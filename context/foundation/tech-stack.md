---
starter_id: flutter
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
  quality_override: true
  self_check_answers:
    typed: true
    from_official_starter: true
    conventions: true
    docs_current: true
    can_judge_agent: true
  has_auth: true
  has_payments: false
  has_realtime: true
  has_ai: true
  has_background_jobs: false
---

## Why this stack

Solo developer building a virtual pet web-app with AI-driven personality, auth (email + OAuth), and real-time stat mechanics in a 3-week after-hours timeline. Dart/Flutter + Serverpod was chosen deliberately over the JS-dominant recommended defaults — the developer has Dart expertise, wants a single-language full-stack, and can spot non-idiomatic agent output. Serverpod provides PostgreSQL ORM, built-in auth, websocket support, and type-safe code generation between client and server. Serverpod Cloud handles deployment. The stack falls outside the registry's coverage (closest entry: flutter) and fails one agent-friendly criterion (Serverpod's limited training-data presence within Dart), accepted as a known-friction choice with instruction-file compensation planned. Bootstrapper confidence is best-effort — manual scaffolding steps are expected. Development happens inside a devcontainer managed by DevPod with Colima as the Docker engine, accessed via SSH.
