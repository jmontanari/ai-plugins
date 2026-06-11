# Research — exec-ready / exec-guardrails

## Brainstorm Inference Digest

**Piece purpose.** Two execute-integrity guardrails covering FR-011 (G-2 no unplanned mid-stream discovery; G-6 oversight scaled to verifiability; metrics SC-002/SC-003):

1. **Test immutability — upgrade detect-later → reject-mechanically.** `tdd-red` already stages tests and emits a `## Staged test manifest` of `<path>: <sha256>`. The execute orchestrator already re-hashes these at the implementer's unified commit (Step 3 item 7 gate (a)) and at Refactor (Step 4 item 5). **The mechanism for rejection already exists** — this piece *tightens its semantics and closes warn-only/soft escape paths*: (a) ensure any Build-step diff touching a Red-manifest file is rejected pre-commit with violating paths named and the implementer re-dispatched — no warn-and-proceed; (b) phase-exit (Step 4/Verify) re-verification is already a no-op claim ("gate already passed") + a Refactor re-hash — the AC-2 requirement that a phase-exit mismatch is a *blocking finding attributed to the phase* must be made explicit, not silently absorbed; (c) Implement-track phases that legitimately author tests must *declare those paths in the plan phase block*, and qa-plan must verify the declaration (only declared paths are exempt); (d) repeated immutability rejections route to Step 6c as plan-incompleteness — never an exemption.

2. **Amendment budget becomes a HARD CAP.** Today the per-piece budget (5 total / max 1 spec) is **hardcoded in prose** and enforced via a **soft-checkpoint** that *never hard-blocks* (operator gets `(c) continue` on every over-threshold amend, re-surfaced per-amendment). FR-011 AC-4 reverses this: the cap is read from `.spec-flow.yaml` (documented default), reaching it **halts execute with an operator escalation summarizing amendment history** — no soft-checkpoint continuation past it.

**Design constraints inferred.**
- **No new `.spec-flow.yaml` key exists for the budget today** — this piece must add one (e.g. `amendment_budget` / `amendment_spec_budget`) to `templates/pipeline-config.yaml` with a documented default, and wire Step 0 / Step 6c to read it. The current numbers (5 total, 1 spec) live only in prose at `execute/SKILL.md` and `README.md`.
- The change is **orchestration-prose surgery** on one large SKILL (`execute/SKILL.md`, 2031 lines) plus one agent (`tdd-red.md`) and one reviewer agent (`qa-plan.md`), plus template/doc edits. Bash snippets (sha256sum / git show / git log --grep) already carry the integrity logic; tightening = rewording the rejection branch + adding a declared-exemption set.
- **Deferred Phase Group path differs:** under `deferred_commit: auto` integrity runs ONCE at the barrier (Step G9b) against the **working tree** using journal `red_manifest_hashes` (git-blob anchor, `git hash-object -w`), not per-phase HEAD. Any "reject pre-commit" wording must cover both the flat/`off` HEAD-hash path AND the barrier/working-tree path.

**Open ambiguities for the spec author.**
- "Rejected *before any commit*" (AC-1): today gate (a) runs *after* the implementer's unified commit lands (HEAD points at it) and rejects by retry/revert. Is AC-1 satisfied by the existing post-commit-but-pre-acceptance gate, or does the spec demand a genuinely pre-commit diff inspection (e.g. inspect the implementer's staged diff / `git diff --cached` before allowing the commit)? This is the load-bearing design question.
- Budget default value when the key is absent — keep 5/1, or pick new documented defaults? FR says "documented default."
- "Repeated rejections route to Step 6c": what counts as the trigger — second rejection (matching the existing 2-attempt oracle budget) or a distinct immutability-rejection counter? AC-1 already retries within the 2-attempt budget then escalates on second failure.
- How does the qa-plan declared-test-path check (AC-3) interact with the existing M3 `integration_registry` exemption (which already permits one plan-authorized edit to registered `[integration]` paths)?
- Whether amendment-history summary at escalation reuses `.discovery-log.md` rows (Phase | type | source | finding | triage | resolution-commit).

