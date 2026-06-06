#!/usr/bin/env bash
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
SERVER="$PROJECT_ROOT/tamagotchi_server"
FLUTTER="$PROJECT_ROOT/tamagotchi_flutter"

# Format silently — rewrites in place, always succeeds.
dart format "$SERVER" > /dev/null 2>&1 || true
dart format "$FLUTTER" > /dev/null 2>&1 || true

# Analyze — report errors; exit 2 if any found so Claude fixes them.
server_out=$(dart analyze --fatal-infos "$SERVER" 2>&1)
server_ok=$?
flutter_out=$(flutter analyze "$FLUTTER" 2>&1)
flutter_ok=$?

if [[ $server_ok -ne 0 || $flutter_ok -ne 0 ]]; then
  echo "=== dart analyze: tamagotchi_server ===" >&2
  echo "$server_out" >&2
  echo "=== flutter analyze: tamagotchi_flutter ===" >&2
  echo "$flutter_out" >&2
  exit 2
fi
