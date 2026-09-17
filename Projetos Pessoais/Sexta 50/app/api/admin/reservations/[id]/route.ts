import { and, eq, inArray } from "drizzle-orm";
import { getDb } from "../../../../../db";
import { draws, reservations } from "../../../../../db/schema";
import {
  readAdminCookie,
  verifyAdminSession,
} from "../../../../../lib/admin-auth";
import {
  isDatabaseBusyError,
  retryDatabaseBusy,
} from "../../../../../lib/database-retry";

async function hasAdminSession(request: Request) {
  return verifyAdminSession(readAdminCookie(request));
}

function parseReservationId(value: string) {
  const id = Number(value);
  return Number.isInteger(id) && id > 0 ? id : null;
}

async function reservationDetails(id: number) {
  const db = getDb();
  const [row] = await db
    .select({
      id: reservations.id,
      number: reservations.chosenNumber,
      name: reservations.displayName,
      phone: reservations.phone,
      status: reservations.paymentStatus,
      paymentReference: reservations.paymentReference,
      reservedAt: reservations.reservedAt,
      expiresAt: reservations.expiresAt,
      paidAt: reservations.paidAt,
      releasedAt: reservations.releasedAt,
      contest: draws.contest,
      drawDate: draws.drawDate,
      closesAt: draws.closesAt,
      drawStatus: draws.status,
      priceCents: draws.ticketPriceCents,
    })
    .from(reservations)
    .innerJoin(draws, eq(reservations.drawId, draws.id))
    .where(eq(reservations.id, id))
    .limit(1);

  return row;
}

export async function GET(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  if (!(await hasAdminSession(request))) {
    return Response.json({ error: "Sessão inválida." }, { status: 401 });
  }

  const id = parseReservationId((await context.params).id);
  if (!id) return Response.json({ error: "Pagamento inválido." }, { status: 400 });

  try {
    const reservation = await reservationDetails(id);
    if (!reservation) {
      return Response.json({ error: "Pagamento não encontrado." }, { status: 404 });
    }

    return Response.json(
      { reservation },
      { headers: { "Cache-Control": "private, no-store" } },
    );
  } catch (error) {
    console.error("admin reservation read failed", error);
    return Response.json(
      { error: "Não foi possível consultar este pagamento." },
      { status: 500 },
    );
  }
}

export async function PATCH(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  if (!(await hasAdminSession(request))) {
    return Response.json({ error: "Sessão inválida." }, { status: 401 });
  }

  const id = parseReservationId((await context.params).id);
  if (!id) return Response.json({ error: "Pagamento inválido." }, { status: 400 });

  try {
    const payload = (await request.json()) as {
      action?: string;
      status?: string;
      refundConfirmed?: boolean;
    };
    const action =
      payload.action ?? (payload.status === "paid" ? "confirm-payment" : "");
    if (
      action !== "confirm-payment" &&
      action !== "release" &&
      action !== "refund-and-release"
    ) {
      return Response.json(
        { error: "A ação pedida não é válida." },
        { status: 400 },
      );
    }
    if (action === "refund-and-release" && payload.refundConfirmed !== true) {
      return Response.json(
        {
          error:
            "Confirma primeiro que o pagamento foi devolvido antes de desbloquear.",
        },
        { status: 400 },
      );
    }

    const db = getDb();
    const before = await reservationDetails(id);
    if (!before) {
      return Response.json(
        { error: "Pagamento não encontrado." },
        { status: 404 },
      );
    }
    if (before.drawStatus === "resulted" || before.drawStatus === "archived") {
      return Response.json(
        { error: "Esta semana já foi arquivada e não pode ser alterada." },
        { status: 409 },
      );
    }

    const expectedStatus = action === "refund-and-release" ? "paid" : "pending";
    const targetStatus =
      action === "confirm-payment"
        ? "paid"
        : action === "release"
          ? "released"
          : "refunded";
    if (before.status === targetStatus) {
      return Response.json(
        { reservation: before },
        { headers: { "Cache-Control": "private, no-store" } },
      );
    }

    const changedAt = new Date().toISOString();
    const [updated] = await retryDatabaseBusy(() =>
      db
        .update(reservations)
        .set(
          action === "confirm-payment"
            ? { paymentStatus: "paid", paidAt: changedAt, expiresAt: null }
            : action === "release"
              ? {
                  paymentStatus: "released",
                  releasedAt: changedAt,
                  expiresAt: null,
                }
              : {
                  paymentStatus: "refunded",
                  releasedAt: changedAt,
                  expiresAt: null,
                },
        )
        .where(
          and(
            eq(reservations.id, id),
            eq(reservations.paymentStatus, expectedStatus),
            inArray(
              reservations.drawId,
              db
                .select({ id: draws.id })
                .from(draws)
                .where(inArray(draws.status, ["open", "closed"])),
            ),
          ),
        )
        .returning({ id: reservations.id }),
    );

    if (!updated) {
      const current = await reservationDetails(id);
      const finalized =
        current?.drawStatus === "resulted" ||
        current?.drawStatus === "archived";
      return Response.json(
        {
          error: finalized
            ? "Esta semana já foi arquivada e não pode ser alterada."
            : action === "refund-and-release"
              ? "Este pagamento já não está confirmado ou já foi corrigido."
            : action === "release"
              ? "Esta participação já não está pendente."
              : "Este pagamento já não está pendente.",
        },
        { status: 409 },
      );
    }

    const reservation =
      (await reservationDetails(id)) ??
      ({
        ...before,
        status: targetStatus,
        paidAt: action === "confirm-payment" ? changedAt : before.paidAt,
        releasedAt:
          action === "release" || action === "refund-and-release"
            ? changedAt
            : before.releasedAt,
        expiresAt: null,
      } as const);

    return Response.json(
      { reservation },
      { headers: { "Cache-Control": "private, no-store" } },
    );
  } catch (error) {
    console.error("admin reservation update failed", error);
    if (isDatabaseBusyError(error)) {
      return Response.json(
        {
          error:
            "O sistema está muito ocupado. Nenhuma alteração foi confirmada; tenta novamente.",
        },
        { status: 503 },
      );
    }
    return Response.json(
      { error: "Não foi possível alterar esta participação." },
      { status: 500 },
    );
  }
}
