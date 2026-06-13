#!/usr/bin/env bash
# ts-stop.sh — Stop hook
# Computes elapsed time since session start and emits a formatted stop time system message.
# NO jq, NO python3, NO npm — pure POSIX bash + date only (NN-C-002)
# ALL error paths exit 0 with valid JSON (NN-C-005)

input=$(cat)

# Re-entry guard MUST be the first substantive check (before any file I/O)
stop_hook_active=$(echo "$input" | grep -o '"stop_hook_active"[[:space:]]*:[[:space:]]*[a-z]*' | sed 's/.*"stop_hook_active"[[:space:]]*:[[:space:]]*//')

if [ "$stop_hook_active" = "true" ]; then
  echo "{}"
  exit 0
fi

session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

now=$(date +%s)
recv_time=$(date +"%H:%M:%S")

# If session_id is empty we cannot locate the start file — emit no-elapsed message
if [ -z "$session_id" ]; then
  echo "{\"systemMessage\": \"← ${recv_time}\"}"
  exit 0
fi

# Guard against path traversal — session_id must be alphanumeric/hyphens only
case "$session_id" in
  *[^a-zA-Z0-9_-]*)
    echo "{\"systemMessage\": \"← ${recv_time}\"}"
    exit 0
    ;;
esac

state_dir="$HOME/.claude/timestamp-hooks"
start_file="$state_dir/${session_id}.start"

# If start file is absent or empty, emit no-elapsed message
if [ ! -f "$start_file" ] || [ ! -s "$start_file" ]; then
  echo "{\"systemMessage\": \"← ${recv_time}\"}"
  exit 0
fi

# Read the start epoch; on failure emit bare JSON and exit cleanly
start=$(cat "$start_file" 2>/dev/null)
if [ -z "$start" ]; then
  rm -f "$start_file" 2>/dev/null
  echo "{\"systemMessage\": \"← ${recv_time}\"}"
  exit 0
fi

# Validate that start looks like a number
case "$start" in
  ''|*[!0-9]*)
    echo "{\"systemMessage\": \"← ${recv_time}\"}"
    rm -f "$start_file" 2>/dev/null
    exit 0
    ;;
esac

elapsed=$((now - start))

# Guard against negative elapsed (clock skew, NTP step, VM resume)
if [ "$elapsed" -lt 0 ]; then
  echo "{\"systemMessage\": \"← ${recv_time}\"}"
  rm -f "$start_file" 2>/dev/null
  exit 0
fi

# Format elapsed time
if [ "$elapsed" -lt 60 ]; then
  elapsed_str="${elapsed}s"
else
  elapsed_str="$((elapsed / 60))m $((elapsed % 60))s"
fi

# Clean up start file
rm -f "$start_file" 2>/dev/null

echo "{\"systemMessage\": \"← ${recv_time} (${elapsed_str})\"}"