## Codebase Conventions

- **Agent file duplication (Copilot mirror).** Every agent ships twice: `agents/<name>.md` (Claude/canonical) and `agents/<name>.agent.md` (GitHub Copilot mirror, trimmed/restructured — e.g. `qa-plan.agent.md` drops the long numbered-criteria appendix). Edits to an agent's logic must be reflected in BOTH files. Confirmed for `qa-plan`, `tdd-red`, `implementer`, `verify`, etc.
- **`.spec-flow.yaml` config pattern.** Keys are read in `execute/SKILL.md` Step 0/per-step with the idiom: valid-values list, documented default when absent/unset (NN-C-003), malformed → one-line warning + default. Template lives at `templates/pipeline-config.yaml` with a comment block per key (purpose + value enumeration + version-introduced note). Existing keys: `refactor`, `merge_strategy`, `tdd`, `deferred_commit`, `model_policy`, `qa_max_iterations`, `default_branch`.
- **Single source of truth refs.** Cross-cutting definitions live in `reference/*.md` and are cited (not restated) per CR-008/NN-C-008. Budget mechanics cross-ref `reference/spike-agent.md` `## Soft-checkpoint budget`; integrity/journal cross-ref `reference/deferred-commit-journal.md`; matrix cross-ref `reference/ac-matrix-contract.md`.
- **Heading anchors are parser-load-bearing (CR-006).** `### Step N`, `### Phase N:` (H3), `#### Sub-Phase N.m:` (H4) are detection anchors — do not change levels.
- **No-runtime-dependency (NN-C-002).** All guardrail logic must be orchestration prose + POSIX bash (sha256sum, git show/cat-file/hash-object/log --grep). No compiled tool, no python beyond optional hook fast-path with bash fallback. Markdown/YAML/JSON/bash only.
- **NN-P-002 two-gate preservation.** Every gate change must NOT bypass per-phase QA (Step 6) or end-of-piece review board. Guardrails *tighten*, never become merge paths.
- **Version bump required (NN-C-009/001):** any change bumps `plugins/spec-flow/plugin.json`, `.claude-plugin/marketplace.json`, and `CHANGELOG.md` (Keep a Changelog).

## Cluster 1 — Test-immutability anti-cheat (tdd-red manifest + execute integrity gates)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/agents/tdd-red.md` (+ `.agent.md` mirror) — Rule 6/10 + `## Staged test manifest` output. **Computes** sha256 per staged test path; **stages** via `git add -- <literal>`, does NOT commit; **reports** the manifest as `<path>: <sha256>` lines in its return digest (also persisted by orchestrator to `/tmp/spec-flow/phase-N-red-manifest.json`). In deferred groups it does NOT git-add; orchestrator anchors via `git hash-object -w`.
- `plugins/spec-flow/skills/execute/SKILL.md` — the orchestration surgery target. Key lines: Step 2 item 6 (capture manifest, defensive re-hash) ~496–508; **Step 3 item 7 gate (a)** content-hash integrity ~599–679; gate (b) reconciliation ~681–690; **Step 4 item 5** phase-exit/Refactor test integrity ~763; M3 `integration_registry` edit-window ~609–677.
- `plugins/spec-flow/agents/implementer.md` (+ `.agent.md`) — Rule 8 + "What Red test modification means" ~63, anti-pattern "Do NOT modify test files" ~86. Already states the gate is "strict and unforgiving."
- `plugins/spec-flow/agents/verify.md` (+ `.agent.md`) — Audit/Full phase-exit verifier; theater catalog. No current explicit Red-manifest re-hash (delegated to orchestrator Step 4 item 5).
- `plugins/spec-flow/reference/deferred-commit-journal.md` — `red_manifest_hashes` journal field (git-blob anchor), barrier-commit integrity (Step G9b), `## Resume` re-verify-by-hash.
- `plugins/spec-flow/templates/plan.md` — `[TDD-Red]` block + per-sub-phase `Verify: no test files modified since [TDD-Red] step` (~115, ~293); Integration-Test Registry table (~49–55).

