---
starter_id: serverpod-flutter
package_manager: pub
project_name: ai-tamagotchi
hints:
  language_family: dart
  team_size: solo
  deployment_target: serverpod-cloud
  ci_provider: github-actions
  ci_default_flow: auto-deploy-on-merge
  bootstrapper_confidence: best-effort
  path_taken: custom
  quality_override: false
  self_check_answers:
    typed: true
    from_official_starter: true
    conventions: true
    docs_current: true
    can_judge_agent: true
  has_auth: true
  has_payments: false
  has_realtime: false
  has_ai: true
  has_background_jobs: true
---

## Why this stack

Brownfield project already scaffolded on Serverpod 3.4.8 (persistent Dart server,
Postgres 16 + pgvector, generated typed RPC client) plus Flutter 3.32 web client,
organised as a pub workspace under `tamagotchi/`. The custom path applies because
the recommended-defaults map shows `<none>` for `(web, dart)`; Serverpod + Flutter
is the only first-class Dart full-stack pairing and is the stack on disk. All
four agent-friendly gates pass per `stack-assessment.md`, with one known
compensation: Serverpod's training-data depth is shallow within the Dart family,
so runtime conventions for the codegen cycle, migrations, runmode configs, and
the Flutter↔server build coupling are carried in `CLAUDE.md`. PRD priors align —
solo learner, after-hours-only, 3-week MVP, web-app, auth + AI in scope: end-to-end
types reduce iteration friction, Serverpod's opinionated layout is agent-readable,
Flutter dominates the Dart training corpus. Deployment to Serverpod Cloud per
`infrastructure.md`; the `scloud` CLI is pre-installed in the devcontainer.
Background stat decay (FR-008) fits Serverpod's future-call API; no Redis is
needed under the single-instance topology. Bootstrapper confidence is best-effort
because no Serverpod card exists in the registry, but the project is already
scaffolded so the bootstrapper does not run.
