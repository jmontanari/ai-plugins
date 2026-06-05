---
charter_snapshot:
  architecture: "2026-06-01"
  non-negotiables: "2026-06-01"
  coding-rules: "2026-06-01"
fast: false
---

# Plan: fix-json-escape — Replace slow bash JSON escaper in session-start hook

**Brief:** docs/changes/fix-json-escape/brief.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding)
**Status:** approved

## Overview

Two-phase implement-only change. Phase 1 replaces the `escape_for_json()` function body
in `hooks/session-start` with a Python3-with-bash-fallback implementation, and amends
NN-C-002 in the charter to document the exception. Phase 2 bumps the plugin version and
updates CHANGELOG. No new logic paths to TDD — both phases are pure targeted edits.

## Architectural Decisions

### ADR-1: Python3-with-bash-fallback rather than pure awk
**Context:** Three viable approaches existed: Python3 only, Python3+bash fallback, or pure awk (POSIX). The fix must work on macOS and Linux.
**Decision:** Python3 with bash fallback. `python3 -c "import json,sys; ..."` takes ~1ms on any input size; bash string-substitution fallback preserves existing behavior on machines without Python3.
**Alternatives considered:** (1) Pure awk — faster than bash but tricky to handle multiline content portably in POSIX awk without GNU extensions; more fragile. (2) Python3 only — simplest code but hard-fails on machines without Python3, violating NN-C-005.
**Consequences:** Session start is ~1000x faster in the common case. Machines without Python3 are unaffected (fallback). NN-C-002 requires a one-sentence exception clause.
**Charter alignment:** NN-C-002 (exception documented), NN-C-005 (hook degrades gracefully).

## Phases

Each phase uses exactly ONE of two tracks:
- **TDD track** — phase contains `[TDD-Red]`
- **Implement track** — phase contains `[Implement]` (and NO `[TDD-Red]`)

---

### Phase 1 (Implement track): Fix escape_for_json + amend NN-C-002

**Exit Gate:** Hook exits 0 with valid JSON on both Python3-present and Python3-absent paths; NN-C-002 contains the Python3 exception clause; AC-1 through AC-4 verified.
**ACs Covered:** AC-1, AC-2, AC-3, AC-4
**In scope:** `plugins/spec-flow/hooks/session-start` (lines 54–62), `.claude/skills/charter-non-negotiables/SKILL.md` (NN-C-002 entry)
**NOT in scope:** call-site changes; other hooks; version files (Phase 2)
**Steps traversed (P2):** N/A
**Dispatch sites (P3):** none
**Charter constraints honored in this phase:**
- NN-C-002 (no runtime deps): amended in this phase to document Python3 as an explicit exception
- NN-C-005 (hooks no-op on missing deps): bash fallback implemented in same edit

- [x] **[Implement]** Write code per the plan

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/hooks/session-start`**
  - Anchor: `escape_for_json()` function definition (lines 54–62)
  - Current:
    ```
    54  escape_for_json() {
    55      local s="$1"
    56      s="${s//\\/\\\\}"
    57      s="${s//\"/\\\"}"
    58      s="${s//$'\n'/\\n}"
    59      s="${s//$'\r'/\\r}"
    60      s="${s//$'\t'/\\t}"
    61      printf '%s' "$s"
    62  }
    ```
  - Target: Replace the function body. Keep the function name and single-argument signature
    unchanged so all 6 call sites require no edits.
    ```
    escape_for_json() {
        local s="$1" py_out
        if command -v python3 >/dev/null 2>&1 && \
           py_out=$(printf '%s' "$s" | python3 -c \
             "import json,sys; s=sys.stdin.read(); print(json.dumps(s,ensure_ascii=False)[1:-1],end='')" 2>/dev/null); then
            printf '%s' "$py_out"
        else
            s="${s//\\/\\\\}"
            s="${s//\"/\\\"}"
            s="${s//$'\n'/\\n}"
            s="${s//$'\r'/\\r}"
            s="${s//$'\t'/\\t}"
            printf '%s' "$s"
        fi
    }
    ```
  - Done: Function definition at lines 54–62 replaced; surrounding lines untouched.
  - Verify: `bash -n plugins/spec-flow/hooks/session-start` exits 0 (syntax check).

  **T-2: MODIFY `.claude/skills/charter-non-negotiables/SKILL.md`**
  - Anchor: NN-C-002 entry, `**Statement:**` paragraph
  - Current: ends with "...anything heavier than bash requires an explicit exception
    documented in this file."
  - Target: Append one sentence to the **Statement** paragraph:
    "**Exception:** `hooks/` scripts may invoke `python3` as an optional fast path
    (e.g., for JSON encoding of large strings) provided a pure-bash fallback is present
    and the hook exits 0 when `python3` is absent."
  - Done: The exception sentence appears in the NN-C-002 Statement field.
  - Verify: Agent-step — read the file and confirm the exception sentence is present in NN-C-002.

- [x] **[Verify]** Confirm the implementation is sound

  **Per-change checks:**
  - T-1 syntax: `bash -n plugins/spec-flow/hooks/session-start` — Expected: exits 0, no output
  - T-1 Python3 fast path (AC-1, AC-3): Generate 125KB test string, run through the new
    function with Python3 available, confirm <100ms and correct escaping of all 5 sequences.
    ```bash
    python3 -c "print('a' * 125000 + '\\\\ \" \\n\\r\\t')" > /tmp/test_input.txt
    time bash -c 'source plugins/spec-flow/hooks/session-start; cat /tmp/test_input.txt | escape_for_json "$(cat /tmp/test_input.txt)"'
    ```
    Expected: completes in <100ms; output contains `\\\\`, `\\\"`, `\\n`, `\\r`, `\\t`
  - T-1 bash fallback (AC-2): Shadow python3, run hook, confirm exit 0 + valid JSON:
    ```bash
    PATH=/usr/bin/git bash plugins/spec-flow/hooks/session-start | python3 -c "import json,sys; json.load(sys.stdin)" && echo "valid JSON"
    ```
    Expected: "valid JSON" printed, exit 0
  - T-2 charter amendment (AC-4): Agent-step — read
    `.claude/skills/charter-non-negotiables/SKILL.md` and confirm the NN-C-002 Statement
    contains "Exception:" and "python3" and "bash fallback".

  **Phase-level check:**
  - Run: `bash -n plugins/spec-flow/hooks/session-start` — Expected: exits 0
  - Run: `bash plugins/spec-flow/hooks/session-start | python3 -m json.tool > /dev/null` — Expected: exits 0 (valid JSON output)
  - Failure: non-zero exit or JSON parse error

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-2, AC-3, AC-4
  - Diff baseline: `git diff main..HEAD`

