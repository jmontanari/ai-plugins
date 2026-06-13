---
charter_snapshot:
  architecture: "2026-06-13"
  non-negotiables: "2026-06-13"
  tools: "2026-06-13"
  processes: "2026-06-13"
  flows: "2026-06-13"
  coding-rules: "2026-06-13"
---

# Brief: timestamp-hooks — Per-message timing visibility plugin

## Problem Statement

When using Claude Code there is no visibility into when a message was sent, when
the response arrived, or how long each exchange took. This plugin adds that
visibility by surfacing a timestamp notice before each message is sent and again
after each response — showing the send time, receive time, and elapsed duration —
so the user can immediately see how long each exchange is taking within a session.

## Functional Requirements

- Capture the epoch timestamp when the user submits a message (UserPromptSubmit hook)
- Emit a systemMessage showing the send timestamp before the message is processed
- Capture the epoch timestamp when Claude finishes responding (Stop hook)
- Compute elapsed time: seconds only when < 60s, `Xm Ys` when ≥ 60s
- Emit a systemMessage showing receive time and elapsed after each response
- Guard against Stop-hook re-entry: if `stop_hook_active` is true, exit 0 silently
- Guard against missing start: if no start epoch exists, emit "start unavailable" and skip elapsed
- All hooks exit 0 with valid JSON in all error paths (NN-C-005)
- No runtime dependencies beyond Claude Code, git, and POSIX bash (NN-C-002)

## Acceptance Criteria

1. AC-1: When the user submits a message, a systemMessage appears immediately showing
   the send time only: `→ 19:01:32`
2. AC-2: After each Claude response, a systemMessage appears showing receive time and
   elapsed: `← 19:02:14 (42s)` when elapsed < 60s, or `← 19:02:14 (1m 2s)` when ≥ 60s
3. AC-3: When Stop fires with `stop_hook_active=true`, the hook exits 0 silently —
   no duplicate timing lines on re-entry.
4. AC-4: When Stop fires with no valid start timestamp (first message, resumed session,
   start hook error), systemMessage shows `← 19:02:14` (time only, no elapsed).
5. AC-5: Both hooks exit 0 with valid JSON in all error conditions (missing dirs,
   unreadable files, malformed stdin).
6. AC-6: Plugin installs and works on a fresh machine with only Claude Code + git + bash —
   no npm, pip, or additional binaries.
7. AC-7: Plugin version is consistent across `plugin.json` and `marketplace.json`
   (initial release at `0.1.0`).

## Non-Negotiables Honored

- NN-C-001 (version sync): plugin.json and marketplace.json both set to 0.1.0 in same commit.
- NN-C-002 (no runtime deps): hooks use only POSIX bash + `date`; no python3, no npm.
- NN-C-005 (silent no-op): hooks exit 0 + valid JSON on missing state, missing dirs,
  or malformed input.
- NN-C-007 (CHANGELOG): CHANGELOG.md ships in Keep a Changelog format with an `## [0.1.0]` entry.
- NN-C-009 (always bump): all version-bearing files (plugin.json, marketplace.json, CHANGELOG.md)
  updated together.

## Coding Rules Honored

- CR-004 (conventional commits): commits use `feat(timestamp-hooks): ...` format.
- CR-005 (repo-relative paths): README references files by repo-root-relative paths.
- CR-006 (CHANGELOG format): CHANGELOG uses Keep a Changelog groupings.
- CR-009 (heading hierarchy): README/CLAUDE.md use H1 title + H2 sections.

## Out of Scope

- Rolling history log file
- `additionalContext` injection into Claude's context
- Sub-second precision
- Message content logging
- Session-level start/stop timestamps
- Copilot CLI co-ship
