import {
  and,
  asc,
  eq,
  inArray,
  isNull,
  lte,
  or,
} from "drizzle-orm";
import { env } from "cloudflare:workers";
import { getD1, getDb } from "../db";
import { draws, prizes, reservations } from "../db/schema";
import { retryDatabaseBusy } from "./database-retry";
import {
  fetchFridayResultForDate,
  type OfficialEuromillionsResult,
} from "./euromillions";

const RESULT_RETRY_MINUTES = 15;

function runtimeValue(key: keyof Cloudflare.Env) {
  const workerEnv = env as unknown as Record<string, string | undefined>;
  return workerEnv[key] ?? process.env[key];
}

function readTestResultFixture(
  targetDrawDate: string,
): OfficialEuromillionsResult | null {
  if (runtimeValue("SEXTA50_TEST_MODE") !== "1") return null;

  const serialized = runtimeValue("SEXTA50_TEST_RESULT");
  if (!serialized) {
    throw new Error("O modo de teste requer SEXTA50_TEST_RESULT.");
  }

  const fixture = JSON.parse(serialized) as Partial<OfficialEuromillionsResult>;
  const drawOrder = fixture.drawOrder;
  if (
    typeof fixture.contest !== "string" ||
    typeof fixture.date !== "string" ||
    typeof fixture.drawDate !== "string" ||
    !Array.isArray(drawOrder) ||
    drawOrder.length !== 5 ||
    new Set(drawOrder).size !== 5 ||
    !drawOrder.every(
      (number) =>
        Number.isInteger(number) && number >= 1 && number <= 50,
    )
  ) {
    throw new Error("O resultado fictício de integração é inválido.");
  }

  if (fixture.drawDate !== targetDrawDate) return null;
  return {
    contest: fixture.contest,
    date: fixture.date,
    drawDate: fixture.drawDate,
    drawOrder,
    sourceUrl: "https://example.invalid/sexta-50-integration-fixture",
  };
}

async function fetchConfiguredResult(targetDrawDate: string) {
  if (runtimeValue("SEXTA50_TEST_MODE") === "1") {
    return readTestResultFixture(targetDrawDate);
  }
  return fetchFridayResultForDate(targetDrawDate);
}

export type WeeklyProcessingResult = {
  drawId: number;
  contest: string;
  drawDate: string;
  status:
    | "processed"
    | "already-processed"
    | "payments-pending"
    | "waiting"
    | "not-due"
    | "throttled"
    | "error";
  message: string;
};

function storedOrder(value: string | null) {
  if (!value) return null;
  try {
    const order = JSON.parse(value);
    return Array.isArray(order) && order.every(Number.isInteger)
      ? (order as number[])
      : null;
  } catch {
    return null;
  }
}

function prizesMatchOrder(
  rows: Array<{ rank: number; winningNumber: number }>,
  order: number[],
  requireAll = false,
) {
  if (requireAll && rows.length !== 3) return false;
  return rows.every(
    (row) =>
      row.rank >= 1 &&
      row.rank <= 3 &&
      row.winningNumber === order[row.rank - 1],
  );
}

