ALTER TABLE `users` ADD `full_name` VARCHAR(255)  NULL  DEFAULT NULL  AFTER `updated_at`;
UPDATE `users` SET full_name = CONCAT(first_name, ' ', last_name);