---
charter_snapshot:
  architecture: "2026-06-13"
  non-negotiables: "2026-06-13"
  tools: "2026-06-13"
  processes: "2026-06-13"
  flows: "2026-06-13"
  coding-rules: "2026-06-13"
tdd: false
---

# Plan: timestamp-hooks

**Brief:** docs/changes/timestamp-hooks/brief.md
**Status:** draft

## Overview

Two phases: core hook scripts first (the behavioral work), then plugin packaging.
Both use Implement track — bash hook scripts are infrastructure/tooling code
where TDD would be ceremony, verified by smoke-testing against simulated payloads.

Phase 1 produces two hooks: `ts-start.sh` fires on `UserPromptSubmit` (emits send
timestamp via systemMessage + writes start epoch file), and `ts-stop.sh` fires on
`Stop` (reads start epoch, computes elapsed, emits receive+elapsed systemMessage).
Phase 2 wires the plugin metadata and marketplace entry.

## Phases

### Phase 1: Core hook scripts

**Exit Gate:** `bash plugins/timestamp-hooks/hooks/ts-stop.sh` with a simulated
stdin payload exits 0 and outputs valid JSON; smoke-test against a real Claude
session confirms "Sent" notice before the message and "Received — Xm Ys" after.
**ACs Covered:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-6
**Phase type:** feature
**In scope:** `plugins/timestamp-hooks/hooks/ts-start.sh`, `plugins/timestamp-hooks/hooks/ts-stop.sh`
**NOT in scope:** plugin.json, hooks.json, marketplace.json, docs (Phase 2)
**Charter constraints honored in this phase:**
- NN-C-002 (no runtime deps): pure POSIX bash + `date` only; no jq (use grep/sed for JSON parsing)
- NN-C-005 (silent no-op): all error paths exit 0 with valid JSON `{}`

- [ ] **[Implement]**

  **`plugins/timestamp-hooks/hooks/ts-start.sh`** (UserPromptSubmit):
  - Create `~/.claude/timestamp-hooks/` dir if absent (`mkdir -p`)
  - Parse `session_id` from stdin JSON using grep/sed (no jq dependency)
  - Get current epoch: `now=$(date +%s)`
  - Write epoch to `~/.claude/timestamp-hooks/${session_id}.start`
  - Format local time (HH:MM:SS only): `date +"%H:%M:%S"`
  - Output JSON with systemMessage: `→ <HH:MM:SS>`
  - On any error (unwritable dir, malformed stdin): output `{}`, exit 0

  **`plugins/timestamp-hooks/hooks/ts-stop.sh`** (Stop):
  - Parse `session_id` and `stop_hook_active` from stdin JSON using grep/sed
  - If `stop_hook_active == true`: output `{}`, exit 0 immediately (re-entry guard)
  - Get current epoch: `now=$(date +%s)`
  - Format receive time: `recv_time=$(date +"%H:%M:%S")`
  - Read start epoch from `~/.claude/timestamp-hooks/${session_id}.start`
  - If absent or empty: output systemMessage `← <recv_time>` (no elapsed), exit 0
  - Compute: `elapsed=$((now - start))`
  - Format elapsed: if < 60s → `${elapsed}s`; else → `$((elapsed/60))m $((elapsed%60))s`
  - Output JSON with systemMessage: `← <recv_time> (<elapsed>)`
  - Clean up: remove `~/.claude/timestamp-hooks/${session_id}.start`
  - On any error (unreadable file, bad parse): output `{}`, exit 0

  systemMessage JSON format:
  ```json
  {"systemMessage": "→ 19:01:32"}
  {"systemMessage": "← 19:02:14 (42s)"}
  {"systemMessage": "← 19:02:14 (1m 2s)"}
  ```

