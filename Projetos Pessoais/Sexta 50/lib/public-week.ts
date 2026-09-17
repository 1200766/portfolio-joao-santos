import { and, asc, eq, inArray } from "drizzle-orm";
import { getDb } from "../db";
import { reservations } from "../db/schema";
import { getOrCreateCurrentDraw } from "./current-draw";

export type PublicWeekSnapshot = {
  reservations: Array<{
    number: number;
    name: string;
    status: "paid" | "pending";
  }>;
  draw: {
    id: number;
    contest: string;
    drawDate: string;
    closesAt: string;
    status: "open" | "closed" | "resulted" | "archived";
    priceCents: number;
  };
};

export async function getPublicWeekSnapshot(): Promise<PublicWeekSnapshot> {
  const db = getDb();
  const { draw } = await getOrCreateCurrentDraw();

  const rows = await db
    .select({
      number: reservations.chosenNumber,
      name: reservations.displayName,
      status: reservations.paymentStatus,
    })
    .from(reservations)
    .where(
      and(
        eq(reservations.drawId, draw.id),
        inArray(reservations.paymentStatus, ["paid", "pending"]),
      ),
    )
    .orderBy(asc(reservations.chosenNumber));

  return {
    reservations: rows as PublicWeekSnapshot["reservations"],
    draw: {
      id: draw.id,
      contest: draw.contest,
      drawDate: draw.drawDate,
      closesAt: draw.closesAt,
      status: draw.status,
      priceCents: draw.ticketPriceCents,
    },
  };
}
