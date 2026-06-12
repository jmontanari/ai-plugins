---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
---

# Plan: agent-twin-symlinks

## Overview

Non-TDD mode: both phases use the Implement track + Write-Tests; AC Coverage Matrix is generated; QA and Final Review remain intact. Convert the 27 Copilot co-ship twins (`agents/*.agent.md`) from byte-identical copies to relative same-dir symlinks to their `.md` source, hardening the `static.sh` invariant and documenting the mechanism. Two phases: (1) symlinks + test hardening, (2) docs + version bump.

## Architectural Decisions

### ADR-1: Symlink the co-ship twins rather than auto-generate or keep copies
**Context:** `.agent.md` twins are byte-identical copies of `.md`, enforced by a `static.sh` diff. Two of 27 drifted (qa-plan red since 5.16.0; implementer unguarded). The copy model has no structural guarantee — only a test that can be (and was) outrun by an un-mirrored edit.
**Decision:** Replace each `.agent.md` regular file with a relative, same-directory symlink to its `.md` twin. `.md` becomes the single source of truth; `.agent.md` is a view.
**Alternatives considered:** (a) Keep copies + add a pre-commit sync hook — still two files, hook can be bypassed, adds a runtime moving part (NN-C-002 friction). (b) Generate `.agent.md` at release time from `.md` — adds a build step; the tree is no longer self-consistent in git. (c) Drop `.agent.md` entirely and point Copilot at `.md` — this is viable (PI-007 established that Copilot CLI v1.0.34 scans both `*.md` and `*.agent.md` and deduplicates by basename, so it reads `.md` directly); rejected here because (i) the symlink keeps the co-ship twin relationship explicit and zero-maintenance, (ii) the existing `static.sh` AC-10 byte-identity enforcement is preserved without removing it, and (iii) the symlink approach eliminates the drift class with a smaller change than deleting all 27 twins plus their enforcement. See `docs/prds/shared/specs/PI-007-copilot-coship/learnings.md`.
**Consequences:** Drift becomes structurally impossible; editing `.md` updates both hosts atomically. Downstream pieces editing agents (e.g. outcome-acs) no longer carry a twin-lockstep / rubric-identity landmine. Residual: git on Windows without `core.symlinks=true` materializes a symlink as a text file → breaks Copilot-on-Windows (documented caveat; POSIX charter baseline makes it acceptable).
**Charter alignment:** NN-C-002 (no runtime dep — POSIX symlink), NN-C-003 (Claude unaffected; Copilot corrected — additive/fix), CR-005 (relative same-dir targets).

## Phases

### Phase 1: Convert twins to symlinks + harden static.sh
**In scope:** replace all 27 `plugins/spec-flow/agents/*.agent.md` with relative symlinks to their `.md` twin; harden `tests/e2e/lib/static.sh` AC-10 to assert symlink-ness.
**NOT in scope:** docs + version bump — covered by Phase 2.
**ACs Covered:** AC-1, AC-2, AC-3
**Exit Gate:** all 27 `.agent.md` are git symlinks (mode 120000) resolving to their `.md`; `static.sh` runs green (0 failed), including the previously-red qa-plan pair.

- [x] **[Implement]**

T-1: CONVERT `plugins/spec-flow/agents/*.agent.md` (27 files) to symlinks.
Operation: for each `.agent.md`, remove the regular file and create a relative same-dir symlink to its `.md` twin.
Exact command (run from repo root):
```bash
cd plugins/spec-flow/agents
for f in *.agent.md; do
  base="${f%.agent.md}.md"
  [ -f "$base" ] || { echo "NO TWIN for $f"; exit 1; }
  rm "$f"
  ln -s "$base" "$f"
done
cd -
git add plugins/spec-flow/agents/*.agent.md
```
Done: every `*.agent.md` is a symlink to its sibling `*.md`; the 2 drifted pairs (qa-plan, implementer) now resolve to the `.md` source. `git add` stages them as mode 120000.
Verify: `find plugins/spec-flow/agents -name '*.agent.md' -type l | wc -l` returns `27`; `git ls-files -s plugins/spec-flow/agents/*.agent.md | grep -vc '^120000'` returns `0`.

