# Introspection — exec-ready / exec-guardrails (FR-EG-1..10)

Code Introspection Report for the plan author. Seeded from `research.md` (4-block-per-cluster). Each MODIFY anchor below carries the **verbatim CURRENT block + line range + semantic anchor** so a Change Specification Block can be written without re-reading. **No spec-flow file changed since the research commit `900aead`** — every line number below is current as of HEAD `f158d97`.

Design anchor (deliberation `## Recommendation`): **one seam, one eval order at the post-commit re-hash gate (flat Step 3.7a / deferred Step G9b): M3 registry window → Red-manifest immutability (enriched) → declared-authored-test exemption (lower precedence) → reconciliation; path in BOTH immutable-set and exemption-set = hard reject (smuggling guard); the 2nd immutability rejection emits a Step 6c `default_triage: amend` discovery row; amendment hard-cap and soft-checkpoint are two thresholds on the single `piece_amendment_count` counter in one canonical home; `(c) continue` removed; spike-agent SSOT "never hard-blocks" edited.** Adversarial review IS available (deliberation `## Adversarial Review`, 5 lenses): architecture-integrity CONTESTED→folded (no fork — one counter); scope/simplicity CONTESTED→VOQ-2/VOQ-3; risk CONTESTED (highest)→VOQ-1 (semantic-tampering residual, resolved by spec scoping to byte-immutability + FR-EG-3 conftest/import enrichment); backward-compat CONTESTED→folded as hard constraints; user-intent HOLDS.

---

## Cluster 1 — Test-immutability anti-cheat (tdd-red manifest + execute integrity gates)

### File Inventory
- `plugins/spec-flow/skills/execute/SKILL.md` (2031 lines) — Step 2 item 6 capture+defensive re-hash (496–508); **Step 3 item 7 gate (a)** content-hash integrity (599–607); **M3 edit-window** (609–677); gate (b) reconciliation (681–690); **Step 4 item 5** phase-exit/Refactor re-hash (763); **Step G9b** barrier working-tree re-hash (1429–1488, integrity step 1 at 1437–1449).
- `plugins/spec-flow/agents/tdd-red.md` (137 lines) + `.agent.md` (135 lines, mirror) — Rule 10 (`.md`) / Rule 9 (`.agent.md`) manifest production (58 / 51); `## Staged test manifest` output template (128–131 / 121–124); deferred-group `git hash-object -w` anchor branch (Rule 6 deferred sub-bullet, 43 / `.agent.md` lacks the long staging prose but keeps the Rule-9 + template + anti-pattern).
- `plugins/spec-flow/agents/implementer.md` (≈190 lines) + `.agent.md` (mirror) — Rule 8 unified commit (51–63); TDD-mode "Do NOT modify test files" anti-pattern (86); "What Red test modification means" (63).
- `plugins/spec-flow/agents/verify.md` (138 lines) + `.agent.md` (mirror) — Audit/Full phase-exit verifier; **NO Red-manifest re-hash present** (FR-EG-4 finding confirmed — delegated entirely to orchestrator Step 4 item 5).
- `plugins/spec-flow/reference/deferred-commit-journal.md` — `red_manifest_hashes` journal field, `## Barrier commit recipe` (cited by G9b), resume-by-hash fallback.

### Dependency Map
`tdd-red` emits `## Staged test manifest` → orchestrator captures (Step 2.6) + defensive re-hash → splices into implementer prompt as `## Red staged test manifest` (Step 3, lines 561–564) → implementer autonomous unified commit → **orchestrator Step 3.7 gate (a)** re-hashes HEAD blobs vs manifest → mismatch = reject + 2-attempt retry → escalate on 2nd. Deferred fork: `red_manifest_hashes` (git-blob anchor via `git hash-object -w`) → barrier G9b working-tree re-hash. M1 invariant: `integration_registry` rows from plan+Red only. **FR-EG-3 lands in `tdd-red`** (fold directly-imported fixtures + same-tree `conftest.py` into the manifest set the gates protect). **FR-EG-1/2/4 land in execute** (tighten reject branches). **FR-EG-5 exemption set** composes into both gate (a) and G9b after M3 window, lower precedence than immutability.

