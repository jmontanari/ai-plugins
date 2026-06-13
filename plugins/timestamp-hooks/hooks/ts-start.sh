#!/usr/bin/env bash
# ts-start.sh — UserPromptSubmit hook
# Records session start epoch and emits a formatted start time system message.
# NO jq, NO python3, NO npm — pure POSIX bash + date only (NN-C-002)
# ALL error paths exit 0 with valid JSON (NN-C-005)

input=$(cat)

session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

# Validate session_id — must be non-empty
if [ -z "$session_id" ]; then
  echo "{}"
  exit 0
fi

# Guard against path traversal — session_id must be alphanumeric/hyphens only
case "$session_id" in
  *[^a-zA-Z0-9_-]*)
    echo "{}"
    exit 0
    ;;
esac

state_dir="$HOME/.claude/timestamp-hooks"

# Create state dir; on failure fall through to error guard
if ! mkdir -p "$state_dir" 2>/dev/null; then
  echo "{}"
  exit 0
fi
chmod 700 "$state_dir" 2>/dev/null

# Opportunistic TTL sweep — remove .start files older than 1 day
find "$state_dir" -name '*.start' -mtime +1 -delete 2>/dev/null

now=$(date +%s)
start_time=$(date +"%H:%M:%S")

# Write start epoch; on failure emit bare JSON and exit cleanly
if ! echo "$now" > "$state_dir/${session_id}.start" 2>/dev/null; then
  echo "{}"
  exit 0
fi

echo "{\"systemMessage\": \"→ ${start_time}\"}"
