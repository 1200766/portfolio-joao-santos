import { asc, desc, eq } from "drizzle-orm";
import { getDb } from "../../../../db";
import { draws, prizes, reservations } from "../../../../db/schema";
import {
  readAdminCookie,
  verifyAdminSession,
} from "../../../../lib/admin-auth";

async function hasAdminSession(request: Request) {
  return verifyAdminSession(readAdminCookie(request));
}

function readOrder(value: string | null) {
  if (!value) return [];
  try {
    const order = JSON.parse(value);
    return Array.isArray(order) ? order.filter(Number.isInteger) : [];
  } catch {
    return [];
  }
}

type HistoryWeek = {
  drawId: number;
  contest: string;
  officialContest: string | null;
  drawDate: string;
  drawOrder: number[];
  sourceUrl: string | null;
  archivedAt: string | null;
  reservationCount: number;
  paidCount: number;
  collectedCents: number;
  prizes: Array<{
    rank: number;
    number: number;
    outcome: "awarded" | "no_paid_reservation";
    name: string | null;
    phone: string | null;
    paidAt: string | null;
    notifiedAt: string | null;
  }>;
};

export async function GET(request: Request) {
  if (!(await hasAdminSession(request))) {
    return Response.json({ error: "Sessão inválida." }, { status: 401 });
  }

  try {
    const db = getDb();
    const rows = await db
      .select({
        drawId: draws.id,
        contest: draws.contest,
        officialContest: draws.officialContest,
        drawDate: draws.drawDate,
        officialOrder: draws.officialOrder,
        sourceUrl: draws.sourceUrl,
        archivedAt: draws.archivedAt,
        reservationCount: draws.reservationCount,
        paidCount: draws.paidCount,
        collectedCents: draws.collectedCents,
        rank: prizes.rank,
        winningNumber: prizes.winningNumber,
        outcome: prizes.outcome,
        winnerName: prizes.winnerName,
        winnerPhone: prizes.winnerPhone,
        winnerPaidAt: prizes.winnerPaidAt,
        notifiedAt: prizes.notifiedAt,
        fallbackName: reservations.displayName,
        fallbackPhone: reservations.phone,
        fallbackPaidAt: reservations.paidAt,
      })
      .from(draws)
      .innerJoin(prizes, eq(prizes.drawId, draws.id))
      .leftJoin(reservations, eq(reservations.id, prizes.reservationId))
      .where(eq(draws.status, "archived"))
      .orderBy(desc(draws.drawDate), asc(prizes.rank));

    const weeks = new Map<number, HistoryWeek>();

    for (const row of rows) {
      const week: HistoryWeek =
        weeks.get(row.drawId) ?? {
          drawId: row.drawId,
          contest: row.contest,
          officialContest: row.officialContest,
          drawDate: row.drawDate,
          drawOrder: readOrder(row.officialOrder),
          sourceUrl: row.sourceUrl,
          archivedAt: row.archivedAt,
          reservationCount: row.reservationCount ?? 0,
          paidCount: row.paidCount ?? 0,
          collectedCents: row.collectedCents ?? 0,
          prizes: [],
        };
      week.prizes.push({
        rank: row.rank,
        number: row.winningNumber,
        outcome: row.outcome,
        name: row.winnerName ?? row.fallbackName,
        phone: row.winnerPhone ?? row.fallbackPhone,
        paidAt: row.winnerPaidAt ?? row.fallbackPaidAt,
        notifiedAt: row.notifiedAt,
      });
      weeks.set(row.drawId, week);
    }

    const history = [...weeks.values()];
    return Response.json(
      {
        weeks: history,
        summary: {
          weeks: history.length,
          winners: history.reduce(
            (total, week) =>
              total +
              week.prizes.filter((prize) => prize.outcome === "awarded").length,
            0,
          ),
          collectedCents: history.reduce(
            (total, week) => total + week.collectedCents,
            0,
          ),
        },
      },
      { headers: { "Cache-Control": "private, no-store" } },
    );
  } catch (error) {
    console.error("admin history failed", error);
    return Response.json(
      { error: "Não foi possível consultar o histórico." },
      { status: 500 },
    );
  }
}