### Test Landscape
No xUnit harness — validation is the **e2e pipeline harness** at `plugins/spec-flow/tests/e2e/`. Entry point `run-e2e.sh` (modes: default / `--audit <piece-dir>` / `--verify-live` / `--record-golden` / `--break`). Layers: **L1 static** (`lib/static.sh` `l1_static_checks` — ordered dispatch-sequence tokens + `assert_grep`/`assert_no_grep` over `execute/SKILL.md` prose; this is where AC-1 "no warn/continue branch at gate (a)", AC-3 "blocking finding not no-op", AC-7 "no `(c) continue`" structural asserts go); **L2 contract** (`lib/contract.sh` — replay-fixture checks: `check_discovery_log`, `check_commit_order`/`assert_subject_order`, `check_transitions`, `check_test_data`, `check_spike`, `check_no_journal`); fixtures at `tests/e2e/fixtures/replay/` (e.g. `discovery-log.md`, `plan-clean.md`, `manifest.yaml`). **Adding a fixture scenario:** add a replay artifact under `fixtures/replay/` (or `fixtures/live-project/`) and a `check_*` function in the matching `lib/*.sh`, wired via `run_mode`. Assertion helpers in `lib/assert.sh`: `assert_grep`, `assert_no_grep`, `assert_file`, `assert_count`, `assert_subject_order`, `assert_exit`.

### Pattern Catalog (verbatim CURRENT anchors)

