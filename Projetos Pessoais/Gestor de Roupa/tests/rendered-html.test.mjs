import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { access, readFile } from "node:fs/promises";
import test from "node:test";
import { promisify } from "node:util";

const templateRoot = new URL("../", import.meta.url);
const execFileAsync = promisify(execFile);

test("includes the complete imported inventory", async () => {
  const data = JSON.parse(
    await readFile(new URL("../data/clothes.json", import.meta.url), "utf8"),
  );
  const photoCount = data.reduce(
    (total, item) => total + item.photos.length,
    0,
  );

  assert.equal(data.length, 46);
  assert.equal(photoCount, 135);
  assert.ok(data.every((item) => item.id && item.name && item.photos.length));

  await Promise.all(
    data.flatMap((item) =>
      item.photos.map((photo) =>
        access(new URL(`../public${photo}`, import.meta.url)),
      ),
    ),
  );
});

test("includes the requested landing and catalog flows", async () => {
  const [home, catalog, layout, styles] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(
      new URL("../app/catalogo/CatalogClient.tsx", import.meta.url),
      "utf8",
    ),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  ]);

  assert.match(home, /Começar a ver a roupa/);
  assert.match(home, /<span>\{photoCount\}<\/span>/);
  assert.doesNotMatch(home, /<span>105<\/span>/);
  assert.match(catalog, /Guardar alterações/);
  assert.match(catalog, /window\.localStorage\.setItem/);
  assert.match(catalog, /Repor dados originais/);
  assert.doesNotMatch(catalog, /fetch\("\/api\/clothes"/);
  assert.match(catalog, /Tipo de roupa/);
  assert.match(catalog, /Marca/);
  assert.match(catalog, /Tamanho/);
  assert.match(catalog, /Preço/);
  assert.match(catalog, /Estado/);
  assert.match(layout, /og\.png/);
  assert.match(
    styles,
    /grid-template-columns: minmax\(0, 1fr\) auto 27px;/,
  );
  assert.doesNotMatch(`${home}\n${catalog}\n${layout}`, /codex-preview/);
});

test("removes temporary starter preview assets", async () => {
  await assert.rejects(
    access(new URL("app/_sites-preview", templateRoot)),
  );
});

test("does not expose a server-side write route", async () => {
  await assert.rejects(
    access(new URL("../app/api/clothes/route.ts", import.meta.url)),
  );
});

test("requires explicit confirmation before replacing imported files", async () => {
  await assert.rejects(
    execFileAsync(process.execPath, ["scripts/import-clothes.mjs"], {
      cwd: new URL("../", import.meta.url),
    }),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /Nenhum ficheiro foi alterado/);
      return true;
    },
  );
});
