import { eq } from "drizzle-orm";
import { getDb } from "../db";
import { draws } from "../db/schema";
import { currentWeekDetails } from "./week";

export async function getOrCreateCurrentDraw() {
  const db = getDb();
  const week = currentWeekDetails();

  const [existing] = await db
    .select()
    .from(draws)
    .where(eq(draws.contest, week.contest))
    .limit(1);

  if (existing) {
    if (
      existing.drawDate === week.drawDate &&
      existing.closesAt === week.closesAt
    ) {
      return { draw: existing, week };
    }

    const [normalized] = await db
      .update(draws)
      .set({
        drawDate: week.drawDate,
        closesAt: week.closesAt,
      })
      .where(eq(draws.id, existing.id))
      .returning();

    if (normalized) return { draw: normalized, week };
  }

  await db
    .insert(draws)
    .values({
      contest: week.contest,
      drawDate: week.drawDate,
      closesAt: week.closesAt,
    })
    .onConflictDoNothing({ target: draws.contest });

  const [draw] = await db
    .select()
    .from(draws)
    .where(eq(draws.contest, week.contest))
    .limit(1);

  if (!draw) throw new Error("Não foi possível abrir a semana.");
  return { draw, week };
}
