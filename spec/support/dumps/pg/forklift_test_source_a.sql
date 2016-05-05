SET client_min_messages TO WARNING;
DROP TABLE IF EXISTS "products";

CREATE TABLE "products" (
  "id" SERIAL NOT NULL PRIMARY KEY,
  "name" varchar(255) NOT NULL DEFAULT '',
  "description" text NOT NULL,
  "inventory" integer DEFAULT NULL,
  "created_at" timestamp NOT NULL,
  "updated_at" timestamp NOT NULL
);

INSERT INTO "products" ("id", "name", "description", "inventory", "created_at", "updated_at")
VALUES
	(1,'car','a car',10,'2014-04-03 11:45:51','2014-04-03 11:45:51'),
	(2,'boat','a boat',3,'2014-04-03 11:45:52','2014-04-03 11:45:52'),
	(3,'bus','a bus',5,'2014-04-03 11:45:54','2014-04-03 11:45:54'),
	(4,'motorcycle','a motorcycle',23,'2014-04-03 11:45:56','2014-04-03 11:45:56'),
	(5,'hang_glider','awesome',2,'2014-04-03 11:46:19','2014-04-03 11:46:19');

DROP TABLE IF EXISTS "sales";

CREATE TABLE "sales" (
  "id" SERIAL NOT NULL PRIMARY KEY,
  "user_id" integer NOT NULL,
  "product_id" integer NOT NULL,
  "timestamp" timestamp NOT NULL
);

INSERT INTO "sales" ("id", "user_id", "product_id", "timestamp")
VALUES
	(1,1,1,'2014-04-03 11:47:11'),
	(2,1,2,'2014-04-03 11:47:11'),
	(3,4,5,'2014-04-03 11:47:12'),
	(4,4,4,'2014-04-03 11:47:25'),
	(5,5,5,'2014-04-03 11:47:26');

DROP TABLE IF EXISTS "users";

CREATE TABLE "users" (
  "id" SERIAL NOT NULL PRIMARY KEY,
  "email" varchar(255) NOT NULL DEFAULT '',
  "first_name" varchar(255) NOT NULL DEFAULT '',
  "last_name" varchar(255) NOT NULL DEFAULT '',
  "created_at" timestamp NOT NULL,
  "updated_at" timestamp NOT NULL
);

INSERT INTO "users" ("id", "email", "first_name", "last_name", "created_at", "updated_at")
VALUES
	(1,'evan@example.com','Evan','T','2014-04-03 11:40:12','2014-04-03 11:39:28'),
	(2,'pablo@example.com','Pablo ','J','2014-04-03 11:41:08','2014-04-03 11:41:08'),
	(3,'kevin@example.com','Kevin','B','2014-04-03 11:41:10','2014-04-03 11:41:10'),
	(4,'brian@example.com','Brian','L','2014-04-03 11:41:12','2014-04-03 11:41:12'),
	(5,'aaront@example.com','Aaron','B','2014-04-03 11:41:13','2014-04-03 11:41:13');
