import { asc, eq, inArray } from "drizzle-orm";
import { getDb } from "../../../../db";
import { draws, reservations } from "../../../../db/schema";
import { getOrCreateCurrentDraw } from "../../../../lib/current-draw";
import {
  listDrawsAwaitingResult,
} from "../../../../lib/weekly-processing";
import {
  readAdminCookie,
  verifyAdminSession,
} from "../../../../lib/admin-auth";

async function hasAdminSession(request: Request) {
  return verifyAdminSession(readAdminCookie(request));
}

export async function GET(request: Request) {
  if (!(await hasAdminSession(request))) {
    return Response.json({ error: "Sessão inválida." }, { status: 401 });
  }

  try {
    const db = getDb();
    const { draw } = await getOrCreateCurrentDraw();
    const awaitingResults = await listDrawsAwaitingResult();

    const rows = await db
      .select({
        id: reservations.id,
        drawId: reservations.drawId,
        number: reservations.chosenNumber,
        name: reservations.displayName,
        phone: reservations.phone,
        status: reservations.paymentStatus,
        reservedAt: reservations.reservedAt,
        expiresAt: reservations.expiresAt,
        paidAt: reservations.paidAt,
      })
      .from(reservations)
      .where(eq(reservations.drawId, draw.id))
      .orderBy(asc(reservations.chosenNumber));
    const awaitingIds = awaitingResults.map((item) => item.id);
    const pendingFinalizationReservations = awaitingIds.length
      ? await db
          .select({
            id: reservations.id,
            drawId: reservations.drawId,
            number: reservations.chosenNumber,
            name: reservations.displayName,
            phone: reservations.phone,
            status: reservations.paymentStatus,
            reservedAt: reservations.reservedAt,
            expiresAt: reservations.expiresAt,
            paidAt: reservations.paidAt,
            contest: draws.contest,
            drawDate: draws.drawDate,
            closesAt: draws.closesAt,
            priceCents: draws.ticketPriceCents,
          })
          .from(reservations)
          .innerJoin(draws, eq(draws.id, reservations.drawId))
          .where(
            inArray(reservations.drawId, awaitingIds),
          )
          .orderBy(asc(draws.drawDate), asc(reservations.chosenNumber))
      : [];

    return Response.json(
      {
        reservations: rows
          .filter((row) => row.status === "paid" || row.status === "pending")
          .map((row) => ({
            ...row,
            contest: draw.contest,
            drawDate: draw.drawDate,
            closesAt: draw.closesAt,
            priceCents: draw.ticketPriceCents,
          })),
        draw: {
          id: draw.id,
          contest: draw.contest,
          drawDate: draw.drawDate,
          closesAt: draw.closesAt,
          priceCents: draw.ticketPriceCents,
          status: draw.status,
        },
        awaitingResults,
        pendingFinalizationReservations:
          pendingFinalizationReservations.filter(
            (row) => row.status === "pending",
          ),
      },
      { headers: { "Cache-Control": "private, no-store" } },
    );
  } catch (error) {
    console.error("admin reservations list failed", error);
    return Response.json(
      { error: "Não foi possível consultar os pagamentos." },
      { status: 500 },
    );
  }
}
