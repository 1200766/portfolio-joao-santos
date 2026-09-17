CREATE UNIQUE INDEX `reservations_draw_number_active_unique` ON `reservations` (`draw_id`,`chosen_number`) WHERE `payment_status` IN ('pending', 'paid');--> statement-breakpoint
DROP INDEX `reservations_draw_number_unique`;--> statement-breakpoint
CREATE INDEX `reservations_pending_expiry_idx` ON `reservations` (`draw_id`,`payment_status`,`expires_at`);
