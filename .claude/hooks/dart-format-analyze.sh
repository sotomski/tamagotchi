#!/usr/bin/env bash
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
SERVER="$PROJECT_ROOT/tamagotchi_server"
FLUTTER="$PROJECT_ROOT/tamagotchi_flutter"

# Only run when Claude edited a Dart or pubspec.yaml file *this turn*. Read-only
# turns (research, planning, shell-only sessions) leave nothing to check, so we
# skip them. The Stop hook payload on stdin gives us the transcript; we scan the
# file-modifying tool calls (Edit/Write/MultiEdit/NotebookEdit) since the last
# genuine user prompt — i.e. the boundary of the current turn. If anything in
# this detection is unavailable (no jq, no transcript), we fall through and run
# the checks rather than risk silently skipping a needed pass.
payload=$(cat)
transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null || true)

if command -v jq > /dev/null 2>&1 && [[ -n "$transcript" && -f "$transcript" ]]; then
  touched=$(jq -s -r '
    # indices of genuine user prompts (tool results carry toolUseResult; prompts do not)
    [ to_entries[] | select(.value.type == "user" and (.value | has("toolUseResult") | not)) | .key ] as $prompts
    | (($prompts | last) // -1) as $turn_start
    | .[$turn_start + 1:][]
    | select(.type == "assistant")
    | .message.content[]?
    | select(.type == "tool_use"
        and (.name == "Edit" or .name == "Write" or .name == "MultiEdit" or .name == "NotebookEdit"))
    | (.input.file_path // .input.notebook_path // empty)
  ' "$transcript" 2>/dev/null | grep -E '(\.dart|pubspec\.yaml)$' || true)

  if [[ -z "$touched" ]]; then
    exit 0
  fi
fi

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