---

### Phase 2 (Implement track): Version bump — 5.1.0 → 5.1.1

**Exit Gate:** All three version-bearing files updated to 5.1.1; CHANGELOG has a Fixed entry; AC-5 verified.
**ACs Covered:** AC-5
**In scope:** `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`
**NOT in scope:** Any behavior changes; all hook changes are in Phase 1
**Steps traversed (P2):** N/A
**Dispatch sites (P3):** none
**Charter constraints honored in this phase:**
- NN-C-009 (version bump): patch bump for bug fix in plugin source
- NN-C-001 (version sync): plugin.json and marketplace.json updated together
- CR-006 (CHANGELOG format): Keep a Changelog format, Fixed grouping

- [x] **[Implement]** Write code per the plan

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`**
  - Anchor: `"version"` field
  - Current: `"version": "5.1.0"`
  - Target: `"version": "5.1.1"`
  - Done: version field reads 5.1.1.
  - Verify: `grep '"version"' plugins/spec-flow/.claude-plugin/plugin.json` → `"version": "5.1.1"`

  **T-2: MODIFY `.claude-plugin/marketplace.json`**
  - Anchor: spec-flow entry `"version"` field
  - Current: `"version": "5.1.0"` (spec-flow entry)
  - Target: `"version": "5.1.1"`
  - Done: spec-flow marketplace entry version reads 5.1.1.
  - Verify: `jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json` → `5.1.1`

  **T-3: MODIFY `plugins/spec-flow/CHANGELOG.md`**
  - Anchor: top of file, below `# Changelog` heading
  - Current: first release section is `## [5.1.0] — ...`
  - Target: prepend a new section:
    ```
    ## [5.1.1] — 2026-06-05

    ### Fixed
    - `escape_for_json()` in `hooks/session-start` now delegates to `python3 json.dumps()`
      when Python3 is available, reducing escaping time from >2s to ~1ms on large charter
      content (125KB+). Pure-bash fallback retained for machines without Python3.
    ```
  - Done: `## [5.1.1]` section appears at top of CHANGELOG with a Fixed bullet.
  - Verify: `head -10 plugins/spec-flow/CHANGELOG.md` shows `## [5.1.1] — 2026-06-05`

- [x] **[Verify]** Confirm the implementation is sound

  **Per-change checks:**
  - T-1: `grep '"version"' plugins/spec-flow/.claude-plugin/plugin.json` — Expected: `"version": "5.1.1"`
  - T-2: `jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json` — Expected: `5.1.1`
  - T-3: `head -5 plugins/spec-flow/CHANGELOG.md` — Expected: `## [5.1.1] — 2026-06-05`

  **Phase-level check (AC-5):**
  - Run: `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)` — Expected: no output (versions in sync)
  - Failure: any output = version mismatch

- [x] **[QA]** Phase review
  - Review against: AC-5
  - Diff baseline: `git diff main..HEAD`

---

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | Python3 path completes 125KB input in <100ms | COVERED | Phase 1 [Verify] T-1 timing check |
| AC-2 | Bash fallback activates when Python3 absent; hook exits 0 | COVERED | Phase 1 [Verify] T-1 fallback check |
| AC-3 | Python3 and bash paths produce identical output | COVERED | Phase 1 [Verify] T-1 output comparison |
| AC-4 | NN-C-002 contains Python3 exception clause | COVERED | Phase 1 [Verify] T-2 agent-step |
| AC-5 | All version files at 5.1.1; CHANGELOG has Fixed entry | COVERED | Phase 2 [Verify] phase-level check |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `time bash -c 'source plugins/spec-flow/hooks/session-start ...'` (see Phase 1 Verify T-1) | <100ms wall-clock |
| AC-2 | shell | `PATH=/usr/bin/git bash plugins/spec-flow/hooks/session-start \| python3 -m json.tool` | exits 0 |
| AC-3 | shell | compare output of both paths on same input | byte-for-byte identical |
| AC-4 | agent-step | Read `.claude/skills/charter-non-negotiables/SKILL.md`, confirm NN-C-002 Statement contains "Exception:" and "python3" | text present |
| AC-5 | shell | `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] \| select(.name == "spec-flow") \| .version' .claude-plugin/marketplace.json)` | no output |

## Contracts

No TDD-track phases — implement-only plan. No boundary-crossing interfaces to document.

## Parallel Execution Notes

Phases are serial. Phase 2 depends on Phase 1 completing cleanly.
