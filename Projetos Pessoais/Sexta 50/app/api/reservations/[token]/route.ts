import { eq } from "drizzle-orm";
import { getDb } from "../../../../db";
import { draws, reservations } from "../../../../db/schema";

async function hashToken(value: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function formatDate(value: string) {
  const [year, month, day] = value.split("-");
  return `${day}/${month}/${year}`;
}

export async function GET(
  _request: Request,
  context: { params: Promise<{ token: string }> },
) {
  try {
    const { token } = await context.params;
    if (!/^[a-zA-Z0-9-]{20,160}$/.test(token)) {
      return Response.json({ error: "Ligação inválida." }, { status: 400 });
    }

    const db = getDb();
    const [row] = await db
      .select({
        number: reservations.chosenNumber,
        name: reservations.displayName,
        phone: reservations.phone,
        status: reservations.paymentStatus,
        reservedAt: reservations.reservedAt,
        expiresAt: reservations.expiresAt,
        drawDate: draws.drawDate,
        closesAt: draws.closesAt,
        priceCents: draws.ticketPriceCents,
      })
      .from(reservations)
      .innerJoin(draws, eq(reservations.drawId, draws.id))
      .where(eq(reservations.accessTokenHash, await hashToken(token)))
      .limit(1);

    if (!row) return Response.json({ error: "Confirmação não encontrada." }, { status: 404 });

    return Response.json({
      reservation: {
        ...row,
        phone: `••• •• ${row.phone.slice(-2)}`,
        drawDate: formatDate(row.drawDate),
      },
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch {
    return Response.json({ error: "Não foi possível consultar a confirmação." }, { status: 500 });
  }
}