T-2: MODIFY `plugins/spec-flow/tests/e2e/lib/static.sh`
Anchor: the `AC-10 (gate-evals)` per-pair loop (the `for _pair in "${_measured_pairs[@]}"` block, ~lines 246-258).
CURRENT (the per-pair body):
```bash
    assert_grep "rubric_version:" "${_agents_dir}/${_pair}.md" \
      "AC-10 (gate-evals): ${_pair}.md has rubric_version"
    assert_grep "rubric_version:" "${_agents_dir}/${_pair}.agent.md" \
      "AC-10 (gate-evals): ${_pair}.agent.md has rubric_version"
    _diff_out=$(diff "${_agents_dir}/${_pair}.md" "${_agents_dir}/${_pair}.agent.md" 2>&1)
    if [ -z "$_diff_out" ]; then
      pass "AC-10 (gate-evals): ${_pair} .md/.agent.md are byte-identical"
    else
      fail "AC-10 (gate-evals): ${_pair} .md/.agent.md differ (unexpected non-rubric_version change)"
    fi
```
TARGET: before the diff check, add an assertion that `${_pair}.agent.md` is a symlink, so a future copy cannot silently reintroduce drift. Insert (using the suite's assertion idiom):
```bash
    if [ -L "${_agents_dir}/${_pair}.agent.md" ]; then
      pass "AC-10 (gate-evals): ${_pair}.agent.md is a symlink to its .md source"
    else
      fail "AC-10 (gate-evals): ${_pair}.agent.md is a regular file — co-ship twin must be a symlink to ${_pair}.md (drift risk)"
    fi
```
Keep the existing `rubric_version` greps and the `diff` byte-identity check unchanged (the symlink resolves, so both still pass). Apply the symlink assertion to ALL 13 measured pairs (inside the existing loop — one insertion covers all).
Done: AC-10 asserts both symlink-ness and content-identity for every measured pair.
Verify: see Phase Verify.

- [x] **[Write-Tests]** No new test file authored — the hardened `static.sh` AC-10 (T-2) IS the test. The existing `static.sh` greps on `.agent.md` (AC-4 tdd-red/implementer, AC-11 qa-plan/implementer) serve as regression coverage that the symlinked content still contains the required tokens.
- [x] **[Verify]**
Run: `bash plugins/spec-flow/tests/e2e/lib/static.sh` (or the e2e runner `plugins/spec-flow/tests/e2e/run-e2e.sh` static stage) — Expected: 0 failed; specifically the `AC-10 (gate-evals): qa-plan .md/.agent.md are byte-identical` line now PASSES (was failing), the new `qa-plan.agent.md is a symlink` line PASSES, and the AC-4/AC-11 greps on `tdd-red.agent.md` / `implementer.agent.md` / `qa-plan.agent.md` still PASS (symlink content resolves).
Run: `find plugins/spec-flow/agents -name '*.agent.md' -type l | wc -l` — Expected: `27`.
Run: `for f in plugins/spec-flow/agents/*.agent.md; do cmp -s "$f" "${f%.agent.md}.md" || echo "MISMATCH $f"; done` — Expected: no output.
Failure indicator: any non-zero `static.sh` fail count, a count ≠ 27, or any `MISMATCH` line.

### Phase 2: Document co-ship mechanism + version bump
**In scope:** `releasing.md` co-ship documentation; version bump to 5.16.1 across the four version-bearing files; CHANGELOG entry.
**NOT in scope:** symlink conversion (Phase 1); NN-C-009 body edits (confirmed unnecessary — it governs version descriptors, not agent-twin identity).
**ACs Covered:** AC-4, AC-5
**Exit Gate:** `releasing.md` documents the symlink mechanism; all four version files read 5.16.1; CHANGELOG has the 5.16.1 entry; the releasing.md verification snippet passes.

- [x] **[Implement]**

T-3: MODIFY `plugins/spec-flow/docs/releasing.md`
Anchor: the co-ship section (the "spec-flow co-ships for two hosts from a single source tree (v2.1.0, PI-007)" block, ~lines 44-46) and/or the "Why four files?" / sync sections.
TARGET: add a short subsection documenting that `agents/*.agent.md` are **relative same-dir symlinks** to their `agents/*.md` source (single source of truth; edit the `.md`, the `.agent.md` view follows), that `rsync -av` (the installed-plugins sync) preserves symlinks and the relative target resolves at the `~/.copilot/...` destination, and the Windows caveat: git without `core.symlinks=true` materializes symlinks as text files, breaking Copilot-on-Windows (POSIX baseline assumed). Mention the invariant is enforced by `static.sh` AC-10 (symlink-ness).
Done: the three facts (symlink mechanism, rsync-a preservation, Windows caveat) are present in `releasing.md`.
Verify: `grep -iE "symlink" plugins/spec-flow/docs/releasing.md` matches; `grep -i "core.symlinks" plugins/spec-flow/docs/releasing.md` matches.

T-4: MODIFY the four version-bearing files to `5.16.1`.
(a) `plugins/spec-flow/plugin.json` — `"version"` → `"5.16.1"`.
(b) `plugins/spec-flow/.claude-plugin/plugin.json` — `"version"` → `"5.16.1"`.
(c) `.claude-plugin/marketplace.json` — the `spec-flow` entry `"version"` → `"5.16.1"`.
(d) `plugins/spec-flow/CHANGELOG.md` — prepend, immediately below `## [Unreleased]`, a new section:
```
## [5.16.1] — 2026-06-12

### Fixed
- **Co-ship twin drift.** `agents/qa-plan.agent.md` carried a "Plan over budget (FR-014)" criterion that 5.15.0 retired from `qa-plan.md` but never mirrored — `static.sh` AC-10 byte-identity had been red since 5.16.0. `agents/implementer.agent.md` had drifted from `implementer.md` (unguarded). Both corrected.

### Changed
- **Agent co-ship twins are now symlinks.** All 27 `agents/*.agent.md` (Copilot CLI variants) are relative same-dir symlinks to their `agents/*.md` (Claude) source — one source of truth; drift is structurally impossible. `static.sh` AC-10 now asserts symlink-ness. `docs/releasing.md` documents the mechanism + the Windows `core.symlinks` caveat. Claude users are unaffected (Claude reads the `.md` files directly).
```
Done: all four files read 5.16.1; CHANGELOG has the dated 5.16.1 section with Fixed + Changed groupings.
Verify: see Phase Verify.

- [x] **[Write-Tests]** No new test — the version triad is verified by the releasing.md verification snippet (a machine check). NN-C-001/009 are enforced by existing review-board/static checks.
- [x] **[Verify]**
Run: `grep '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` — Expected: both print `5.16.1`.
Run (LLM-agent-step): read `.claude-plugin/marketplace.json`, find the `spec-flow` entry, confirm its `"version"` is `5.16.1`.
Run: `head -12 plugins/spec-flow/CHANGELOG.md` — Expected: a `## [5.16.1] — 2026-06-12` section below `## [Unreleased]` with Fixed + Changed groupings.
Failure indicator: any version string ≠ 5.16.1, or a missing CHANGELOG section.

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | All 27 `.agent.md` are git symlinks (mode 120000) | COVERED | Phase 1 |
| AC-2 | Each `.agent.md` resolves to content identical to its `.md` | COVERED | Phase 1 |
| AC-3 | `static.sh` AC-10 asserts symlink-ness; full suite green | COVERED | Phase 1 |
| AC-4 | `releasing.md` documents symlink mechanism + rsync + Windows caveat | COVERED | Phase 2 |
| AC-5 | Version triad reads 5.16.1 + CHANGELOG entry | COVERED | Phase 2 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `find plugins/spec-flow/agents -name '*.agent.md' -type l | wc -l` | `27` |
| AC-2 | shell | `for f in plugins/spec-flow/agents/*.agent.md; do cmp -s "$f" "${f%.agent.md}.md" || echo MISMATCH; done` | no output |
| AC-3 | shell | `bash plugins/spec-flow/tests/e2e/lib/static.sh` | 0 failed (qa-plan pair green) |
| AC-4 | shell | `grep -iE "symlink|rsync|core.symlinks" plugins/spec-flow/docs/releasing.md` | all three match |
| AC-5 | file-check | `grep '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` + CHANGELOG head | all `5.16.1`; `## [5.16.1]` present |

## Contracts

No TDD-track phases in this plan — contracts section present for forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs.

## Parallel Execution Notes

Phase 1 → Phase 2 serial (Phase 2's CHANGELOG narrates Phase 1's mechanism change). No Phase Group.
