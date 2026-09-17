ALTER TABLE `reservations` ADD `access_token_hash` text;--> statement-breakpoint
ALTER TABLE `reservations` ADD `expires_at` text;--> statement-breakpoint
CREATE UNIQUE INDEX `reservations_access_token_unique` ON `reservations` (`access_token_hash`);