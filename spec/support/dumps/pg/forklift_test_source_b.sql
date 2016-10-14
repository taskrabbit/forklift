SET client_min_messages TO WARNING;
DROP TABLE IF EXISTS "admin_notes";

CREATE TABLE "admin_notes" (
  "id" SERIAL NOT NULL PRIMARY KEY,
  "user_id" integer NOT NULL,
  "note" text NOT NULL,
  "created_at" timestamp NOT NULL,
  "updated_at" timestamp NOT NULL
);

INSERT INTO "admin_notes" ("id", "user_id", "note", "created_at", "updated_at")
VALUES
	(1,1,'User 1 called customer support\n','2014-04-03 11:50:25','2014-04-03 11:50:25'),
	(2,2,'User 2 called customer support','2014-04-03 11:50:26','2014-04-03 11:50:26'),
	(3,5,'User 5 returned the purchase','2014-04-03 11:50:28','2014-04-03 11:50:28');
