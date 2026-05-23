# tamagotchi_server — Serverpod backend

## Generated code: the spy → generate cycle
After editing any `*.spy.yaml` (Serverpod protocol/endpoint defs), run `serverpod generate` from this directory. It regenerates files in both `lib/src/generated/` (server) and `../tamagotchi_client/lib/src/protocol/` (client). Skipping it leaves the client out of sync and tests fail with confusing errors. Both generated trees are excluded from the analyzer, so mistakes only surface at runtime.

## Tests need sidecars
Integration tests in `test/integration/` require Postgres (port 8090). Bring it up with `docker compose up -d` from this directory before `dart test`. Cryptic socket errors usually mean the sidecar isn't running. This project does not use Redis — `redis.enabled` is `false` in every runmode config.

## Endpoints
- Endpoint classes live in their feature's directory under `lib/src/` and extend `Endpoint`. They auto-register — no manual wiring.
- First parameter of every endpoint method is `Session session`. Method signatures map 1:1 to RPC.

## Migrations
- Create: `serverpod create-migration` (diffs current vs. last schema).
- Apply: `dart bin/main.dart --apply-migrations` from this directory.
- Never hand-edit a migration that has already been applied — write a new one.

## Secrets and config
- Runmode configs: `config/{development,test,staging,production}.yaml`.
- Passwords: `config/passwords.yaml` (local only) or `SERVERPOD_PASSWORD_*` env vars in deployed/CI environments.
- Never commit a real secret into `passwords.yaml` or a workflow file — use env vars / GitHub Actions secrets.
