# Dump of table admin_notes
# ------------------------------------------------------------

DROP TABLE IF EXISTS `admin_notes`;

CREATE TABLE `admin_notes` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `note` text NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

LOCK TABLES `admin_notes` WRITE;

INSERT INTO `admin_notes` (`id`, `user_id`, `note`, `created_at`, `updated_at`)
VALUES
	(1,1,'User 1 called customer support\n','2014-04-03 11:50:25','2014-04-03 11:50:25'),
	(2,2,'User 2 called customer support','2014-04-03 11:50:26','2014-04-03 11:50:26'),
	(3,5,'User 5 returned the purchase','2014-04-03 11:50:28','2014-04-03 11:50:28');

UNLOCK TABLES;