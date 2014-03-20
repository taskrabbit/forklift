ALTER TABLE `users` ADD `combined_name` VARCHAR(255)  NULL DEFAULT NULL  AFTER `last_name`;

UPDATE `users` SET `combined_name` = (
  select CONCAT(first_name, " ", last_name)
);

CREATE INDEX combined_name ON users (combined_name);
