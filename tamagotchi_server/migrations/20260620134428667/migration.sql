BEGIN;

--
-- ACTION UPDATE DATA
-- The JournalEvent enum value `pet` was renamed to `play` (S-04 Play rename).
-- The enum is serialized by name (stored as text), so existing rows still hold
-- the old string. Rewrite them in place. Idempotent / no-op on a fresh DB.
--
UPDATE "journal_entry" SET "event" = 'play' WHERE "event" = 'pet';

--
-- MIGRATION VERSION FOR tamagotchi
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('tamagotchi', '20260620134428667', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260620134428667', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260213194423028', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260213194423028', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260129181112269', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129181112269', "timestamp" = now();


COMMIT;
