CREATE TABLE `draws` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`contest` text NOT NULL,
	`draw_date` text NOT NULL,
	`closes_at` text NOT NULL,
	`status` text DEFAULT 'open' NOT NULL,
	`ticket_price_cents` integer DEFAULT 250 NOT NULL,
	`official_order` text,
	`source_url` text,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `draws_contest_unique` ON `draws` (`contest`);--> statement-breakpoint
CREATE TABLE `prizes` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`draw_id` integer NOT NULL,
	`reservation_id` integer,
	`rank` integer NOT NULL,
	`winning_number` integer NOT NULL,
	`notified_at` text,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`draw_id`) REFERENCES `draws`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`reservation_id`) REFERENCES `reservations`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE UNIQUE INDEX `prizes_draw_rank_unique` ON `prizes` (`draw_id`,`rank`);--> statement-breakpoint
CREATE TABLE `reservations` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`draw_id` integer NOT NULL,
	`chosen_number` integer NOT NULL,
	`display_name` text NOT NULL,
	`phone` text NOT NULL,
	`payment_status` text DEFAULT 'pending' NOT NULL,
	`payment_reference` text,
	`reserved_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`paid_at` text,
	FOREIGN KEY (`draw_id`) REFERENCES `draws`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `reservations_draw_number_unique` ON `reservations` (`draw_id`,`chosen_number`);--> statement-breakpoint
CREATE INDEX `reservations_payment_status_idx` ON `reservations` (`payment_status`);