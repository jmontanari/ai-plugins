---
charter_snapshot:
  architecture: "2026-06-01"
  non-negotiables: "2026-06-01"
  coding-rules: "2026-06-01"
jira_key: ~
jira_url: ~
---

# Brief: fix-json-escape — Replace slow bash JSON escaper in session-start hook

## Problem Statement

`escape_for_json()` in `plugins/spec-flow/hooks/session-start` (lines 54–62) performs 5
whole-string bash substitutions per call (`${s//...}`). Bash string ops are O(n) per pass;
with 5 passes on 125KB of charter content, the two large calls (doctrine ~19KB, charter
content up to 100KB+) take >2 seconds total — exceeding the harness auto-background
threshold. The result is a >1 minute delay before session-start context appears in repos
with multi-domain `doctrine_load` configs.

## Functional Requirements

- FR-1: Replace the `escape_for_json()` function body with a Python3-based implementation
  that pipes content via stdin through `python3 -c "import json,sys; ..."`, completing in
  ~1ms regardless of input size.
- FR-2: Include a bash fallback: if `python3` is not on PATH, fall back to the current
  pure-bash substitution logic. The hook must still exit 0 with valid JSON output on
  machines without Python3 (NN-C-005).
- FR-3: All 6 call sites in `session-start` continue to use the same `escape_for_json`
  signature with no changes at the call sites.
- FR-4: Amend NN-C-002 in `.claude/skills/charter-non-negotiables/SKILL.md` to document
  the Python3 exception: permitted in `hooks/` as an optional fast path when available,
  with a mandatory bash fallback.
- FR-5: Bump plugin version 5.1.0 → 5.1.1 in all version-bearing files; add a CHANGELOG
  entry under `Fixed`.

## Acceptance Criteria

1. AC-1: With Python3 available, `escape_for_json` on a 125KB string completes in <100ms
   (wall-clock measured via `time`).
2. AC-2: With Python3 shadowed/absent (tested by temporarily setting PATH to exclude it),
   the function falls back to bash and the hook still exits 0 with valid JSON on stdout.
3. AC-3: The Python3 path and bash path produce byte-for-byte identical output for the
   same input, verified across all 5 escape sequences (`\`, `"`, `\n`, `\r`, `\t`).
4. AC-4: NN-C-002 in `.claude/skills/charter-non-negotiables/SKILL.md` contains an
   explicit "Python3 in hooks" exception clause with the bash-fallback requirement.
5. AC-5: `plugins/spec-flow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
   both reflect version 5.1.1, and `plugins/spec-flow/CHANGELOG.md` has a `## [5.1.1]`
   section with a `Fixed` entry describing the hook performance fix.

## Non-Negotiables Honored

- NN-C-002 (no runtime deps): Amended to add explicit Python3 exception in hooks; bash
  fallback ensures the hook works on a bare POSIX machine without Python3.
- NN-C-005 (hooks no-op on missing deps): Bash fallback path preserves existing behavior
  when Python3 is absent — hook exits 0 with valid JSON in all cases.
- NN-C-009 (version bump): Bug fix in plugin source → patch bump 5.1.0 → 5.1.1.
- NN-C-001 (version sync): plugin.json and marketplace.json updated together.

## Coding Rules Honored

- CR-004 (conventional-commits): Commit will use `fix(spec-flow): ...` format.

## Out of Scope

- Caching escaped output across sessions
- Reducing the `doctrine_load` list size
- Any other hooks (only `session-start` contains `escape_for_json`)
- Windows (WSL aside) — target platforms are macOS and Linux
- Skipping the fast path for small-string call sites (lines 87/88/98/102) — single
  function body is simpler; overhead on small strings is negligible
