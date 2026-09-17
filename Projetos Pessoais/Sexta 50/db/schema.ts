import { sql } from "drizzle-orm";
import { index, integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

export const draws = sqliteTable("draws", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  contest: text("contest").notNull(),
  drawDate: text("draw_date").notNull(),
  closesAt: text("closes_at").notNull(),
  status: text("status", { enum: ["open", "closed", "resulted", "archived"] }).notNull().default("open"),
  ticketPriceCents: integer("ticket_price_cents").notNull().default(250),
  officialContest: text("official_contest"),
  officialOrder: text("official_order"),
  sourceUrl: text("source_url"),
  lastResultCheckAt: text("last_result_check_at"),
  resultFetchedAt: text("result_fetched_at"),
  resultHash: text("result_hash"),
  resultedAt: text("resulted_at"),
  archivedAt: text("archived_at"),
  reservationCount: integer("reservation_count"),
  paidCount: integer("paid_count"),
  collectedCents: integer("collected_cents"),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
}, (table) => [
  uniqueIndex("draws_contest_unique").on(table.contest),
  index("draws_processing_idx").on(table.status, table.closesAt),
]);

export const reservations = sqliteTable("reservations", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  drawId: integer("draw_id").notNull().references(() => draws.id, { onDelete: "cascade" }),
  chosenNumber: integer("chosen_number").notNull(),
  displayName: text("display_name").notNull(),
  phone: text("phone").notNull(),
  accessTokenHash: text("access_token_hash"),
  paymentStatus: text("payment_status", { enum: ["pending", "paid", "released", "expired", "refunded"] }).notNull().default("pending"),
  paymentReference: text("payment_reference"),
  reservedAt: text("reserved_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  expiresAt: text("expires_at"),
  paidAt: text("paid_at"),
  releasedAt: text("released_at"),
}, (table) => [
  uniqueIndex("reservations_draw_number_active_unique")
    .on(table.drawId, table.chosenNumber)
    .where(sql`${table.paymentStatus} in ('pending', 'paid')`),
  uniqueIndex("reservations_access_token_unique").on(table.accessTokenHash),
  index("reservations_payment_status_idx").on(table.paymentStatus),
]);

export const prizes = sqliteTable("prizes", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  drawId: integer("draw_id").notNull().references(() => draws.id, { onDelete: "cascade" }),
  reservationId: integer("reservation_id").references(() => reservations.id, { onDelete: "set null" }),
  rank: integer("rank").notNull(),
  winningNumber: integer("winning_number").notNull(),
  outcome: text("outcome", { enum: ["awarded", "no_paid_reservation"] })
    .notNull()
    .default("no_paid_reservation"),
  winnerName: text("winner_name"),
  winnerPhone: text("winner_phone"),
  winnerPaidAt: text("winner_paid_at"),
  notifiedAt: text("notified_at"),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
}, (table) => [
  uniqueIndex("prizes_draw_rank_unique").on(table.drawId, table.rank),
]);
