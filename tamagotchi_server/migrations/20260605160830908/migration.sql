BEGIN;

--
-- Function: gen_random_uuid_v7()
-- Source: https://gist.github.com/kjmph/5bd772b2c2df145aa645b837da7eca74
-- License: MIT (copyright notice included on the generator source code).
--
create or replace function gen_random_uuid_v7()
returns uuid
as $$
begin
  -- use random v4 uuid as starting point (which has the same variant we need)
  -- then overlay timestamp
  -- then set version 7 by flipping the 2 and 1 bit in the version 4 string
  return encode(
    set_bit(
      set_bit(
        overlay(uuid_send(gen_random_uuid())
                placing substring(int8send(floor(extract(epoch from clock_timestamp()) * 1000)::bigint) from 3)
                from 1 for 6
        ),
        52, 1
      ),
      53, 1
    ),
    'hex')::uuid;
end
$$
language plpgsql
volatile;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "creature" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "ownerUuid" uuid NOT NULL,
    "name" text NOT NULL,
    "hunger" bigint NOT NULL,
    "energy" bigint NOT NULL,
    "love" bigint NOT NULL,
    "illness" bigint NOT NULL,
    "hatchedAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "creature_owner_idx" ON "creature" USING btree ("ownerUuid");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "creature_personality" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "creatureId" uuid NOT NULL,
    "hungerDecayMod" double precision NOT NULL,
    "hungerRegenMod" double precision NOT NULL,
    "energyDecayMod" double precision NOT NULL,
    "energyRegenMod" double precision NOT NULL,
    "loveDecayMod" double precision NOT NULL,
    "loveRegenMod" double precision NOT NULL,
    "illnessDecayMod" double precision NOT NULL,
    "illnessRegenMod" double precision NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "creature_personality_creature_idx" ON "creature_personality" USING btree ("creatureId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "journal_entry" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "creatureId" uuid NOT NULL,
    "ownerUuid" uuid NOT NULL,
    "timestamp" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "event" text NOT NULL,
    "prose" text NOT NULL DEFAULT ''::text,
    "statDelta" json
);

-- Indexes
CREATE INDEX "journal_entry_creature_idx" ON "journal_entry" USING btree ("creatureId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "creature_personality"
    ADD CONSTRAINT "creature_personality_fk_0"
    FOREIGN KEY("creatureId")
    REFERENCES "creature"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR tamagotchi
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('tamagotchi', '20260605160830908', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260605160830908', "timestamp" = now();

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