**A1 — Step 2 item 6 capture + defensive re-hash (496–508)** — semantic anchor `### Step 2` item 6 "Capture the stage manifest" / "Defensive re-hash at capture time":
```
496	6. **Capture the stage manifest.** Extract Red's `## Staged test manifest` section verbatim. Hold in orchestrator state as `phase_N_red_stage_manifest` — a dict of `path → sha256`. This replaces the old post-commit contamination check: the orchestrator uses it after the implementer's unified commit to (a) re-hash each test file in HEAD and detect tampering, and (b) reconcile the commit's file list against the expected union of Red's staged paths + Build's reported paths.
...
499	   for path in <paths from manifest>; do
500	     actual=$(sha256sum -- "$path" | cut -d' ' -f1)
501	     reported=<hash from Red's manifest for this path>
502	     [ "$actual" = "$reported" ] || echo "manifest mismatch: $path"
503	   done
```
(Captures the enriched set once FR-EG-3 lands — already iterates "manifest paths", so enrichment flows through unchanged.)

**A2 — Step 3.7 gate (a) content-hash integrity (599–607)** — semantic anchor `- **(a) Content-hash integrity (Mode: TDD only).**`. THIS is the FR-EG-1 reject seam:
```
599	   - **(a) Content-hash integrity (Mode: TDD only).** For every path in `phase_N_red_stage_manifest`, re-hash the file AS COMMITTED in HEAD and compare against the manifest:
600	     ```bash
601	     for path in <manifest paths>; do
602	       commit_hash=$(git show HEAD:"$path" | sha256sum | cut -d' ' -f1)
603	       manifest_hash=<manifest hash for path>
604	       [ "$commit_hash" = "$manifest_hash" ] || echo "integrity fail: $path"
605	     done
606	     ```
607	     Any mismatch means the implementer modified one of Red's tests — the anti-cheat safeguard replacing pre-v2.7.0's `git diff tests/` check. Reject the phase and retry within the 2-attempt budget (the retry must recreate the commit without touching Red's tests). Escalate on second failure.
```
> Note: NO warn-and-proceed branch exists today — current prose already says "Reject the phase and retry." FR-EG-1's tightening is mostly making the eval order explicit (insert declared-authored-test exemption AFTER M3 / immutability, lower precedence), naming violating paths in the re-dispatch, and adding the FR-EG-9 "2nd rejection → Step 6c" routing. AC-1's structural assert (`assert_no_grep` for warn/continue at gate (a)) passes against current prose — the load-bearing edits are the exemption composition + named-path re-dispatch + repeated-rejection routing.

**A3 — M3 integration_registry edit-window (609–677)** — semantic anchor `**M3 edit window for registered `[integration]` paths.**`. This is the existing exemption set the new declared-`Authored-tests:` exemption composes alongside. Window logic: before `registered_in_phase` = skip (not authored); `registered ≤ current < completes` = immutable at `skeleton_sha256`; at `completes` = one plan-authorized edit (skeleton→completed); after = immutable at `completed_sha256`. The closure-hash loop (622–674) uses `git cat-file -e` presence + `git show | sha256sum`. Closing prose (677): "Build cannot self-authorize an integration edit … registry rows come only from plan + Red (M1 invariant) … The M3 window is a gate *tightening* mechanism, never a merge path (NN-P-002)." The declared-authored exemption must mirror this "lower-precedence, plan-derived, qa-plan-reviewed" framing.

**A4 — gate (b) reconciliation (681–690)** — semantic anchor `- **(b) Unified commit reconciliation`:
```
681	   - **(b) Unified commit reconciliation (Mode: TDD AND Mode: Implement).** The commit's file list must equal the **expected file set**:
682	     - **Mode: TDD:** `expected = Red's manifest paths ∪ Build's `## Files Created/Modified` paths`.
683	     - **Mode: Implement:** `expected = Build's `## Files Created/Modified` paths` only (no Red manifest).
...
686	     git show --name-only --pretty= HEAD | sort > /tmp/commit_files.txt
688	     diff /tmp/commit_files.txt /tmp/expected_files.txt
```
> Per deliberation fold 2c-1 + the conditional-mechanism fold: declared `**Authored-tests:**` paths join `expected` here so a legitimately-authored test on Implement track does not trip the "stray file" check (AC-5). The `expected` set is where FR-EG-5's exemption composes on the reconciliation half.

**A5 — Step 4 item 5 phase-exit / Refactor re-hash (763)** — semantic anchor `5. **Test integrity (Mode: TDD only; non-TDD mode: no-op).**`. THIS is the "already passed / no-op" wording AC-3/FR-EG-4 must harden:
```
763	5. **Test integrity (Mode: TDD only; non-TDD mode: no-op).** As of v2.7.0, the primary anti-tampering safeguard runs at Step 3.7a (content-hash check of Red's staged test manifest against Red's test files in HEAD). By the time Step 4 runs, that gate has already passed — so no additional diff is needed here. ... If the phase produces a Refactor commit in Step 5, re-run the content-hash check against HEAD after Refactor lands ... If any hash drifts at Refactor time: REJECT, revert the refactor commit, and flag the Refactor agent for re-dispatch with the offending paths surfaced.
```
> Current text frames re-verification as conditional on a Refactor commit and leads with "already passed — no additional diff is needed." FR-EG-4 reframes: phase-exit re-hash of the full manifest set is unconditional and a mismatch is a **blocking finding attributed to the phase** (not "already passed / no-op"). AC-3's structural assert reads this prose for "blocking finding," not "already passed / no-op."

**A6 — Step G9b barrier integrity (1429–1449)** — semantic anchor `### Step G9b: Barrier work-commit`, integrity step 1. FR-EG-2 reject seam on the deferred path:
```
1437	1. **Re-hash each sub-phase's Red tests in the working tree against the journal `red_manifest_hashes`.** ...
1440	   for path in <this sub-phase's red_manifest_hashes keys>; do
1441	     wt_blob=$(git hash-object -- "$path")
1442	     manifest_blob=<journal red_manifest_hashes[path]>
1443	     [ "$wt_blob" = "$manifest_blob" ] || echo "barrier integrity fail: $path"
1444	   done
1447	   If the journal lacks the `anchor: blob` marker (written by ≤5.1.0), verify with `sha256sum` instead (see resume fallback).
1449	   Any mismatch means a Build agent modified one of Red's tests ... Reject within the 2-attempt budget (re-dispatch the offending sub-phase's Build without touching Red's tests ...); escalate on second failure.
```
Commit ordering (the SF3 guard, 1435): G9 hook sweep runs BEFORE this G9b re-hash; after the sweep autofixes a Red file the orchestrator re-anchors via `git hash-object -w` and updates the journal — so this re-hash compares against the post-sweep baseline (prevents false trip). Barrier sequence: step 1 integrity → step 2 oracle → step 3 compute union → step 4 stage+commit (1459–1462) → step 5 reconcile (1466–1472) → step 6 `rm journal`. **The reject in step 1 is genuinely pre-commit (the barrier commit is step 4)** — this is the asymmetry the spec accepts: deferred = literal pre-commit; flat = revert-before-acceptance. NFR-EG-3: the ≤5.1.0 `sha256sum` fallback (1447) is the in-flight-resume escape that must NOT be hard-rejected.

**A7 — tdd-red.md Rule 10 manifest production (58) + output template (128–131)** — semantic anchor `10. **Emit a `## Staged test manifest` with SHA-256 hashes.**` (FR-EG-3 enrichment lands here):
```
58	10. **Emit a `## Staged test manifest` with SHA-256 hashes.** For every path in `## Tests Written`, compute the content hash of the staged file and list it as `<path>: <sha256>`. ... In a deferred Phase Group the ORCHESTRATOR independently anchors each test file with `git hash-object -w` at red-done; your manifest is an advisory cross-check, not the integrity baseline.
...
128	## Staged test manifest
129	<one line per staged test file — `<path>: <sha256>` — emitted verbatim into the orchestrator's state for integrity reconciliation after the implementer's unified commit>
130	- tests/path/test_foo.py: a3f5c891...
131	- tests/path/test_bar.py: b71d2a4e...
```
Mirror `.agent.md`: same content at **Rule 9 (line 51)** + template (121–124) + anti-pattern (134 "Omit the `## Staged test manifest` section"). FR-EG-3 extends Rule 10/9 with the bounded enrichment rule (resolve `from X import`/`import X` direct statements to repo-relative files + any `conftest.py` from the staged test's directory up to test root; no transitive walk; non-resolving imports skipped, per OQ-1 default). Output template gains fixture/conftest lines. **Both files edited (FR-EG-10).**

**A8 — implementer.md Rule 8 (51–63) + anti-pattern (86)** — semantic anchor `8. **ONE unified commit at the end`. FR-EG-1/FR-EG-9 re-dispatch contract:
```
53	   **Mode: TDD.** ... The orchestrator runs two post-commit gates: (i) re-hashes each test file in HEAD against Red's stage manifest — any drift means you modified Red's tests to make them pass (rejected); (ii) reconciles the commit's file list against the expected union — any stray file (rejected).
63	   **What "Red test modification" means.** Any change to a file in Red's `## Staged test manifest` ... The content-hash integrity check ... is strict and unforgiving by design.
...
86	- Do NOT modify test files (the content-hash gate in Rule 8 rejects any change to a file in Red's `## Staged test manifest`). If a test looks wrong, report BLOCKED — do not "fix" it.
```
The SKIPPED-IDs precedent (re-dispatch surfacing offending paths) lives at Step 3 item 5(b)/(c) of execute (lines 589–592) — "tests X, Y were SKIPPED in your run … you cannot pass Red tests by skipping them." FR-EG-1's named-path re-dispatch mirrors this. Rule 8 prose should note the manifest set now includes FR-EG-3 fixtures/conftest. **`.md` + `.agent.md` mirror (identical size).**

---

## Cluster 2 — Amendment budget (soft-checkpoint → hard cap)

### File Inventory
- `plugins/spec-flow/skills/execute/SKILL.md` — `#### Amendment budget tracking` (1211–1263): counters (1215–1218), recovery grep (1220–1225), pre-dispatch check (1227–1232), **soft-checkpoint four-option prompt (1241–1263)**, canonical-def cite to spike-agent (1263). Budget enforcement note in Step 6c (985).
- `plugins/spec-flow/templates/pipeline-config.yaml` — NO `amendment_budget` key today (keys end at `qa_max_iterations` line 70). FR-EG-7 adds it modeled on the `qa_max_iterations` comment block.
- `plugins/spec-flow/reference/spike-agent.md` — `## Soft-checkpoint budget` (67–84): the "never hard-blocks" assertion (81) FR-EG-8 must edit so the SSOT matches the hard-halt.
- `plugins/spec-flow/plugin.json` (version 5.11.0, line 4); `.claude-plugin/marketplace.json` (spec-flow entry version 5.11.0, line 15); `plugins/spec-flow/CHANGELOG.md` (Keep-a-Changelog; `## [Unreleased]` at line 5, head `## [5.11.0] — 2026-06-10`).

### Dependency Map
Single counter `piece_amendment_count` recovered via `git log --grep '^chore(plan): amend' --grep '^chore(spec): amend'`. New `amendment_budget` int flows: `.spec-flow.yaml` key → Step 0 config load (existing idiom: valid-values, default-when-absent NN-C-003, malformed→warning+default) → pre-dispatch check at every amend site (Step 6c, Step 8 Final Review, reflection, auto-mode). FR-EG-8 replaces the `(c) continue` branch in the soft-checkpoint prompt with a hard halt reusing the existing `(b) block` flow (status→`blocked`, manifest commit). The 1-spec sub-cap stays a fixed documented constant (out of scope to make configurable). spike-agent SSOT (81) edited from "never hard-blocks" to "soft-checkpoint never per-event hard-blocks; the configurable `amendment_budget` hard-cap halts at its threshold" so AC-10 SSOT-consistency holds.

### Test Landscape
e2e amendment-loop replay scenarios + L1 structural asserts over `execute/SKILL.md` (AC-7: `assert_no_grep` for `(c) continue`; AC-8: `assert_no_grep` for off/unlimited sentinel; config-default asserts via `fixtures/live-project/.spec-flow.yaml`). Counter recovery is a lossless `git log | wc -l` reconstruction — testable by a fixture branch history. The hard-halt → blocked status is observable via the manifest commit subject (`assert_subject_order`).

### Pattern Catalog (verbatim CURRENT anchors)

**B1 — counter recovery (1220–1225)** — semantic anchor `**Counter recovery on session resume.**`:
```
1222	- `piece_amendment_count` = `git log --oneline $piece_start_sha..HEAD --grep '^chore(plan): amend' --grep '^chore(spec): amend' | wc -l`
1223	- `piece_spec_amendment_count` = `git log --oneline $piece_start_sha..HEAD --grep '^chore(spec): amend' | wc -l`
```
(Single counter, single recovery — confirms AC-10 "exactly one counter, one canonical home." Do NOT add a second counter.)

**B2 — soft-checkpoint four-option prompt (1241–1263)** — semantic anchor `**Soft-checkpoint prompt.**`. FR-EG-8 edits this block: remove `(c) continue`, add diagnostic framing + amendment-history summary, keep `(f)/(d)/(b)`, add "raise `amendment_budget` and resume" instruction (OQ-2 default: reuse menu + one instruction line, no new option code path):
```
1243	Hit <N> amendments — this piece may be under-scoped. Choose:
1244	  (c) continue amending
1245	  (f) fork remaining must-fix work into a new piece
1246	  (d) defer this finding
1247	  (b) block piece
1248	```
```
1253	- **On `c` (continue):** dispatch the amendment. Re-surface this same four-option prompt on each subsequent amendment attempt — the count never resets and never hard-blocks. ...
1256	- **On `b` (block):** operator-chosen halt. Set the current piece's status to `blocked` ...
1258	  git add docs/prds/<prd-slug>/manifest.yaml
1259	  git commit -m "chore(<piece-slug>): block — amendment budget exhausted"
1261	  and exit with: `Halted: piece <piece-slug> status set to blocked (amendment budget exhausted). Re-spec or abandon recommended.`
1263	The count never resets within a piece and never hard-blocks. The soft checkpoint re-surfaces on each subsequent amendment; the operator's `(c)` choice is per-amendment (not a session-wide unlock). See `plugins/spec-flow/reference/spike-agent.md` `## Soft-checkpoint budget` for the canonical definition.
```
Also edit the merged-prompt at 1229 (which includes `(c) continue`) and the pre-dispatch routing at 1231–1232 ("route to the soft-checkpoint prompt … not a hard refuse"). The `(b) block` halt at 1256–1261 is the flow the hard-cap reuses. Cite line at 1263 points at spike-agent SSOT.

**B3 — spike-agent SSOT (67–84)** — semantic anchor `## Soft-checkpoint budget`. FR-EG-8 edits line 81:
```
74	Default thresholds: 5 total; 1 spec sub-cap.
76	At threshold: prompt the operator `continue / fork / defer / block`. Re-surface on each subsequent amendment.
81	Count never resets within a piece; never hard-blocks (only the operator's `block` choice halts execution).
```
> Line 76 "continue / fork / defer / block" and line 81 "never hard-blocks" both contradict the hard-cap and must be edited (AC-10). Default-thresholds line (74) should note `amendment_budget` is the configurable total.

**B4 — pipeline-config `qa_max_iterations` comment-block idiom (62–70)** — the verbatim pattern FR-EG-7's `amendment_budget` key models:
```
62	# qa_max_iterations: configurable QA fix-loop circuit-breaker limit (new in v5.6.0)
63	#   auto  — resolve per piece track: 5 for doc-as-code/Implement pieces (tdd: false),
64	#           3 for TDD pieces (tdd: true). Codifies the pi-011 finding that a hard 3 is
65	#           wrong for doc-as-code Final Review (default)
66	#   <int> — explicit cap applied uniformly to all five QA-agent fix-loops
67	#   Governs: Final Review fix loop, per-phase qa-phase, mid-piece Opus pass, Group Deep QA,
68	#   qa-phase-lite. Does NOT govern the oracle 2-attempt build budget or the mechanical
69	#   SKILL self-lint loop.
70	qa_max_iterations: auto
```
> New key idiom (CR-007): `# amendment_budget: per-piece amendment hard-cap (new in vX.Y.0)` + `#   <int> — …(default 5)` + governs/does-not-govern note + `amendment_budget: 5`. No off/unlimited sentinel (AC-8).

**B5 — version trio (FR-EG-10)** — `plugin.json:4` `"version": "5.11.0"`; `marketplace.json:15` `"version": "5.11.0"` (spec-flow entry; the second entry at 24 is a different plugin v1.1.1 — do not touch); `CHANGELOG.md` `## [Unreleased]` (line 5) — add a `### Changed` entry recording the `(c) continue` removal with a migration note (behavioral break, CR-006), NOT `### Added`.

---

## Cluster 3 — qa-plan declared-test-path verification + plan phase-block format

### File Inventory
- `plugins/spec-flow/agents/qa-plan.md` (212 lines) — numbered criteria **1–31**; Criterion 26 (Integration allocation / registry cross-check, 147) is the (a)–(e) cross-check model for the new criterion; the scope-collection step (32, under Criterion 11) is the literal-path-union precedent. New criterion appends after 31, before `## Output Format` (193).
- `plugins/spec-flow/agents/qa-plan.agent.md` (mirror, **trimmed**) — numbered criteria **1–26 only** (drops criteria 27–31 incl. the P2/P3 and Test-Data criteria); the scope-collection step is also at line 32; new criterion appends after 26, before `## Output Format`. Mirror must get the same new criterion (FR-EG-6/FR-EG-10).
- `plugins/spec-flow/templates/plan.md` — phase-header fields `**ACs Covered:**`/`**In scope:**`/`**NOT in scope:**`/`**Steps traversed (P2):**`/`**Dispatch sites (P3):**` (61–66, repeated 134–143, 201–206); Phase-Group `**Scope:**` (275, 300). New conditional `**Authored-tests:**` field documented here (FR-EG-5).

### Dependency Map
qa-plan reads `plan.md` phase blocks read-only. Criterion 26's registry cross-check (a)–(e) is the precedent for FR-EG-6's "verify IFF present" criterion: each declared `**Authored-tests:**` path is a real test path cited in that phase's body, and no declared path collides with a Red-manifest or integration-registry path (collision/phantom → must-fix; absence never a finding). The orchestrator's gate (a)/(b) exemption set (Red manifest ∪ M3 registry ∪ qa-plan-verified declared paths) consumes the field at runtime. Smuggling guard: a path in BOTH the immutable set AND `**Authored-tests:**` is a hard reject at runtime (AC-6) AND a qa-plan must-fix.

### Test Landscape
qa-plan is a QA gate (no own tests); criteria exercised by plan-stage replay fixtures (`fixtures/replay/plan-clean.md`, `plan-no-test-data.md`). New criterion verified by a plan fixture authoring a test on Implement track without declaring → must-fix (AC-6 collision fixture; AC-5 clean-declaration fixture). The `**Authored-tests:**` conditional-absence case (pre-piece plan, no field → no finding) is an L2 contract check.

### Pattern Catalog (verbatim CURRENT anchors)

**C1 — Criterion 26 registry cross-check (147)** — the (a)–(e) cross-check model FR-EG-6 follows:
```
147	26. **Integration allocation (activate only when the spec declares an Integration Coverage block; skip if absent — not an error per NFR-INT-02):** For each declared integration: (a) ... (d) the `## Integration-Test Registry` table is well-formed ...; (e) for every registry row, `registered_in_phase ≤ completes_in_phase` ... Any missing (a)/(b)/(c)/(d)/(e) → must-fix. Evidence: quote the integration and the phase block.
```
> New criterion (e.g. #32 in `.md`, #27 in `.agent.md`): "**Authored-tests declaration (activate only when a phase carries an `**Authored-tests:**` field; absence is never a finding):** each declared path is a literal test path cited in that phase's `[Build]`/`[Implement]`/`[Verify]`/`**Scope:**` body; no declared path collides with a Red-manifest or `integration_registry` path. Collision or phantom declaration → must-fix." Note divergent numbering between `.md` (after 31) and `.agent.md` (after 26).

**C2 — scope-collection precedent (Criterion 11, line 32, present in both files)**:
```
32	    1. For each `### Phase <N>` heading, collect its declared file scope — the union of literal file paths cited in `[Build]`, `[Implement]`, `[Verify]`, and `**Scope:**` lines within the phase's body. Skip Phase Groups ... and Phase 0 Scaffold ...
```
> The "collect literal paths cited in the phase body" mechanic the new criterion reuses to verify a declared path is actually cited.

**C3 — plan.md phase-header conditional-field convention (61–66)** — semantic anchor `### Phase 1 (TDD track example)`:
```
61	**ACs Covered:** {{ac_list}}
62	**In scope:** {{explicit_scope_list}}
63	**NOT in scope:** {{explicit_exclusions_with_forward_phase_references}}
64	<!-- The two fields below are REQUIRED only when this phase edits a multi-step orchestration file ...; omit otherwise. See plan SKILL.md §9c. -->
65	**Steps traversed (P2):** {{steps_or_na}}
66	**Dispatch sites (P3):** {{sites_or_none}}
```
> FR-EG-5's `**Authored-tests:**` is a NEW conditional field documented with an HTML-comment guard exactly like 64 (e.g. `<!-- OPTIONAL: list literal test paths this phase legitimately authors; omit if none. Listed paths are exempt from the Red-immutability reject; a path also in Red's manifest is a hard reject. -->` + `**Authored-tests:** {{authored_test_paths_or_omit}}`). Document at all three flat-phase header sites (61–66, 134–143, 201–206) for consistency; conditional ⇒ omit by default (NFR-EG-3 backward-compat).

---

## Cluster 4 — Step 6c discovery routing (repeated-rejection → plan-incompleteness)

### File Inventory
- `plugins/spec-flow/skills/execute/SKILL.md` `### Step 6c: Discovery Triage` (981–1288) — amendment-budget enforcement note (985); aggregation 3 sources incl. **Build oracle missing-prerequisite escalation (1004)**; aggregation record schema (991–999); triage prompt (1036–1052); `.discovery-log.md` row format (1267–1278).
- `.discovery-log.md` (generated at `docs/prds/<prd-slug>/specs/<piece-slug>/`) — the amendment-history substrate AC-4/FR-EG-8 escalation summarizes.

### Dependency Map
A discovery record `{row_text, default_triage, source_agent, ac_id}` (991–999) enters the aggregated list → operator triage → amend/fork/defer dispatch → `.discovery-log.md` row. FR-EG-9 adds a new source: the **2nd immutability rejection** from Cluster-1 gate (a)/G9b becomes a missing-prerequisite-shaped discovery routed here with `source_agent: orchestrator`, `default_triage: amend` (VOQ-4 chose `orchestrator` over the L1004 `implementer` precedent — it is the orchestrator that detects the reject). Never auto-exempts the touched test; mutability is reachable only via a re-reviewed plan amendment.

### Test Landscape
e2e discovery/amend replay scenarios; `lib/contract.sh check_discovery_log` asserts the 6-column header + first-row match. FR-EG-9 fixture: persistently-tampering Build agent → assert a SINGLE Step 6c row with `source_agent: orchestrator`, `default_triage: amend` after the 2nd rejection; assert exemption set unchanged.

### Pattern Catalog (verbatim CURRENT anchors)

**D1 — missing-prerequisite escalation precedent (1004)** — semantic anchor aggregation source 3. FR-EG-9 mirrors this shape:
```
1004	3. **Build oracle escalations citing missing prerequisite.** When Steps 2/3's oracle iteration budget is exhausted with the implementer escalating that a prerequisite is missing ... the escalation message is captured here as a discovery with `default_triage: "amend"`, `source_agent: "implementer"`, and `row_text` set to the escalation's one-line summary. ...
```
> FR-EG-9 adds a parallel source 4: "2nd immutability rejection on a phase → discovery with `source_agent: orchestrator`, `default_triage: amend`, `row_text` = the named violating paths." Note VOQ-4: precedent uses `implementer`; FR-EG-9 deliberately uses `orchestrator`.

**D2 — aggregation record schema (991–999)** — semantic anchor `phase_<id>_routed_discoveries`:
```
992	   {
993	     row_text:      "<verbatim AC matrix row text, including the | separators>",
994	     default_triage: "amend" | "fork",   # set by Step 4 from the Reason: field
995	     source_agent:  "<agent that produced the matrix, typically `verify` or `implementer`>",
996	     ac_id:         "<AC-N as parsed from the row's AC ID column>"
997	   }
```
(The FR-EG-9 row conforms to this schema — `default_triage: "amend"`, `source_agent: "orchestrator"`, `ac_id` may be `—`.)

**D3 — `.discovery-log.md` row format (1267–1278)** — semantic anchor `#### `.discovery-log.md` authoring`. UNCHANGED by FR-EG-9 (format-compatible):
```
1272	| Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |
1273	|---|---|---|---|---|---|
1274	| phase_3 | requires-amendment | qa-phase | Auth helper missing X | amend | abc1234 chore(plan): amend — ... |
```
> Matches the e2e replay fixture `fixtures/replay/discovery-log.md` (6-col header, `check_discovery_log` asserts it). The amendment-history escalation (FR-EG-8) reads these rows + the git-log `--grep` canonical count.

---

## Notes for the plan author
- **Mirror discipline (FR-EG-10):** every edited agent (`tdd-red`, `implementer`, `qa-plan`) needs `<name>.md` AND `<name>.agent.md`. `verify` only needs editing if FR-EG-4 adds verifier-side prose (current FR-EG-4 lands the re-hash in execute Step 4 item 5, so `verify.md` may stay untouched — confirm during planning). `qa-plan.agent.md` is structurally trimmed (criteria 1–26 vs 1–31) — the new criterion appends at a different number.
- **No-warn-branch reality:** execute gate (a) (607) and G9b (1449) already say "Reject"/"escalate," not "warn." FR-EG-1/FR-EG-2's substantive edits are: (1) compose the declared-authored exemption into the eval order; (2) name violating paths in re-dispatch; (3) route 2nd rejection to Step 6c. AC-1/AC-2 structural asserts (`assert_no_grep` for warn/continue) pass against current prose — they lock the absence in.
- **Heading anchors (CR-006):** `### Step N`, `### Phase N:`, `#### Sub-Phase N.m:`, and the e2e L1_SEQUENCE tokens (`### Step 2: TDD-Red`, `### Step 3: Implement`, `### Step 4: Verify`, `### Step 6: Phase QA`, `## Final Review`) are parser-load-bearing — do not change levels or token text.
- **e2e fixture wiring:** add replay artifacts under `tests/e2e/fixtures/replay/` (or `live-project/`), add `check_*`/structural-assert functions in the matching `lib/*.sh` (`static.sh` for prose asserts, `contract.sh` for fixture-contract asserts), invoked via `run_mode`. Helpers: `assert_grep`/`assert_no_grep`/`assert_file`/`assert_count`/`assert_subject_order`/`assert_exit` in `lib/assert.sh`.

[RESEARCH-CONSUMED: 16 files, 4 re-read]
[DELIBERATION-CONSUMED: one seam/one eval order at the post-commit re-hash gate (M3→immutability→exemption(lower-precedence)→reconciliation, smuggling guard); 2nd-rejection→Step 6c amend row; amendment hard-cap + soft-checkpoint as two thresholds on the single piece_amendment_count counter in one home, (c) continue removed, spike-agent "never hard-blocks" edited — adversarial review AVAILABLE (5 lenses, VOQ-1..4 carried)]
STATUS: OK