async function resultHash(value: {
  contest: string;
  drawDate: string;
  drawOrder: number[];
}) {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(
      JSON.stringify([value.contest, value.drawDate, value.drawOrder]),
    ),
  );
  return Array.from(new Uint8Array(bytes), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

export async function listDrawsAwaitingResult(now = new Date()) {
  const db = getDb();
  return db
    .select({
      id: draws.id,
      contest: draws.contest,
      drawDate: draws.drawDate,
      closesAt: draws.closesAt,
      status: draws.status,
      lastResultCheckAt: draws.lastResultCheckAt,
    })
    .from(draws)
    .where(
      and(
        inArray(draws.status, ["open", "closed", "resulted"]),
        lte(draws.closesAt, now.toISOString()),
      ),
    )
    .orderBy(asc(draws.drawDate));
}

async function finalizeDraw(
  draw: typeof draws.$inferSelect,
  now: Date,
  force: boolean,
): Promise<WeeklyProcessingResult> {
  const nowIso = now.toISOString();
  const db = getDb();
  const existingPrizes = await db
    .select({
      rank: prizes.rank,
      winningNumber: prizes.winningNumber,
    })
    .from(prizes)
    .where(eq(prizes.drawId, draw.id))
    .orderBy(asc(prizes.rank));

  if (draw.status === "archived") {
    const order = storedOrder(draw.officialOrder);
    if (!order || !prizesMatchOrder(existingPrizes, order, true)) {
      return {
        drawId: draw.id,
        contest: draw.contest,
        drawDate: draw.drawDate,
        status: "error",
        message: "O arquivo desta semana está incompleto e requer revisão.",
      };
    }
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "already-processed",
      message: "Esta semana já está arquivada.",
    };
  }

  if (new Date(draw.closesAt).getTime() > now.getTime()) {
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "not-due",
      message: "O sorteio desta semana ainda não fechou.",
    };
  }

  const pendingRows = await db
    .select({ id: reservations.id })
    .from(reservations)
    .where(
      and(
        eq(reservations.drawId, draw.id),
        eq(reservations.paymentStatus, "pending"),
      ),
    );
  if (pendingRows.length > 0) {
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "payments-pending",
      message: `Ainda existem ${pendingRows.length} pagamento${pendingRows.length === 1 ? "" : "s"} por confirmar ou desbloquear nesta semana.`,
    };
  }

  const retryWindowMs = force
    ? 10 * 1000
    : RESULT_RETRY_MINUTES * 60 * 1000;
  const cutoff = new Date(
    now.getTime() - retryWindowMs,
  ).toISOString();
  const claimConditions = [
    eq(draws.id, draw.id),
    inArray(draws.status, ["open", "closed", "resulted"]),
    or(
      isNull(draws.lastResultCheckAt),
      lte(draws.lastResultCheckAt, cutoff),
    )!,
  ];

  const [claimed] = await retryDatabaseBusy(() =>
    db
      .update(draws)
      .set({ lastResultCheckAt: nowIso })
      .where(and(...claimConditions))
      .returning({ id: draws.id }),
  );

  if (!claimed) {
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "throttled",
      message: "O resultado oficial foi consultado há poucos minutos.",
    };
  }

  let official;
  try {
    official = await fetchConfiguredResult(draw.drawDate);
  } catch (error) {
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "error",
      message:
        error instanceof Error
          ? error.message
          : "Não foi possível consultar o resultado oficial.",
    };
  }

  if (!official) {
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "waiting",
      message: "O resultado oficial desta sexta-feira ainda não está disponível.",
    };
  }

  const hash = await resultHash(official);
  if (draw.resultHash && draw.resultHash !== hash) {
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "error",
      message: "O resultado guardado não coincide com a fonte oficial.",
    };
  }
  const previousOrder = storedOrder(draw.officialOrder);
  if (
    previousOrder &&
    JSON.stringify(previousOrder) !== JSON.stringify(official.drawOrder)
  ) {
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "error",
      message: "A ordem já guardada não coincide com a fonte oficial.",
    };
  }
  if (!prizesMatchOrder(existingPrizes, official.drawOrder)) {
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "error",
      message: "Os prémios já guardados não coincidem com o resultado oficial.",
    };
  }

  const orderJson = JSON.stringify(official.drawOrder);
  const d1 = getD1();
  const statements = [
    d1
      .prepare(`
        UPDATE draws
        SET
          status = 'resulted',
          official_contest = ?,
          official_order = ?,
          source_url = ?,
          result_fetched_at = ?,
          result_hash = ?,
          resulted_at = COALESCE(resulted_at, ?),
          reservation_count = (
            SELECT COUNT(*)
            FROM reservations
            WHERE draw_id = ? AND payment_status IN ('pending', 'paid')
          ),
          paid_count = (
            SELECT COUNT(*)
            FROM reservations
            WHERE draw_id = ? AND payment_status = 'paid'
          ),
          collected_cents = (
            SELECT COUNT(*) * draws.ticket_price_cents
            FROM reservations
            WHERE draw_id = ? AND payment_status = 'paid'
          )
        WHERE
          id = ?
          AND status IN ('open', 'closed', 'resulted')
          AND (result_hash IS NULL OR result_hash = ?)
      `)
      .bind(
        official.contest,
        orderJson,
        official.sourceUrl,
        nowIso,
        hash,
        nowIso,
        draw.id,
        draw.id,
        draw.id,
        draw.id,
        hash,
      ),
  ];

  official.drawOrder.slice(0, 3).forEach((winningNumber, index) => {
    statements.push(
      d1
        .prepare(`
          INSERT INTO prizes (
            draw_id,
            reservation_id,
            rank,
            winning_number,
            outcome,
            winner_name,
            winner_phone,
            winner_paid_at
          )
          SELECT
            ?,
            winner.id,
            ?,
            ?,
            CASE
              WHEN winner.id IS NULL THEN 'no_paid_reservation'
              ELSE 'awarded'
            END,
            winner.display_name,
            winner.phone,
            winner.paid_at
          FROM (SELECT 1) AS seed
          LEFT JOIN reservations AS winner
            ON winner.draw_id = ?
            AND winner.chosen_number = ?
            AND winner.payment_status = 'paid'
          WHERE EXISTS (
            SELECT 1
            FROM draws
            WHERE id = ? AND result_hash = ?
          )
          ON CONFLICT(draw_id, rank) DO UPDATE SET
            reservation_id = excluded.reservation_id,
            outcome = excluded.outcome,
            winner_name = excluded.winner_name,
            winner_phone = excluded.winner_phone,
            winner_paid_at = excluded.winner_paid_at
          WHERE prizes.winning_number = excluded.winning_number
        `)
        .bind(
          draw.id,
          index + 1,
          winningNumber,
          draw.id,
          winningNumber,
          draw.id,
          hash,
        ),
    );
  });

  statements.push(
    d1
      .prepare(`
        UPDATE draws
        SET
          status = 'archived',
          archived_at = COALESCE(archived_at, ?)
        WHERE
          id = ?
          AND status = 'resulted'
          AND result_hash = ?
          AND (
            SELECT COUNT(*)
            FROM prizes
            WHERE draw_id = ?
          ) = 3
          AND EXISTS (
            SELECT 1 FROM prizes
            WHERE draw_id = ? AND rank = 1 AND winning_number = ?
          )
          AND EXISTS (
            SELECT 1 FROM prizes
            WHERE draw_id = ? AND rank = 2 AND winning_number = ?
          )
          AND EXISTS (
            SELECT 1 FROM prizes
            WHERE draw_id = ? AND rank = 3 AND winning_number = ?
          )
      `)
      .bind(
        nowIso,
        draw.id,
        hash,
        draw.id,
        draw.id,
        official.drawOrder[0],
        draw.id,
        official.drawOrder[1],
        draw.id,
        official.drawOrder[2],
      ),
  );
  statements.push(
    d1
      .prepare(`
        DELETE FROM reservations
        WHERE
          draw_id = ?
          AND EXISTS (
            SELECT 1
            FROM draws
            WHERE id = ? AND status = 'archived' AND result_hash = ?
          )
          AND id NOT IN (
            SELECT reservation_id
            FROM prizes
            WHERE draw_id = ? AND reservation_id IS NOT NULL
          )
      `)
      .bind(draw.id, draw.id, hash, draw.id),
  );

  try {
    await retryDatabaseBusy(() => d1.batch(statements));
  } catch (error) {
    console.error("weekly draw finalization failed", error);
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "error",
      message: "Não foi possível arquivar a semana. Nada foi alterado.",
    };
  }

  const [archived] = await db
    .select({ status: draws.status })
    .from(draws)
    .where(eq(draws.id, draw.id))
    .limit(1);
  const prizeRows = await db
    .select({
      rank: prizes.rank,
      winningNumber: prizes.winningNumber,
    })
    .from(prizes)
    .where(eq(prizes.drawId, draw.id))
    .orderBy(asc(prizes.rank));

  if (
    archived?.status !== "archived" ||
    !prizesMatchOrder(prizeRows, official.drawOrder, true)
  ) {
    return {
      drawId: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      status: "error",
      message: "A semana não ficou totalmente arquivada.",
    };
  }

  return {
    drawId: draw.id,
    contest: draw.contest,
    drawDate: draw.drawDate,
    status: "processed",
    message: "Resultado confirmado, prémios atribuídos e semana arquivada.",
  };
}

export async function processDueDraws(options: {
  drawId: number;
  force?: boolean;
  now?: Date;
}) {
  const db = getDb();
  const now = options.now ?? new Date();
  const rows = await db
    .select()
    .from(draws)
    .where(eq(draws.id, options.drawId))
    .limit(1);

  const results: WeeklyProcessingResult[] = [];
  for (const draw of rows) {
    results.push(await finalizeDraw(draw, now, options.force === true));
  }

  return results;
}
