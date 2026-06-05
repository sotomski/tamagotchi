---
change_id: signed-in-empty-creature-view
title: Signed in empty creature view
status: implementing
created: 2026-06-04
updated: 2026-06-05
# status stays `implementing` (Phases 1–5 committed); Phase 6 was re-planned, not the whole change reset to `planned`.
archived_at: null
---

## Notes

<!-- Free-form notes for this change: links, ad-hoc context, decisions that don't belong in research/frame/plan. -->

- **2026-06-05 — Prod SMTP egress blocked (Phase 5 finding; blocks the Phase 6 acceptance gate).** On scloud deploy `89894694`, a prod registration reached the EmailLabs send but failed with `SocketException: Connection timed out` to `smtp.emaillabs.net.pl:587` (errno 110). EmailLabs 587/465 are reachable from the devcontainer (→ 185.49.13.184), so the block is **scloud-side egress** (outbound SMTP appears categorically blocked). Phase 6 DNS authorization is necessary but **not sufficient**. Recommended fix: send over HTTPS (443) via the **EmailLabs REST API** (`api.emaillabs.net.pl`, REST AppKey/SecretKey — not the SMTP-account creds) — a code change to the Phase 2 send branch, so **Phase 6 likely needs a re-plan**. Detail: `context/foundation/infrastructure.md` → "S-01 Production Deploy & EmailLabs Secrets" → "After this deploy".
- **2026-06-05 — Phase 6 re-planned into two gates** (via `/10x-frame` → `/10x-plan`; see `frame.md`). **Phase 6** = transport pivot: replace the SMTP body of `_sendVerificationEmail` with an HTTPS POST to EmailLabs `new_sendmail` over 443, drop `mailer`, add `http`, provision `emaillabsApiKey`/`emaillabsApiSecret` scloud secrets, redeploy, and prove outbound 443 egress. **Phase 7 (FINAL)** = EmailLabs sender-auth + DNS (SPF/DKIM/DMARC `p=none`) + the production register→email→login→home→logout acceptance test. Decisions: prove-443 via a real prod registration (no throwaway probe); rethrow on non-2xx from `new_sendmail`. See `plan.md` Phases 6–7.
