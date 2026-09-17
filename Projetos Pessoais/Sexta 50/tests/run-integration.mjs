import { spawn, spawnSync } from "node:child_process";
import { mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import net from "node:net";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const testRoot = await mkdtemp(path.join(tmpdir(), "sexta50-integration-"));
const stateDirectory = path.join(testRoot, "state");
const fixture = JSON.stringify({
  contest: "FIXTURE-2026-30",
  date: "24/07/2026",
  drawDate: "2026-07-24",
  drawOrder: [47, 11, 22, 33, 44],
});
let server;
let serverOutput = "";

function freePort() {
  return new Promise((resolve, reject) => {
    const candidate = net.createServer();
    candidate.once("error", reject);
    candidate.listen(0, "127.0.0.1", () => {
      const address = candidate.address();
      const port = typeof address === "object" && address ? address.port : 0;
      candidate.close((error) => (error ? reject(error) : resolve(port)));
    });
  });
}

async function findDatabase(directory) {
  let entries;
  try {
    entries = await readdir(directory, { withFileTypes: true });
  } catch {
    return null;
  }

  for (const entry of entries) {
    const candidate = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      const nested = await findDatabase(candidate);
      if (nested) return nested;
    } else if (
      entry.name.endsWith(".sqlite") &&
      !entry.name.endsWith("metadata.sqlite")
    ) {
      return candidate;
    }
  }
  return null;
}

async function waitFor(description, operation, timeoutMs = 60_000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    if (server?.exitCode !== null) {
      throw new Error(
        `O servidor terminou antes de ${description}.\n${serverOutput.slice(-8_000)}`,
      );
    }
    try {
      const result = await operation();
      if (result) return result;
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(
    `Tempo esgotado ao esperar por ${description}.${
      lastError instanceof Error ? ` ${lastError.message}` : ""
    }\n${serverOutput.slice(-8_000)}`,
  );
}

async function stopServer() {
  if (!server || server.exitCode !== null) return;
  server.kill("SIGTERM");
  await Promise.race([
    new Promise((resolve) => server.once("exit", resolve)),
    new Promise((resolve) =>
      setTimeout(() => {
        if (server?.exitCode === null) server.kill("SIGKILL");
        resolve();
      }, 5_000),
    ),
  ]);
}

try {
  const sqlite = spawnSync("sqlite3", ["--version"], { encoding: "utf8" });
  if (sqlite.status !== 0) {
    throw new Error("O executável sqlite3 é necessário para este teste.");
  }

  const port = await freePort();
  const baseUrl = `http://localhost:${port}`;
  const environment = {
    ...process.env,
    ADMIN_USERNAME: "Test",
    ADMIN_PASSWORD: "test-secret",
    ADMIN_SESSION_SECRET:
      "integration-only-session-secret-with-at-least-32-characters",
    SEXTA50_STATE_DIR: stateDirectory,
    SEXTA50_TEST_MODE: "1",
    SEXTA50_TEST_RESULT: fixture,
    NO_COLOR: "1",
  };

  server = spawn(
    "npm",
    ["run", "dev", "--", "--port", String(port)],
    {
      cwd: projectRoot,
      env: environment,
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  const recordOutput = (chunk) => {
    serverOutput = `${serverOutput}${chunk}`.slice(-20_000);
  };
  server.stdout.on("data", recordOutput);
  server.stderr.on("data", recordOutput);

  await waitFor("o arranque do servidor", async () => {
    try {
      await fetch(`${baseUrl}/api/reservations`, { cache: "no-store" });
    } catch {
      return false;
    }
    return true;
  });

  const database = await waitFor("a base D1 temporária", () =>
    findDatabase(stateDirectory),
  );
  const migrationsDirectory = path.join(projectRoot, "drizzle");
  const migrations = (await readdir(migrationsDirectory))
    .filter((name) => name.endsWith(".sql"))
    .sort();

  for (const migration of migrations) {
    const source = await readFile(
      path.join(migrationsDirectory, migration),
      "utf8",
    );
    const applied = spawnSync("sqlite3", [database], {
      input: source.replaceAll("--> statement-breakpoint", "\n"),
      encoding: "utf8",
    });
    if (applied.status !== 0) {
      throw new Error(
        `A migração ${migration} falhou: ${applied.stderr || applied.stdout}`,
      );
    }
  }

  await waitFor("a API migrada", async () => {
    const response = await fetch(`${baseUrl}/api/reservations`, {
      cache: "no-store",
    });
    return response.status === 200;
  });

  const flow = spawnSync(process.execPath, ["tests/integration-flow.mjs"], {
    cwd: projectRoot,
    env: {
      ...environment,
      SEXTA50_TEST_URL: baseUrl,
      SEXTA50_TEST_DB: database,
    },
    stdio: "inherit",
  });
  if (flow.status !== 0) {
    throw new Error(
      `O fluxo de integração terminou com o código ${flow.status}.\n${serverOutput.slice(-8_000)}`,
    );
  }
} finally {
  await stopServer();
  await rm(testRoot, { recursive: true, force: true });
}
