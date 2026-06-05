# Frame Brief: Production transactional email undeliverable on scloud (S-01 Phase 6)

> Framing step before /10x-plan. This document captures what is *actually*
> at issue, separated from what was initially assumed.

## Reported Observation

On production (scloud deploy `89894694`), a registration reaches the EmailLabs
send and fails with:

```
SocketException: Connection timed out, host: smtp.emaillabs.net.pl, port: 587 (errno 110)
  ... _sendVerificationEmail (tamagotchi_server/lib/server.dart)
```

The verification email is never delivered; registration cannot complete on prod.

## Initial Framing (preserved)

- **User's stated cause or approach**: scloud blocks outbound SMTP egress; the SMTP transport (`mailer`/`SmtpServer` on 587) is the broken dimension.
- **User's proposed direction**: switch the EmailLabs send transport in `server.dart`'s verification-code callbacks from SMTP to EmailLabs' REST API (`POST https://api.emaillabs.net.pl/api/new_sendmail` over HTTPS/443, Basic `AppKey:SecretKey`); keep the provider and the planned Phase 6 DNS sender-authorization work.
- **Pre-dispatch narrowing**: single, well-isolated observation (one symptom: prod SMTP send times out at TCP connect). No scope ambiguity to resolve — extended narrowing skipped, evidence already conclusive (see below).

## Dimension Map

Where could "production verification email is never delivered" originate?

1. **Transport / network egress** — can the container open a socket to the mail service? scloud blocks outbound SMTP (25/465/587).  ← **initial framing lands here**
2. **Sender authorization / DNS deliverability** — even when sent, mail is rejected/spam-filed without SPF/DKIM for `tamagotchi.codecreations.eu`. *(This was the original "Phase 6 = DNS only" framing.)*
3. **Credentials / endpoint config** — wrong host/port/creds for the send.
4. **Provider fit** — EmailLabs is the wrong provider (e.g. no HTTP fallback over 443).
5. **Callback wiring / code** — the IDP send callback doesn't fire or is malformed.

## Hypothesis Investigation

| Hypothesis | Evidence | Verdict |
| --- | --- | --- |
| **1. Transport/egress blocked** | `errno 110` (ETIMEDOUT) at TCP connect from the container — a silent SYN drop, not a refusal; ports 587 **and** 465 reachable from the devcontainer (`smtp.emaillabs.net.pl`→185.49.13.184) but time out from scloud; outbound SMTP block confirmed on Serverpod Discord (2026-06-05). Serverpod's email callback is transport-agnostic (`server.dart:161-193` is hand-rolled), so SMTP is a *choice*, not a requirement. | **STRONG** |
| **2. DNS / sender-auth (original Phase 6)** | Real second gate — the subdomain isn't yet authorized — but it is **downstream** of transport and currently masked: the send never connects, so deliverability is never exercised. A timeout is not a bounce/spam signal. | **WEAK as the current blocker** (valid, but latent) |
| **3. Credentials / config** | Host resolves and is externally reachable; failure is a TCP timeout, not an auth reject (`535`/`401`). Creds were accepted into `SmtpServer(...)` and never evaluated. | **NONE** |
| **4. Provider fit** | EmailLabs exposes a transactional REST API over 443 (`new_sendmail`, Basic `AppKey:SecretKey`) reusing our existing `smtp_account` + From. Provider is not the broken dimension; switching adds an account/DNS/secrets migration for no benefit. | **NONE** (no reason to switch provider) |
| **5. Callback wiring / code** | The send fired: stack reaches `_sendVerificationEmail` → `mailer` → connect. Callbacks are correctly run-mode-gated (`server.dart:105-150`); dev bypass unaffected (`server.dart:20,36-46`). Code is wired right. | **NONE** |

## Narrowing Signals

- **Timeout vs refusal/auth-reject** → isolates Dimension 1 over 3/5: the failure is at the network layer, before any SMTP dialogue.
- **587 + 465 both blocked from scloud, both open from the devcontainer** → the block is the platform's egress policy, not host/port/cred error and not a transient outage.
- **Discord confirmation** → it is a *deliberate, categorical* SMTP block, so no port-switch (465/25) rescues SMTP; only a non-SMTP transport does.
- **`server.dart:161-193` is hand-rolled and transport-agnostic** → swapping SMTP→HTTP is a localized change to one function + its imports; nothing upstream (callbacks, gating, dev bypass) needs to move.

