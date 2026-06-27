BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "creature_personality" DROP CONSTRAINT IF EXISTS "creature_personality_fk_0";
--
-- ACTION ALTER TABLE
--
--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "creature_personality"
    ADD CONSTRAINT "creature_personality_fk_0"
    FOREIGN KEY("creatureId")
    REFERENCES "creature"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "journal_entry"
    ADD CONSTRAINT "journal_entry_fk_0"
    FOREIGN KEY("creatureId")
    REFERENCES "creature"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- MIGRATION VERSION FOR tamagotchi
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('tamagotchi', '20260624184340945', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260624184340945', "timestamp" = now();

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
