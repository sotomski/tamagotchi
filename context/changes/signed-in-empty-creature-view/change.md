---
change_id: signed-in-empty-creature-view
title: Signed in empty creature view
status: implementing
created: 2026-06-04
updated: 2026-06-05
archived_at: null
---

## Notes

<!-- Free-form notes for this change: links, ad-hoc context, decisions that don't belong in research/frame/plan. -->

- **2026-06-05 — Prod SMTP egress blocked (Phase 5 finding; blocks the Phase 6 acceptance gate).** On scloud deploy `89894694`, a prod registration reached the EmailLabs send but failed with `SocketException: Connection timed out` to `smtp.emaillabs.net.pl:587` (errno 110). EmailLabs 587/465 are reachable from the devcontainer (→ 185.49.13.184), so the block is **scloud-side egress** (outbound SMTP appears categorically blocked). Phase 6 DNS authorization is necessary but **not sufficient**. Recommended fix: send over HTTPS (443) via the **EmailLabs REST API** (`api.emaillabs.net.pl`, REST AppKey/SecretKey — not the SMTP-account creds) — a code change to the Phase 2 send branch, so **Phase 6 likely needs a re-plan**. Detail: `context/foundation/infrastructure.md` → "S-01 Production Deploy & EmailLabs Secrets" → "After this deploy".