## Cross-System Convention

Universal PaaS pattern: AWS/GCP/Azure/DigitalOcean/Render block outbound SMTP to fight spam and direct apps to an **HTTP email API over 443**. scloud follows the same convention. The leading hypothesis matches the convention exactly; the original "DNS-only" framing was the standard *deliverability* checklist applied without first checking that the transport is permitted at all.

## Reframed (or Confirmed) Problem Statement

> **The actual problem to plan around is**: production transactional email is undeliverable because the chosen *transport* (SMTP) is categorically blocked by scloud's egress policy — not because of DNS/sender-auth (a real but downstream gate) and not because of the provider (EmailLabs offers a 443 REST API).

The user's framing is **confirmed and sharpened**. "Switch transport, keep provider, keep DNS" is correct. The one real correction to the *prior* plan: Phase 6's "DNS only" was **incomplete, not wrong** — DNS addresses the downstream deliverability gate (Dimension 2); it never addresses the upstream transport gate (Dimension 1) that blocks every send before deliverability is ever reached. Both gates must be cleared. Switching providers or petitioning scloud to unblock SMTP are dominated alternatives (more cost / depends on a support exception / no working path today).

## Confidence

**HIGH** — strong, multi-source evidence (empirical port probe + Discord + framework docs + localized source), matches the universal cloud convention, decisive narrowing signal (timeout-not-refusal).

One residual to verify (does not lower confidence, but name it): the REST fix assumes **outbound 443 egress from the scloud container is open**. This is the platform norm (SMTP-specific blocking is the anomaly), but it is not yet empirically proven for *this* container — it is proven the moment the REST send returns a `200`/`401` from EmailLabs instead of a timeout. First verification step in planning/implementation: confirm a `new_sendmail` call from prod reaches EmailLabs (any HTTP response, even `401`, proves egress).

## What Changes for /10x-plan

Re-plan Phase 6 around **two gates, not one**: (a) a transport change — replace the SMTP body of `_sendVerificationEmail` (`server.dart:161-193`) with an HTTPS POST to EmailLabs `new_sendmail` (`package:http`, Basic `AppKey:SecretKey`, params `smtp_account`/`to[]`/`from`/`subject`/`html`+`text`), drop the `mailer` dep, and provision two new scloud secrets `emaillabsApiKey`/`emaillabsApiSecret` (reuse `emaillabsSmtpUser` as `smtp_account` + `emaillabsSmtpFrom`; the SMTP-account password becomes unused); and (b) the existing DNS sender-authorization. Plan may sequence (a) and (b) as separate phases — they're independent (code+secrets+redeploy vs. panel+registrar) — with the production register→email→login→home→logout acceptance test as the final gate. First implementation step proves outbound 443.

## References

- Source (transport): `tamagotchi_server/lib/server.dart:161-193` (`_sendVerificationEmail`, SMTP); callbacks `:105-150`; dev bypass `:20,36-46`
- Prior plan (incomplete Phase 6): `context/changes/signed-in-empty-creature-view/plan.md` §Phase 6
- Phase 5 finding (durable): same change `change.md` Notes; `context/foundation/infrastructure.md` → "S-01 Production Deploy & EmailLabs Secrets" → "After this deploy"
- EmailLabs `new_sendmail` contract: `POST https://api.emaillabs.net.pl/api/new_sendmail`, Basic `base64(AppKey:SecretKey)`, `application/x-www-form-urlencoded`; required `smtp_account`, `to[<email>]`, `from`, `subject`, `html`/`text`; JSON `{code,status,message,data}`
- Memory: [[project-tamagotchi-email-emaillabs]] (updated), [[project-scloud-auto-manages-secrets-and-db-config]]
- Investigation: inline (empirical TCP probe of 587/465, Serverpod docs via context7 + web, EmailLabs API docs, source read) — no sub-agents needed; evidence conclusive per Frame Step 4.
