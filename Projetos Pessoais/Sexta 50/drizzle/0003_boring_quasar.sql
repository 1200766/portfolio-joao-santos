DROP INDEX `reservations_pending_expiry_idx`;--> statement-breakpoint
UPDATE `reservations`
SET `expires_at` = NULL
WHERE `payment_status` = 'pending';--> statement-breakpoint
ALTER TABLE `reservations` ADD `released_at` text;--> statement-breakpoint
ALTER TABLE `draws` ADD `official_contest` text;--> statement-breakpoint
ALTER TABLE `draws` ADD `last_result_check_at` text;--> statement-breakpoint
ALTER TABLE `draws` ADD `result_fetched_at` text;--> statement-breakpoint
ALTER TABLE `draws` ADD `result_hash` text;--> statement-breakpoint
ALTER TABLE `draws` ADD `resulted_at` text;--> statement-breakpoint
ALTER TABLE `draws` ADD `archived_at` text;--> statement-breakpoint
ALTER TABLE `draws` ADD `reservation_count` integer;--> statement-breakpoint
ALTER TABLE `draws` ADD `paid_count` integer;--> statement-breakpoint
ALTER TABLE `draws` ADD `collected_cents` integer;--> statement-breakpoint
CREATE INDEX `draws_processing_idx` ON `draws` (`status`,`closes_at`);--> statement-breakpoint
ALTER TABLE `prizes` ADD `outcome` text DEFAULT 'no_paid_reservation' NOT NULL;--> statement-breakpoint
ALTER TABLE `prizes` ADD `winner_name` text;--> statement-breakpoint
ALTER TABLE `prizes` ADD `winner_phone` text;--> statement-breakpoint
ALTER TABLE `prizes` ADD `winner_paid_at` text;
