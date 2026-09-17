import { and, eq, inArray } from "drizzle-orm";
import { getD1, getDb } from "../../../db";
import { reservations } from "../../../db/schema";
import { getOrCreateCurrentDraw } from "../../../lib/current-draw";
import {
  isDatabaseBusyError,
  isUniqueConstraintError,
  retryDatabaseBusy,
} from "../../../lib/database-retry";
import { getPublicWeekSnapshot } from "../../../lib/public-week";

async function hashToken(value: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function maskedPhone(phone: string) {
  return `••• •• ${phone.slice(-2)}`;
}

export async function GET() {
  try {
    return Response.json(
      await getPublicWeekSnapshot(),
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return Response.json(
      { error: "Não foi possível consultar a semana." },
      { status: 500 },
    );
  }
}

export async function POST(request: Request) {
  try {
    const payload = (await request.json()) as {
      number?: number;
      name?: string;
      phone?: string;
      consent?: boolean;
      drawId?: number;
      contest?: string;
    };
    const number = Number(payload.number);
    const name = payload.name?.trim() ?? "";
    const phone = payload.phone?.replace(/\D/g, "") ?? "";

    if (!Number.isInteger(number) || number < 1 || number > 50) {
      return Response.json({ error: "Escolhe um número entre 1 e 50." }, { status: 400 });
    }
    if (name.length < 1 || name.length > 24) {
      return Response.json({ error: "Indica um nome ou alcunha." }, { status: 400 });
    }
    if (!/^9\d{8}$/.test(phone)) {
      return Response.json({ error: "Indica um número de telemóvel português válido." }, { status: 400 });
    }
    if (payload.consent !== true) {
      return Response.json({ error: "É necessário aceitar a utilização dos dados." }, { status: 400 });
    }

    const { draw, week } = await getOrCreateCurrentDraw();
    if (payload.drawId !== draw.id || payload.contest !== draw.contest) {
      return Response.json(
        { error: "A semana mudou. Atualiza o mapa antes de escolheres um número." },
        { status: 409 },
      );
    }

    const token = `${crypto.randomUUID()}${crypto.randomUUID()}`.replace(/-/g, "");
    const accessTokenHash = await hashToken(token);
    const now = new Date();
    const nowIso = now.toISOString();
    const closesAt = new Date(draw.closesAt).getTime();
    if (!Number.isFinite(closesAt)) throw new Error("A data de fecho da semana é inválida.");

    type InsertedReservation = {
      chosenNumber: number;
      displayName: string;
      phone: string;
      paymentStatus: "pending";
      reservedAt: string;
      expiresAt: string | null;
    };

    let reservation: InsertedReservation | null;
    try {
      reservation = await retryDatabaseBusy(() =>
        getD1()
          .prepare(`
            INSERT INTO reservations (
              draw_id,
              chosen_number,
              display_name,
              phone,
              access_token_hash,
              expires_at
            )
            SELECT id, ?, ?, ?, ?, NULL
            FROM draws
            WHERE id = ? AND status = 'open' AND closes_at > ?
            RETURNING
              chosen_number AS chosenNumber,
              display_name AS displayName,
              phone,
              payment_status AS paymentStatus,
              reserved_at AS reservedAt,
              expires_at AS expiresAt
          `)
          .bind(number, name, phone, accessTokenHash, draw.id, nowIso)
          .first<InsertedReservation>(),
      );
    } catch (error) {
      if (isUniqueConstraintError(error)) {
        return Response.json(
          { error: "Este número acabou de ser escolhido. Seleciona outro." },
          { status: 409 },
        );
      }
      if (isDatabaseBusyError(error)) {
        const db = getDb();
        const [taken] = await db
          .select({ id: reservations.id })
          .from(reservations)
          .where(
            and(
              eq(reservations.drawId, draw.id),
              eq(reservations.chosenNumber, number),
              inArray(reservations.paymentStatus, ["pending", "paid"]),
            ),
          )
          .limit(1);
        return Response.json(
          {
            error: taken
              ? "Este número acabou de ser escolhido. Seleciona outro."
              : "O mapa está muito concorrido. Atualiza e tenta novamente.",
          },
          { status: taken ? 409 : 503 },
        );
      }
      throw error;
    }

    if (!reservation) {
      return Response.json(
        { error: "As escolhas desta semana estão encerradas." },
        { status: 409 },
      );
    }

    return Response.json({
      token,
      reservation: {
        number: reservation.chosenNumber,
        name: reservation.displayName,
        phone: maskedPhone(reservation.phone),
        status: reservation.paymentStatus,
        reservedAt: reservation.reservedAt,
        expiresAt: reservation.expiresAt,
        drawDate: week.displayDate,
        closesAt: draw.closesAt,
        priceCents: draw.ticketPriceCents,
      },
    }, { status: 201 });
  } catch (error) {
    if (isUniqueConstraintError(error)) {
      return Response.json({ error: "Este número acabou de ser escolhido. Seleciona outro." }, { status: 409 });
    }
    if (isDatabaseBusyError(error)) {
      return Response.json(
        { error: "O mapa está muito concorrido. Atualiza e tenta novamente." },
        { status: 503 },
      );
    }
    return Response.json({ error: "Não foi possível guardar a reserva." }, { status: 500 });
  }
}