- [ ] **[Verify]**
  - `echo '{"session_id":"test-abc","hook_event_name":"UserPromptSubmit"}' | bash plugins/timestamp-hooks/hooks/ts-start.sh`
    → exits 0, outputs `{"systemMessage": "→ HH:MM:SS"}`, creates `~/.claude/timestamp-hooks/test-abc.start`
  - `echo '{"session_id":"test-abc","stop_hook_active":false,"hook_event_name":"Stop"}' | bash plugins/timestamp-hooks/hooks/ts-stop.sh`
    → exits 0, outputs `{"systemMessage": "← HH:MM:SS (Xs)"}` with real elapsed
  - `echo '{"session_id":"no-such-session","stop_hook_active":false,"hook_event_name":"Stop"}' | bash plugins/timestamp-hooks/hooks/ts-stop.sh`
    → exits 0, outputs `{"systemMessage": "← HH:MM:SS"}` (no elapsed — no start file)
  - `echo '{"session_id":"test-abc","stop_hook_active":true,"hook_event_name":"Stop"}' | bash plugins/timestamp-hooks/hooks/ts-stop.sh`
    → exits 0, outputs `{}`

### Phase 2: Plugin packaging

**Exit Gate:** `diff <(jq -r .version plugins/timestamp-hooks/plugin.json) <(jq -r '.plugins[] | select(.name == "timestamp-hooks") | .version' .claude-plugin/marketplace.json)` produces no output; `grep '## \[0.1.0\]' plugins/timestamp-hooks/CHANGELOG.md` matches.
**ACs Covered:** AC-7
**Phase type:** feature
**In scope:** `plugins/timestamp-hooks/plugin.json`, `plugins/timestamp-hooks/.claude-plugin/hooks.json`,
`plugins/timestamp-hooks/CHANGELOG.md`, `plugins/timestamp-hooks/CLAUDE.md`,
`plugins/timestamp-hooks/README.md`, `.claude-plugin/marketplace.json`
**NOT in scope:** hook script changes (Phase 1)
**Charter constraints honored in this phase:**
- NN-C-001 (version sync): plugin.json + marketplace.json both at 0.1.0
- NN-C-007 (CHANGELOG): Keep a Changelog format, Added section
- NN-C-009 (always bump): all version-bearing files updated together
- CR-005 (repo-relative paths): README uses `plugins/timestamp-hooks/...` paths
- CR-006 (CHANGELOG format): uses Added / groupings

- [ ] **[Implement]**

  **`plugins/timestamp-hooks/plugin.json`:**
  ```json
  {
    "name": "timestamp-hooks",
    "description": "Shows send/receive timestamps and elapsed time for each Claude Code message exchange",
    "version": "0.1.0",
    "author": {"name": "Joe"},
    "license": "MIT",
    "hooks": "./.claude-plugin/hooks.json"
  }
  ```

  **`plugins/timestamp-hooks/.claude-plugin/hooks.json`:**
  ```json
  {
    "description": "Timestamp hooks — fires on message send and response complete",
    "hooks": {
      "UserPromptSubmit": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/ts-start.sh"}],
      "Stop": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/ts-stop.sh"}]
    }
  }
  ```

  **`plugins/timestamp-hooks/CHANGELOG.md`:** Keep a Changelog format, `## [0.1.0] — 2026-06-13`,
  Added section listing the two hook scripts and plugin packaging.

  **`plugins/timestamp-hooks/CLAUDE.md`:** Brief description of what the plugin does,
  how to install (add to hooks config), and what systemMessage output looks like.

  **`plugins/timestamp-hooks/README.md`:** Installation, output format example, state
  file location (`~/.claude/timestamp-hooks/`), and NN-C-002 compliance note.

  **`.claude-plugin/marketplace.json`:** Add entry for `timestamp-hooks` at version `0.1.0`.

- [ ] **[Verify]**
  - `diff <(jq -r .version plugins/timestamp-hooks/plugin.json) <(jq -r '.plugins[] | select(.name == "timestamp-hooks") | .version' .claude-plugin/marketplace.json)` → no output
  - `grep '## \[0.1.0\]' plugins/timestamp-hooks/CHANGELOG.md` → matches
  - `ls plugins/timestamp-hooks/hooks/` → shows ts-start.sh and ts-stop.sh