### Dependency Map
**Dependency Map:** `tdd-red` emits manifest → orchestrator captures (Step 2.6) + defensive re-hash → splices into implementer prompt as `## Red staged test manifest` (Step 3) → implementer creates unified commit → **orchestrator Step 3.7 gate (a)** re-hashes HEAD blobs vs manifest, mismatch = reject + retry (2-attempt) then escalate → Step 4.5 (M3 completing window) / Step 4 item 5 (Refactor re-hash). Deferred-group fork: `red_manifest_hashes` in journal → barrier (G9b) working-tree re-hash. M1 invariant: `integration_registry` rows from plan+Red only, never Build.

### Test Landscape
**Test Landscape:** No unit-test harness here — spec-flow is markdown/bash; validation is via the e2e pipeline smoke-test harness (`plugins/spec-flow/tests/`, see commit 7d04a89 "3-layer L1/L2/L3"). Guardrail behavior is verified by L1/L2/L3 scenario fixtures + qa-plan/review-board adversarial review, not xUnit. Integrity bash snippets are self-checking (`echo "integrity fail: $path"`).

### Pattern Catalog
**Pattern Catalog:**

Current gate (a) rejection prose (the warn→reject seam, execute/SKILL.md ~599–607):
```bash
for path in <manifest paths>; do
  commit_hash=$(git show HEAD:"$path" | sha256sum | cut -d' ' -f1)
  manifest_hash=<manifest hash for path>
  [ "$commit_hash" = "$manifest_hash" ] || echo "integrity fail: $path"
done
```
> Any mismatch means the implementer modified one of Red's tests — the anti-cheat safeguard replacing pre-v2.7.0's `git diff tests/` check. Reject the phase and retry within the 2-attempt budget (the retry must recreate the commit without touching Red's tests). Escalate on second failure.

tdd-red manifest output contract (tdd-red.md ~128–131):
```
## Staged test manifest
- tests/path/test_foo.py: a3f5c891...
- tests/path/test_bar.py: b71d2a4e...
```

Phase-exit (Step 4 item 5) — the "already passed / no-op" wording AC-2 must harden into a blocking finding:
> the primary anti-tampering safeguard runs at Step 3.7a … By the time Step 4 runs, that gate has already passed — so no additional diff is needed here. … If the phase produces a Refactor commit … re-run the content-hash check against HEAD after Refactor lands … If any hash drifts at Refactor time: REJECT, revert the refactor commit, and flag the Refactor agent for re-dispatch.

## Cluster 2 — Amendment budget (soft-checkpoint → hard cap)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/execute/SKILL.md` — `#### Amendment budget tracking` ~1211–1263 (counters, recovery, pre-dispatch check, **soft-checkpoint prompt**); Step 6c amend-dispatch ~985; auto-mode budget reuse ~1097; Step 8 Final Review budget reuse ~1761; reflection budget ~1872.
- `plugins/spec-flow/templates/pipeline-config.yaml` — `.spec-flow.yaml` template; **NO amendment-budget key exists today** (keys: refactor/merge_strategy/tdd/deferred_commit/model_policy/qa_max_iterations/default_branch). New key must be added here with documented default.
- `plugins/spec-flow/reference/spike-agent.md` `## Soft-checkpoint budget` ~67–72 — canonical budget-counter definition (`piece_amendment_count`, `piece_spec_amendment_count`). Must flip from soft-checkpoint to hard-cap semantics (or be superseded).
- `plugins/spec-flow/reference/coordinator-contract.md` ~40 — amendment-counter recovery (recompute from branch history, no escalation).
- `plugins/spec-flow/reference/metrics-artifact.md` ~75 — `execute.amendments.total` = `piece_amendment_count` (SC link).
- `plugins/spec-flow/README.md` ~224, ~242 — documents "5 total / max 1 spec" budget prose (must update to reflect configurable hard cap).

### Dependency Map
**Dependency Map:** Counters live in piece-scoped orchestrator state, recovered on resume via `git log --grep '^chore(plan): amend' / '^chore(spec): amend'`. Pre-dispatch check at every `plan-amend`/`spec-amend` (Step 6c, Step 8, reflection, auto-mode) currently routes ≥threshold to the **four-option soft-checkpoint** `(c)/(f)/(d)/(b)`. FR-011 AC-4 replaces the `(c) continue` continuation with a hard halt+escalation summarizing amendment history (likely from `.discovery-log.md`). Budget value flows from new `.spec-flow.yaml` key → Step 0 load → all amend dispatch sites.

### Test Landscape
**Test Landscape:** Verified via e2e pipeline harness amendment-loop scenarios + review-board; no unit tests. Counter recovery is a pure `git log | wc -l` reconstruction (lossless, testable by fixture branch history).

### Pattern Catalog
**Pattern Catalog:**

Current counter recovery (execute/SKILL.md ~1222–1223):
```bash
piece_amendment_count = git log --oneline $piece_start_sha..HEAD --grep '^chore(plan): amend' --grep '^chore(spec): amend' | wc -l
piece_spec_amendment_count = git log --oneline $piece_start_sha..HEAD --grep '^chore(spec): amend' | wc -l
```

Current **soft-checkpoint** (the prose AC-4 must replace with a hard halt, ~1241–1263):
```
Hit <N> amendments — this piece may be under-scoped. Choose:
  (c) continue amending
  (f) fork remaining must-fix work into a new piece
  (d) defer this finding
  (b) block piece
```
> The count never resets within a piece and never hard-blocks. The soft checkpoint re-surfaces on each subsequent amendment; the operator's `(c)` choice is per-amendment.

Existing block-and-exit pattern to reuse for the hard-cap halt (~1256–1261):
```bash
git add docs/prds/<prd-slug>/manifest.yaml
git commit -m "chore(<piece-slug>): block — amendment budget exhausted"
```
> exit with: `Halted: piece <piece-slug> status set to blocked (amendment budget exhausted). Re-spec or abandon recommended.`

## Cluster 3 — qa-plan declared-test-path verification + plan phase-block format

### File Inventory
**File Inventory:**
- `plugins/spec-flow/agents/qa-plan.md` (+ `.agent.md` mirror) — adversarial plan reviewer. Criterion 3 (TDD structure: `[TDD-Red]`→`[QA-Red]`→`[Build]`→`[Verify]`); Criterion 8 (charter constraint allocation); Criterion 26 (Integration allocation — validates registry rows incl. `registered_in_phase`); Criterion 23/28 (Change Specification Block path discipline); Criterion 32-collection of per-phase `In scope:`/`[Build]`/`[Implement]`/`[Verify]` literal paths. **This is where AC-3's "qa-plan verifies the declaration" hooks in** — add a criterion checking Implement-track phases that author test paths declare them.
- `plugins/spec-flow/templates/plan.md` — phase block anatomy: `**In scope:**` / `**NOT in scope:**` (~62, ~139, ~202), `[TDD-Red]` (~70), `[Build]` (~85), `[Implement]` (~147/210), per-sub-phase `**Scope:** {{literal_file_paths}}` (~275/300), Integration-Test Registry (~49–55), front-matter `tdd:`/`legacy_deferred_rows:` (~9). The **`In scope:`/`Scope:` literal-path list is the natural home for declared test-path exemptions.**
- `plugins/spec-flow/skills/plan/SKILL.md` — plan authoring rules (§9c P2/P3, §9a Executable AC Binding) referenced by qa-plan criteria.

### Dependency Map
**Dependency Map:** qa-plan reads `plan.md` phase blocks (read-only, never modifies). Criterion 26 already parses the Integration-Test Registry's `registered_in_phase`/`completes_in_phase` and cross-checks against `[Integration-Test]` blocks — the precedent for a new "declared test paths" criterion. The orchestrator's Step 3.7 gate (a) exemption set (Red manifest ∪ M3 registry paths) would extend to include qa-plan-verified declared Implement-track test paths. AC-3: "only declared paths exempt."

### Test Landscape
**Test Landscape:** qa-plan is itself a QA gate (no tests of its own); its criteria are exercised by plan-stage fixtures in the e2e harness. New criterion is verified the same way (a plan fixture that authors tests on Implement track without declaring → must-fix).

### Pattern Catalog
**Pattern Catalog:**

qa-plan scope-collection precedent (qa-plan.md Criterion 32 step 1):
> For each `### Phase <N>` heading, collect its declared file scope — the union of literal file paths cited in `[Build]`, `[Implement]`, `[Verify]`, and `**Scope:**` lines within the phase's body.

Integration-allocation criterion (the cross-check precedent for AC-3, Criterion 26):
> (e) for every registry row, `registered_in_phase ≤ completes_in_phase` … Any missing (a)/(b)/(c)/(d)/(e) → must-fix.

Plan phase-block scope declaration (templates/plan.md ~62-63, ~275):
```
**In scope:** {{explicit_scope_list}}
**NOT in scope:** {{explicit_exclusions_with_forward_phase_references}}
...
**Scope:** {{literal_file_paths_comma_separated}}
```

## Cluster 4 — Step 6c discovery routing (repeated-rejection → plan-incompleteness)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/execute/SKILL.md` `### Step 6c: Discovery Triage` ~981–1263 — aggregates three discovery sources (Step 4 Reason-routed `requires-amendment`/`requires-fork`; qa-phase deferred-to-reflection; Build oracle missing-prerequisite escalations ~1004), triage prompt with `(a) amend / (s) amend-spec / (f) fork / (d) defer` (~1034–1052), per-discovery dispatch, `.discovery-log.md` row append (~1265–1278), auto-mode 50% threshold (~1068–1103).
- `.discovery-log.md` (generated per piece at `docs/prds/<prd-slug>/specs/<piece-slug>/`) — the amendment-history record AC-4's escalation can summarize.

### Dependency Map
**Dependency Map:** A discovery row `{type, source_agent, ac_id, row_text, default_triage}` enters the aggregated list → operator triage → amend/fork/defer dispatch → `.discovery-log.md` row. FR-011's failure mode adds a new source: **repeated immutability rejection** from Cluster-1's gate (a) becomes a `requires-amendment`/plan-incompleteness discovery routed here (`default_triage: amend`, `source_agent: implementer`/orchestrator), never an exemption. Existing missing-prerequisite escalation path (~1004) is the closest precedent.

### Test Landscape
**Test Landscape:** Exercised by e2e harness discovery/amend scenarios. The `.discovery-log.md` table format (Phase | Discovery type | Source agent | Finding | Triage choice | Resolution commit) is the structured record.

### Pattern Catalog
**Pattern Catalog:**

Existing escalation→6c-as-amendment precedent (execute/SKILL.md ~1004):
> When Steps 2/3's oracle iteration budget is exhausted with the implementer escalating that a prerequisite is missing … the escalation message is captured here as a discovery with `default_triage: "amend"`, `source_agent: "implementer"`, and `row_text` set to the escalation's one-line summary.

`.discovery-log.md` row format (~1272–1275) — amendment-history substrate for AC-4 escalation:
```markdown
| Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |
|---|---|---|---|---|---|
| phase_3 | requires-amendment | qa-phase | Auth helper missing X | amend | abc1234 chore(plan): amend — ... |
```
