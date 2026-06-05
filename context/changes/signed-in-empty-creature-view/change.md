---
change_id: signed-in-empty-creature-view
title: Signed in empty creature view
status: deferred
created: 2026-06-04
updated: 2026-06-05
# status: `deferred` (2026-06-05) — Phases 1–6 committed; Phase 7 (EmailLabs sender-auth + DNS) is blocked on DNS control-panel access for the codecreations.eu zone (operator contacted, ETA unknown). Resume Phase 7 when DNS access is restored.
archived_at: null
---

## Notes

<!-- Free-form notes for this change: links, ad-hoc context, decisions that don't belong in research/frame/plan. -->

- **2026-06-05 — Prod SMTP egress blocked (Phase 5 finding; blocks the Phase 6 acceptance gate).** On scloud deploy `89894694`, a prod registration reached the EmailLabs send but failed with `SocketException: Connection timed out` to `smtp.emaillabs.net.pl:587` (errno 110). EmailLabs 587/465 are reachable from the devcontainer (→ 185.49.13.184), so the block is **scloud-side egress** (outbound SMTP appears categorically blocked). Phase 6 DNS authorization is necessary but **not sufficient**. Recommended fix: send over HTTPS (443) via the **EmailLabs REST API** (`api.emaillabs.net.pl`, REST AppKey/SecretKey — not the SMTP-account creds) — a code change to the Phase 2 send branch, so **Phase 6 likely needs a re-plan**. Detail: `context/foundation/infrastructure.md` → "S-01 Production Deploy & EmailLabs Secrets" → "After this deploy".
- **2026-06-05 — Phase 6 re-planned into two gates** (via `/10x-frame` → `/10x-plan`; see `frame.md`). **Phase 6** = transport pivot: replace the SMTP body of `_sendVerificationEmail` with an HTTPS POST to EmailLabs `new_sendmail` over 443, drop `mailer`, add `http`, provision `emaillabsApiKey`/`emaillabsApiSecret` scloud secrets, redeploy, and prove outbound 443 egress. **Phase 7 (FINAL)** = EmailLabs sender-auth + DNS (SPF/DKIM/DMARC `p=none`) + the production register→email→login→home→logout acceptance test. Decisions: prove-443 via a real prod registration (no throwaway probe); rethrow on non-2xx from `new_sendmail`. See `plan.md` Phases 6–7.
- **2026-06-05 — Phase 6 transport pivot implemented (code + docs).** `server.dart`'s `_sendVerificationEmail` now POSTs to EmailLabs `new_sendmail` over 443 (Basic `AppKey:SecretKey`, form body `smtp_account`/`to[<email>]`/`from`/`subject`/`text`; throws on non-2xx or `status != "success"` and on network failure — a verification-code flow must fail loudly). Dropped `mailer`, added `http: ^1.6.0`; `dart pub get` + `dart analyze` clean. The run-mode gate and dev static-code bypass are unchanged. `infrastructure.md` "S-01 Production Deploy & EmailLabs Secrets" updated for the REST transport (two new `emaillabsApiKey`/`emaillabsApiSecret` secret commands; `emaillabsSmtpUser`/`emaillabsSmtpFrom` reused; `emaillabsSmtpPassword` now unused). **Verified on prod (deploy `9d43a330`, 2026-06-05):** a prod registration now **reaches EmailLabs over 443** — `new_sendmail` returned `HTTP 401 {code:401,status:"error",message:"Error: App Key is invalid",req_id:...}` (logged at ERROR, then thrown), **not** the prior `SocketException`/TCP timeout. Outbound 443 egress is proven; the frame's one residual transport risk is retired. ⚠️ **Open before Phase 7 acceptance:** the 401 `App Key is invalid` is a **credentials** rejection (EmailLabs parsed the Basic-auth AppKey and didn't recognize it) — a code-independent issue distinct from DNS/sender-auth. Re-check the provisioned `emaillabsApiKey`/`emaillabsApiSecret` against EmailLabs panel → Administrator → API (correct values, no whitespace, not swapped, API access enabled). Deliverability (DNS sender-auth) is Phase 7.
- **2026-06-05 — Phase 7 DEFERRED (blocked on DNS access).** Phase 6 credentials fix verified on prod: `new_sendmail` now returns **HTTP 500 `"SMTP account is not authorized to send from no-reply@tamagotchi.codecreations.eu"`** (the expected pre-authorization rejection — auth works, only sender-auth/DNS remains; the 401 is retired). EmailLabs Sender Authorization was started in the panel and emitted a **CNAME-delegated** record set (chosen approach: **Option B — panel-exact, no added SPF TXT, DMARC stays an EmailLabs-managed CNAME**). The four records to publish in the **Cloudflare `codecreations.eu` zone** (DNS-only / grey cloud, short Name — Cloudflare appends the zone):
  | Name | Type | Value |
  |---|---|---|
  | `default._domainkey.tamagotchi` | CNAME | `c6cce8-8dc371.dkimbox.com` |
  | `mailing.tamagotchi` | CNAME | `d8b0d5-565945.dkimbox.com` |
  | `tracking.tamagotchi` | CNAME | `tracking.dkimbox.com` |
  | `_dmarc.tamagotchi` | CNAME | `354499-be9384.dkimbox.com` |

  **Blocker:** no access to the codecreations.eu DNS control panel; operator contacted (ETA unknown). **Resume steps when access returns:** publish the 4 CNAMEs → click **Check → Accepted** in the EmailLabs panel → ping the agent to `dig`-verify the CNAMEs resolve to their `dkimbox.com` targets (adapted 7.1/7.2 check — no SPF TXT / no own DMARC TXT under Option B) → run the prod acceptance test (register → real email from `tamagotchi.codecreations.eu` → code → login → empty-creature home → logout) → set `status: complete`. Note: the DKIM CNAME is the record that clears the 500.
