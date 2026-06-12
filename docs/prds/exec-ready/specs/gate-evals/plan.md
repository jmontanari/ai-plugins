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
legacy_deferred_rows: false
# review_board_variant NOT set — this piece is python code + bash fixtures + a guardrail-integrity
# edit, not skill/reference doc-as-code; the blind review-board seat is retained.
---

# Plan: gate-evals

**Spec:** docs/prds/exec-ready/specs/gate-evals/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Two cleanly-separated halves over one piece.

**(1) Internal transcript-mining tool (python 3 + pip)** at repo-root `tools/transcript-eval/` —
**not shipped, not under `plugins/<plugin>/`**, so NN-C-002 (consumer zero-install) does not govern it
by location. It reads real `~/.claude/projects/<project>/*.jsonl` session transcripts **read-only**,
parses **best-effort** (probe fields, null on miss, report coverage — never silently drop), extracts
per-seat gate **findings** + an **inferred operator accept/reject**, computes **precision /
verdict-overlap / leave-one-out unique-catch / rubber-stamp / activity** (real-usage signal —
explicitly **not recall**), renders a cross-repo pipeline-health **story** with the FR-016 per-seat
evidence as a required section, and writes everything to a **durable repo-peer insight store**
(default `/Volumes/joeData/spec-flow-insights/`) **outside repo scope**. An up-front
**extraction-validation spike (operator-gated)** gates the metric/story build on real coverage
(≥95%) + accept/reject agreement (≥80%). The parse/scrub/aggregate core is a reusable lib that
`flywheel-global` (FR-007) imports later.

**(2) Consumer-surface guardrail evals (pure bash)** under `plugins/spec-flow/tests/e2e/` — a
**reconstructed cheater oracle** that re-implements the FR-011 execute-integrity predicate
(content-hash vs Red manifest; `--name-only` reconciliation; smuggling = manifest ∩ exempt; M3
window; amendment cap) against a tampered HEAD built in `e2e_mktemp` with `trap … EXIT` cleanup;
the **EG-1 residual tier** (transitive/by-name closure tamper — documented expected-fail, excluded
from the 100% headline); the **EG-2 guardrail fix** (an explicit per-sub-phase `exempt_authored`
attribution rule at the G9b Phase-Group barrier) + a multi-sub-phase locking fixture that the fix
turns into a *detected* cheat. Then the cross-cutting contract: an additive `rubric_version` tag on
the 13 measured gate-agent pairs, the FR-016 citation obligation in `gate-scaling.md#board-swap-rule`,
an honest SC-009 re-scope, and the version bump.

**No model is invoked anywhere in this piece** — mining is deterministic `.jsonl` parsing; the
cheater track is deterministic bash. The `tests/e2e/README.md` "harness never invokes a model"
invariant therefore stays true unchanged.

Finally, **Phase 10** is the operator-gated capstone: it **runs** the validated miner across the real
cross-repo corpus to produce the **first persisted baseline** (aggregates + story in the external
store) — the actual FR-016 evidence, not just the tool that could produce it. Without it the piece
would ship a measuring instrument that was never run on real data (the "documented to run" trap); it
satisfies the judgment halves of AC-3/AC-5/AC-6 against reality. All mined output stays in the external
store; only run-provenance metadata touches the repo (SF-5/SF-6).

**Non-TDD mode** (`tdd: false`): all phases use `[Implement]` → `[Write-Tests]` → `[Verify]` → `[QA]`.
The AC Coverage Matrix is included below for traceability (not required in non-TDD mode); per-phase
QA gates and the end-of-piece Final Review remain fully intact.

**Confidence note (carried from `deliberation.md`):** the **mining-half design (Phases 1–4) was
operator-driven and was NOT re-run through the 5-phase deliberation board** — treat it as a
lower-confidence anchor and lean on per-phase QA. The **cheater-track design (Phases 5–6) WAS
adversarially vetted** (architecture-integrity HOLDS; risk-lens folded the single-sha256-shim,
`trap … EXIT`, and EG-1/EG-2-tier decisions). The reconstructed oracle is **green-by-construction
against itself** (VOQ-1) — it pins to the live predicate via one shared sha256 shim and cannot
surface a live-gate bypass; the live-gate-grader path is a deferred future decision (ADR-7).

## Charter Constraint Allocation

Every NN-C/NN-P/CR the spec claims is allocated to exactly one phase (no drops, no duplicates).
The per-phase "Charter constraints honored in this phase" slots are authoritative; this table is the
cross-check.

| Entry | Short name | Phase |
|-------|-----------|-------|
| NN-C-002 | bash-only consumer / python by location | Phase 1 |
| CR-005 | repo-root-relative paths | Phase 1 |
| NN-P-004 | operator-gated | Phase 2 |
| CR-008 | thin orchestrator / narrow executor | Phase 2 |
| NN-P-005 | Opus-thinking/Sonnet-mechanics — no model invoked | Phase 3 |
| (Phase 4 carries no charter entry — all allocated elsewhere) | — | — |
| NN-C-006 | destructive ops confined (e2e_mktemp + trap) | Phase 5 |
| CR-009 | heading hierarchy (fixtures/docs) | Phase 5 |
| NN-C-003 | backward-compat additive (the one behavior change = EG-2) | Phase 6 |
| NN-C-004 | bare agent `name:` | Phase 7 |
| NN-C-008 | self-contained agents | Phase 7 |
| NN-P-001 | human sign-off gate never removed | Phase 8 |
| NN-C-001 | plugin/marketplace version sync | Phase 9 |
| NN-C-009 | version bump | Phase 9 |
| CR-004 | conventional commits | Phase 9 |

## Architectural Decisions

### ADR-1: Mine real session transcripts instead of fabricating a labeled fixture corpus
**Context:** FR-016 board-seat cuts must be evidence-gated (G-6). The original design fabricated a
60–80 labeled fixture corpus. A plan-stage data check found the operator's real spec-flow session
transcripts (`~/.claude/projects/<project>/*.jsonl`) are plentiful (prop-firm 195 sessions /
ai-plugins 57 / pool) and already carry per-seat gate dispatches + results.
**Decision:** Mine real sessions for precision/overlap/leave-one-out/activity. The fabricated-corpus
machinery is superseded; only the cheater track (recall floor) survives from the prior design.
**Alternatives considered:** (a) fabricated corpus — dropped: high authoring cost, only *controlled*
recall, no real-usage signal; (b) LLM re-run of a past gate against its artifact for verdict-flip —
deferred to a later piece (it needs a model in the loop; this piece is deterministic).
**Consequences:** Mining gives **precision, not true recall** (you cannot see defects nobody
flagged) — recall comes only from the cheater track. The "story" must never claim a "catch rate"
(SF-8/SC-009). Extraction depends on an undocumented `.jsonl` schema → gated by the SF-7 spike.
**Charter alignment:** NN-P-004 (operator-gated, out-of-band), NN-P-005 (no model invoked).

### ADR-2: `rubric_version` measured set = 13 gate-agent pairs (triage/charter/PRD excluded)
**Context:** SF-12 adds an additive `rubric_version` key to "every measured gate-agent pair" so mined
metrics segment by rubric era. "Measured" is ambiguous across 17 candidate `qa-*`/`review-board-*` pairs.
**Decision:** Tag the **13 pairs** whose per-seat verdicts the miner measures from real transcripts:
`qa-spec, qa-plan, qa-phase, qa-phase-lite, qa-tdd-red` + `review-board-{architecture, blind,
edge-case, ground-truth, integration, prd-alignment, security, spec-compliance}`.
**Alternatives considered:** (a) all 17 — over-scopes; `review-board-triage` renders no correctness
verdict and `qa-charter/qa-prd/qa-prd-review` are charter/PRD-stage gates outside FR-017's
"merge-blocking QA gate" measurement scope; (b) only the 8 named board seats + qa-spec/plan/phase
(11) — drops `qa-phase-lite`/`qa-tdd-red`, which DO render measurable per-seat findings inside Phase
Groups / TDD-Red.
**Consequences:** 26 files edited (13 byte-identical `.md`/`.agent.md` pairs). Excluded agents stay
untagged with documented rationale; a future piece can extend the set additively.
**Charter alignment:** NN-C-004 (bare `name:` preserved), NN-C-008 (no conversation-history
assumption added), NN-C-003 (additive optional key).

### ADR-3: Internal python tool lives at repo-root `tools/transcript-eval/` (NN-C-002 by location)
**Context:** The miner needs python + pip; NN-C-002 mandates bash-only / zero runtime deps for
*shipped plugin* artifacts.
**Decision:** Place the tool at **repo-root `tools/transcript-eval/`** — outside `plugins/<plugin>/`
and outside the rsync'd distribution (`releasing.md`/charter-processes ships only `plugins/spec-flow/`).
**Alternatives considered:** (a) under `plugins/spec-flow/` with a bash fallback — rejected: forces a
bash re-implementation of `.jsonl` parsing/scrub/aggregate, large and fragile (NN-C-002 hostile); (b)
a charter amendment widening NN-C-002 — rejected: unnecessary; the location already exempts it. An
optional one-line NN-C-002 scope clarification is a possible follow-up, not part of this piece.
**Consequences:** The end-user zero-install guarantee is unchanged (the tool never enters an installed
runtime). The python `requirements.txt` lives ONLY at `tools/transcript-eval/` — never under
`plugins/spec-flow/` (AC-12 verifies both).
**Charter alignment:** NN-C-002 (honored by location), CR-005 (in-repo refs repo-root-relative).

### ADR-4: External insight-store layout (OQ-2 resolution)
**Context:** SF-5 needs a concrete repo-peer store layout the run history accrues into.
**Decision:** `<store>/` (default `/Volumes/joeData/spec-flow-insights/`) holds:
`<store>/projects/<encoded-project>/` per source project; a single append-only
`<store>/run-index.jsonl` (one JSON record per run, with a `kind` field); `<store>/aggregates.json`
(latest accrued per-seat aggregates); `<store>/story-latest.md` (newest rendered story snapshot) +
`<store>/stories/<run-id>.md` archive.
**Alternatives considered:** (a) per-project subdir with its own run index — rejected: cross-repo
aggregation wants one global index; (b) committed-in-repo store — rejected: violates SF-6 privacy +
loses durability on `git clean`.
**Consequences:** A repo wipe / worktree removal / `git clean` cannot touch the store. The store path
is validated at startup; unwritable ⇒ loud non-zero failure, **no in-repo fallback** (SF-NFR-4).
**Charter alignment:** CR-005 (external store path is configurable/absolute, distinct from
repo-root-relative in-repo refs).

### ADR-5: EG-2 fix = a prose attribution rule at G9b, not a new mechanism
**Context:** AC-9 — a multi-sub-phase Phase Group where sub-phase A declares an `exempt_authored`
path that sub-phase B tampers must be **rejected** at the G9b barrier. Today G9b (execute/SKILL.md
line 1495) checks "not in the sub-phase's `exempt_authored` set" but never states **how** a
sub-phase's `exempt_authored` is derived for the deferred path — the flat-phase derivation lives only
at line 704, so the deferred barrier is ambiguous about per-sub-phase attribution.
**Decision:** Insert an explicit **per-sub-phase attribution rule** into G9b step 1: each sub-phase's
`exempt_authored` is parsed from THAT sub-phase's own `**Authored-tests:**` field; an exemption
declared by sub-phase A confers NO exemption when the same path appears in sub-phase B's
`red_manifest_hashes` and drifts. Add a worked example. No new bash mechanism — it tightens the
existing per-sub-phase re-hash loop.
**Alternatives considered:** (a) a new orchestrator-state attribution map — rejected: the per-sub-phase
`exempt_authored` already exists in the journal `sub_phases`; the gap is *documentation* of the
attribution semantics, not data; (b) leave it implicit — rejected: AC-9 requires the tamper be
provably caught, which needs the rule stated and a locking fixture.
**Consequences:** The only **behavior change** in the piece (a stricter integrity check → CHANGELOG
`### Fixed`). The locking fixture (a cross-sub-phase exemption tamper) flips from a latent gap to a
*detected* cheat. Backward-compatible: legitimate same-sub-phase exemptions are unaffected.
**Charter alignment:** NN-C-003 (backward-compat — additive tightening, not a removed gate; CHANGELOG
Fixed), NN-P-002 (gate-tightening, never a merge path).

### ADR-6: Accept/reject inference heuristic + SF-7 spike gate (OQ-1 resolution)
**Context:** Operator accept/reject of a finding is not recorded as a field — it must be inferred.
**Decision:** Heuristic: a finding is `accepted` when a downstream fix dispatch
(`fix-doc`/`fix-code`/`implementer`) or Edit referencing the finding appears later in the same
session; else `rejected`/dismissed. The **SF-7 spike** hand-validates ≥20 findings across ≥3 sessions
/ ≥2 repos and **halts the downstream build** unless seat/finding coverage ≥95% AND accept/reject
agreement ≥80% (defaults, tunable).
**Alternatives considered:** (a) require an explicit accept/reject field — rejected: not present in
historical transcripts (no retro-capture possible); (b) skip validation, trust the heuristic —
rejected: a naive `jq` extraction came back empty; unvalidated extraction risks silently-wrong
evidence feeding FR-016 cuts.
**Consequences:** Below threshold ⇒ the **inference design**, not just the threshold, is revisited at
plan/execute time (halt-and-redesign). Above threshold ⇒ the metric/story layer proceeds.
**Charter alignment:** NN-P-004 (the spike gate is an operator-reviewed decision).

### ADR-7: Cheater oracle is a reconstructed copy, parity-pinned by one sha256 shim (VOQ-1 carried)
**Context:** The FR-011 predicate is ~200 lines of LLM-orchestrated prose in execute/SKILL.md — not a
sourceable production function. A bash oracle must re-implement it.
**Decision:** Reconstruct the predicate in `lib/cheater-oracle.sh`, normalizing the hash through ONE
`sha256` shim that matches whatever the live gate hardcodes (`sha256sum`, BSD `shasum -a 256`
fallback). The oracle is the deterministic recall floor against constructed tampers.
**Alternatives considered:** (a) drive scripted cheats through the LIVE execute reconciliation with
the oracle as GRADER-only — deferred (needs a live execute run; out of scope here); (b) labeled-
assertion replay (today's `gate-ac{4,5,6}` static fixtures) — kept for the allow-set/label fixtures
but insufficient for behavioral recall.
**Consequences:** The oracle is **green-by-construction against itself** (VOQ-1) — it validates the
*taxonomy is mechanically detectable*, not that the live gate has no bypass. The live-gate-grader
path remains a documented future decision. Parity is pinned by the shared shim so an oracle/live hash
divergence is caught.
**Charter alignment:** NN-C-002 (pure bash, no deps), NN-C-006 (tampered repos confined to
`e2e_mktemp` + `trap … EXIT`).

## Integration-Test Registry (M1)

Built from plan authoring; carried across phases by execute. `skeleton_sha256`/`completed_sha256` are
runtime-populated (`—` at plan time). Non-TDD mode: each outer `[integration]` test is authored +
greened inline in its completing phase's `[Integration-Test]` step (no cross-phase Red).

| ID | Path | Boundary (inside) | Doubled externals (contract test) | AC | registered_in_phase | completes_in_phase | skeleton_sha256 | completed_sha256 |
|----|------|-------------------|-----------------------------------|----|--------------------|---------------------|-----------------|------------------|
| INT-1 | `plugins/spec-flow/tests/e2e/lib/cheater-oracle.sh` (self-run integration assertion) | reconstructed bash oracle + execute/SKILL.md FR-011 predicate region | FR-011 predicate re-implemented as the oracle (contract test: the shared `sha256` shim parity check) | AC-7, AC-9 | 5 | 6 |  — | — |
| INT-2 | `tools/transcript-eval/tests/test_integration_store.py` | parse + scrub + aggregate lib + store writer | filesystem insight store (privacy-bound — temp store path + in-repo no-write assertion) | AC-1, AC-4, AC-5 | 1 | 4 | — | — |

## Phases

### Phase 1: Tool foundation + external insight store writer
**Exit Gate:** `tools/transcript-eval/` package imports; CLI `--help` runs; the store writer creates
the configured store and **fails loudly** (non-zero, no in-repo write) on an unwritable path;
`pytest tools/transcript-eval/` passes the foundation + store tests.
**ACs Covered:** AC-4
**In scope:** CREATE the `tools/transcript-eval/` python package skeleton (lib + CLI + `requirements.txt`
+ setup note); config loading (project-dir set + store path, with defaults); the external store
writer with startup path-validation + loud-fail; the `## No secrets` scrub-clause reference wiring
(scrub applied in Phase 2); committed sample `.jsonl` fixtures under `tools/transcript-eval/tests/fixtures/`.
**NOT in scope:** extraction logic — Phase 2; metric math — Phase 3; story render + the lib→store
integration test — Phase 4; any `plugins/spec-flow/` change — Phases 5–9.
**Authored-tests:** tools/transcript-eval/tests/test_store.py, tools/transcript-eval/tests/test_config.py
**Charter constraints honored in this phase:**
- NN-C-002 (bash-only consumer / python by location): the tool is created at **repo-root `tools/`**,
  outside `plugins/<plugin>/` and the shipped distribution — python+pip is permitted here by location.
- CR-005 (repo-root-relative paths): all in-repo references repo-root-relative; the external store
  path is configurable/absolute (ADR-4).

- [x] **[Implement]** Build the package skeleton, config, and store writer
  - Order: package/layout + requirements → config loader → store-writer (validate → write → loud-fail) → fixtures.
  - Architecture constraints: read-only against `~/.claude/projects/` (SF-NFR-1); the ONLY writable
    target is the external store (SF-6); no in-repo write path ever (ADR-4).

  **Change Specifications:**

  **T-1: CREATE `tools/transcript-eval/requirements.txt`**
  - Structure: pinned deps the tool needs (standard-library-first; declare only what is actually
    imported — e.g. none beyond stdlib if `json`/`pathlib`/`argparse`/`re` suffice; otherwise list
    them, one per line with `==` pins). Include a top comment: `# internal maintainer tool — repo-root tools/, NOT shipped (NN-C-002 by location, ADR-3)`.
  - Pattern: standard pip `requirements.txt` (one `pkg==x.y.z` per line).
  - Done: file exists; every listed dep is imported by the tool; if stdlib-only, the file states so in a comment and lists nothing.
  - Verify: `test -f tools/transcript-eval/requirements.txt`

  **T-2: CREATE `tools/transcript-eval/README.md`**
  - Structure: one H1; a one-line setup contract (`python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt`), the CLI usage, the store-path/project-dir config keys + defaults, and an explicit "internal-only, not shipped, NN-C-002 by location" note. Heading hierarchy one H1/H2/H3 (CR-009).
  - Pattern: mirror the concise style of `plugins/spec-flow/tests/e2e/README.md`.
  - Done: README documents setup + CLI + config + the not-shipped rationale.
  - Verify: `grep -q "not shipped" tools/transcript-eval/README.md`

  **T-3: CREATE `tools/transcript-eval/transcript_eval/__init__.py` + `config.py`**
  - Structure: `config.py` exposes `load_config(cli_args, env) -> Config` where `Config` carries
    `project_dirs: list[Path]` (default: all `~/.claude/projects/*/`), `store_path: Path` (default
    `/Volumes/joeData/spec-flow-insights/`), and `thresholds` (coverage 0.95, agreement 0.80 — used
    in Phase 2). Config sources, in precedence order: CLI flag > env var (`SPEC_FLOW_INSIGHTS_STORE`,
    `SPEC_FLOW_PROJECT_DIRS`) > default.
  - Pattern (NN-C-002 fast-path idiom, adapted — python IS the impl here, no bash fallback per ADR-3):
    ```python
    # config precedence: CLI > env > default (no in-repo write target is ever a valid store_path)
    def load_config(args, env):
        store = args.store or env.get("SPEC_FLOW_INSIGHTS_STORE") or DEFAULT_STORE
        ...
    ```
  - Done: `load_config` returns a `Config` with the documented precedence; an in-repo `store_path`
    (a path under the repo root) is rejected at construction (guards SF-6).
  - Verify: `python3 -c "from transcript_eval import config"` (run from `tools/transcript-eval/`) exits 0.

  **T-4: CREATE `tools/transcript-eval/transcript_eval/store.py`**
  - Structure: `class InsightStore` with `__init__(config)` that **validates writability at startup**
    (creates `store_path` if absent under a writable parent; raises `StoreUnwritableError` with a loud
    message + non-zero exit if the parent is unwritable — NO in-repo fallback); `append_run(record:
    dict)` → appends one JSON line to `<store>/run-index.jsonl` with a `kind` field; `write_aggregates`,
    `write_story` per the ADR-4 layout. Every write target is under `store_path`; assert no path
    resolves under the repo root.
  - Pattern:
    ```python
    # loud-fail, no in-repo fallback (SF-NFR-4)
    if not os.access(self.store_path.parent, os.W_OK):
        raise StoreUnwritableError(f"insight store unwritable: {self.store_path} — refusing in-repo fallback")
    ```
  - Done: writable store → files land under `store_path`; unwritable parent → `StoreUnwritableError`,
    non-zero exit, nothing written in-repo.
  - Verify: `pytest tools/transcript-eval/tests/test_store.py -q` (after T-7).

  **T-5: CREATE `tools/transcript-eval/transcript_eval/cli.py` + console entry**
  - Structure: `argparse` CLI exposing `--store`, `--project-dir` (repeatable), `--help`; subcommands
    stubbed for `extract` (Phase 2), `metrics` (Phase 3), `story` (Phase 4). `--help` lists them; the
    not-yet-built subcommands print a clear "implemented in a later phase" notice rather than crashing.
  - Pattern: standard `argparse` with `subparsers`.
  - Done: `python3 -m transcript_eval --help` exits 0 and lists the subcommands.
  - Verify: `cd tools/transcript-eval && python3 -m transcript_eval --help` exits 0.

  **T-6: CREATE sample `.jsonl` fixtures under `tools/transcript-eval/tests/fixtures/`**
  - Structure: ≥2 small hand-built `.jsonl` files modeled on the real schema (Cluster A): a
    `clean-session.jsonl` (a couple of `type:assistant` records with `tool_use` Agent dispatches
    `subagent_type: spec-flow:qa-phase`/`spec-flow:review-board-security` + correlated `tool_result`
    findings + a downstream fix dispatch), a `malformed.jsonl` (one valid record + one truncated/invalid
    JSON line), and a `secret-bearing.jsonl` (a record whose text contains a secret-shaped token,
    e.g. `sk-ABCD...`, for the Phase 2 scrub test).
  - Pattern (real record shape, Cluster A): `{"type":"assistant","sessionId":"…","message":{"content":[{"type":"tool_use","name":"Agent","id":"toolu_x","input":{"subagent_type":"spec-flow:qa-phase","description":"…","prompt":"…"}}]}}` then `{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_x","content":"<finding prose>"}]}}`.
  - Done: fixtures exist; `clean-session.jsonl` parses with ≥2 seat dispatches + correlated results;
    `malformed.jsonl` has exactly one unparseable line; `secret-bearing.jsonl` carries one secret token.
  - Verify: `python3 -c "import json,sys; [json.loads(l) for l in open('tools/transcript-eval/tests/fixtures/clean-session.jsonl')]"` exits 0.

  **T-7: CREATE `tools/transcript-eval/tests/test_store.py` + `test_config.py`** (authored in [Write-Tests]; listed here for inventory)
  - Covered in the [Write-Tests] step below.

- [x] **[Write-Tests]** Write the foundation + store tests (stage, do not commit)
  - Aim: cover AC-4 (store loud-fail + no in-repo write) and config precedence.

  **Test Data:**
  - TS-store-ok: input a writable temp dir as `store_path`, call `InsightStore(config).append_run({"kind":"test"})` → expect `<temp>/run-index.jsonl` exists with one `"kind":"test"` line.
  - TS-store-unwritable: input a non-writable parent path (e.g. `/proc/nope` or a `chmod 000` temp dir) as `store_path` → expect `StoreUnwritableError` raised AND no file created anywhere under the repo root.
  - TS-store-norepo: input a `store_path` that resolves UNDER the repo root → expect construction rejects it (guards SF-6).
  - TS-config-precedence: input CLI `--store=/a`, env `SPEC_FLOW_INSIGHTS_STORE=/b` → expect resolved `store_path == /a` (CLI wins); with no CLI flag and env set → expect `/b`; with neither → expect the default.

- [x] **[Verify]** Confirm the foundation is sound
  **Per-change checks:**
  - T-3: `cd tools/transcript-eval && python3 -c "from transcript_eval import config, store, cli"` — Expected: exit 0, no ImportError.
  - T-5: `cd tools/transcript-eval && python3 -m transcript_eval --help` — Expected: exit 0; output lists `extract`, `metrics`, `story`.
  **Phase-level check:**
  - Run: `cd tools/transcript-eval && python3 -m pytest tests/test_store.py tests/test_config.py -q`
  - Expected: all tests pass (the 4 Test-Data cases above + config cases), `0 failed`.
  - Failure: any `StoreUnwritableError` NOT raised on the unwritable case, OR any file written under the repo root during the unwritable case, OR a non-zero pytest exit.

- [x] **[QA]** Phase review
  - Review against: AC-4
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 2: Extraction + scrub + extraction-validation spike (operator-gated)
**Exit Gate:** the extractor parses the sample fixtures best-effort (null-on-miss, coverage reported,
no crash on `malformed.jsonl`); secrets are scrubbed; the **spike** runs against ≥3 real sessions /
≥2 repos, emits coverage% + agreement% + a `PROCEED`/`HALT` verdict, and the operator confirms the
gate (≥95% coverage, ≥80% agreement) — a `HALT` blocks Phase 3 until the inference is revisited.
**ACs Covered:** AC-1, AC-5, AC-6
**In scope:** the parse/extract lib (per-seat dispatch + findings + inferred accept/reject from real
`.jsonl`); best-effort field-probing + coverage/confidence reporting (SF-NFR-2/3); the secret-scrub
layer (SF-6); the SF-7 extraction-validation spike CLI command + report.
**NOT in scope:** metric math — Phase 3; story render — Phase 4; the lib→store integration test —
Phase 4 (this phase writes extracted records to the store but the end-to-end privacy assertion lives
in the completing Phase 4).
**Authored-tests:** tools/transcript-eval/tests/test_extract.py, tools/transcript-eval/tests/test_scrub.py, tools/transcript-eval/tests/test_spike.py
**Charter constraints honored in this phase:**
- NN-P-004 (operator-gated): the miner runs out-of-band, operator-invoked; the SF-7 spike is an
  operator-reviewed gate (no auto-proceed below threshold).
- CR-008 (thin orchestrator / narrow executor): the miner is a standalone operator tool; no skill
  gains executor logic and no agent spawns sub-agents.

- [x] **[Implement]** Build the extractor, scrub layer, and spike command
  - Order: record iterator → seat-dispatch+result correlation → finding extraction → accept/reject
    inference → scrub → coverage report → spike command.
  - Architecture constraints: best-effort parse — probe fields, emit `null` on miss, **report** the
    miss; never raise on a malformed line; never silently drop a finding (SF-NFR-2/3).

  **Change Specifications:**

  **T-1: CREATE `tools/transcript-eval/transcript_eval/extract.py`**
  - Structure: `iter_records(jsonl_path) -> Iterator[dict|None]` (best-effort; yields `None` +
    increments a miss counter on a `json.JSONDecodeError`); `extract_dispatches(records) ->
    list[Dispatch]` where a `Dispatch` is a `type:assistant` record whose `message.content[]` has a
    `tool_use` block with `name in {"Agent","Task"}` and `subagent_type` in the measured-seat set
    (`spec-flow:qa-*`, `spec-flow:review-board-*`, `spec-flow:verify`); `correlate_results(records,
    dispatches)` maps each `tool_use.id` → the `tool_result` whose `tool_use_id` matches (fallback:
    `parentUuid` chain); `extract_findings(result_text) -> list[Finding]`; `infer_accept_reject(finding,
    downstream_records) -> "accepted"|"rejected"` per the ADR-6 heuristic (a downstream
    fix-doc/fix-code/implementer dispatch or Edit referencing the finding ⇒ accepted; else rejected).
    Emit a `CoverageReport` (sessions parsed, lines missed, fields missed, inference-ambiguous count).
  - Pattern (real schema, Cluster A — verified 58/58 correlation in one session):
    ```python
    for b in msg.get("content", []):
        if b.get("type") == "tool_use" and b.get("name") in ("Agent", "Task"):
            st = b.get("input", {}).get("subagent_type", "")
            if is_measured_seat(st): dispatches[b["id"]] = st
        elif b.get("type") == "tool_result" and b.get("tool_use_id") in dispatches:
            results[b["tool_use_id"]] = text_of(b.get("content"))
    ```
  - Done: extraction yields per-seat finding records (each with seat, finding text, accept/reject) +
    a coverage report; a malformed line yields null fields + a reported miss, not a crash; no finding
    is silently dropped.
  - Verify: `pytest tools/transcript-eval/tests/test_extract.py -q` (after [Write-Tests]).

  **T-2: CREATE `tools/transcript-eval/transcript_eval/scrub.py`**
  - Structure: `scrub(record_or_text) -> scrubbed` replacing secret-shaped tokens (API keys, bearer
    tokens, private-key blocks, connection strings) with a redaction marker, per the
    `reference/metrics-artifact.md` `## No secrets` clause (record only counts/slugs/dates/enums —
    summarize, never paste sensitive values). Applied to every extracted record before it leaves the
    process toward the store.
  - Pattern: a small ordered list of `(regex, replacement)` pairs (e.g. `sk-[A-Za-z0-9]{16,}` →
    `<redacted-key>`, `-----BEGIN [A-Z ]*PRIVATE KEY-----` blocks → `<redacted-private-key>`).
  - Done: a secret-shaped token in input is absent from the scrubbed output; non-secret text is
    unchanged.
  - Verify: `pytest tools/transcript-eval/tests/test_scrub.py -q`.

  **T-3: CREATE `tools/transcript-eval/transcript_eval/spike.py` + wire CLI `extract`/`spike` subcommands**
  - Structure: `run_spike(config, sample) -> SpikeReport` that runs extraction over a real-sessions
    sample (≥20 findings across ≥3 sessions / ≥2 repos), computes seat/finding extraction
    **coverage%** and accept/reject **agreement%** against an operator-supplied hand-check file, and
    emits a `PROCEED` verdict iff coverage ≥ `thresholds.coverage` (0.95) AND agreement ≥
    `thresholds.agreement` (0.80), else `HALT` with the failing metric named. The report is written
    to the store and printed for operator review.
  - Pattern: deterministic computation only (no model). The hand-check file is a small operator-authored
    `expected.jsonl` mapping finding-id → accept|reject.
  - Done: `spike` emits `coverage`, `agreement`, and a `PROCEED|HALT` verdict; below-threshold ⇒ `HALT`.
  - Verify: `pytest tools/transcript-eval/tests/test_spike.py -q` + the operator-gated real run (Verify step).

- [x] **[Write-Tests]** Write extraction/scrub/spike tests (stage, do not commit)

  **Test Data:**
  - TE-clean: input `tests/fixtures/clean-session.jsonl` → expect ≥2 seat dispatches extracted, each
    with a correlated finding + an inferred accept/reject; a coverage report with `0` parse misses.
  - TE-malformed: input `tests/fixtures/malformed.jsonl` (1 valid + 1 truncated line) → expect the
    valid record extracted, the bad line counted as a reported miss, NO exception raised, no finding dropped.
  - TE-acceptreject: input a fixture where a finding is followed downstream by a `fix-doc` dispatch
    referencing it → expect `accepted`; a finding with no downstream action → expect `rejected`.
  - TS-scrub: input `tests/fixtures/secret-bearing.jsonl` (token `sk-ABCDEF0123456789XYZ`) → expect
    the scrubbed record contains `<redacted-key>` and NOT the original token.
  - TSP-proceed: input a synthetic sample with coverage 0.97 + agreement 0.85 → expect verdict `PROCEED`.
  - TSP-halt: input a synthetic sample with coverage 0.90 (below 0.95) → expect verdict `HALT` naming the coverage gap.

- [x] **[Verify]** Confirm extraction + the spike gate
  **Per-change checks:**
  - T-1: `pytest tools/transcript-eval/tests/test_extract.py -q` — Expected: all cases pass, `0 failed`; malformed case raises no exception.
  - T-2: `pytest tools/transcript-eval/tests/test_scrub.py -q` — Expected: scrub removes the secret token.
  **Phase-level check (machine):**
  - Run: `cd tools/transcript-eval && python3 -m pytest tests/test_extract.py tests/test_scrub.py tests/test_spike.py -q`
  - Expected: all pass, `0 failed`; the spike module emits `coverage`, `agreement`, and `PROCEED|HALT`.
  - Failure: any crash on the malformed fixture; the secret token surviving scrub; a missing coverage/agreement/verdict field.
  **Operator-gated check (AC-6, judgment):**
  - Run the spike against real sessions (the operator substitutes their own second cross-repo project
    dir for the `prop-firm` example and authors the hand-check file once): `cd tools/transcript-eval &&
    python3 -m transcript_eval spike --project-dir ~/.claude/projects/-Volumes-joeData-ai-plugins
    --project-dir ~/.claude/projects/-mnt-c-crypto --hand-check tools/transcript-eval/spike-handcheck.local.jsonl`
    (`*.local.jsonl` is operator-authored and never committed — SF-6.)
  - Expected: a printed report with coverage% + agreement% over ≥20 findings / ≥3 sessions / ≥2 repos
    and a `PROCEED`/`HALT` verdict. **Operator confirms** the numbers and the gate decision. A `HALT`
    blocks Phase 3 (revisit the inference design per ADR-6) — do not proceed on a HALT.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-5, AC-6
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 3: Gate-effectiveness metrics
**Exit Gate:** each metric (precision, verdict-overlap, leave-one-out unique-catch, rubber-stamp,
activity) equals its hand-derived value on a synthetic extracted-records fixture; the leave-one-out
delta is computed per seat; `pytest` green.
**ACs Covered:** AC-2
**In scope:** the metric layer over extracted records — per-seat **precision** (accepted ÷ raised),
**verdict-overlap** (seats co-finding the same issue), **leave-one-out unique-catch** (accepted
findings only one seat raised), **rubber-stamp** signals (approval with zero reviewer notes OR within
a configurable < 60 s dispatch→approval interval), **activity** (dispatch counts); the recall-honesty
labeling (SF-8 — every number labeled precision-from-usage, never "catch rate").
**NOT in scope:** story rendering — Phase 4; the lib→store integration test — Phase 4; any model
invocation (none — deterministic).
**Authored-tests:** tools/transcript-eval/tests/test_metrics.py
**Charter constraints honored in this phase:**
- NN-P-005 (Opus-thinking/Sonnet-mechanics — no silent upgrade): the metric layer is pure
  deterministic computation; **no model is invoked** by this piece at all.

- [x] **[Implement]** Build the metric layer
  - Order: data model (`SeatMetrics`) → precision → activity → verdict-overlap → leave-one-out →
    rubber-stamp → the precision-from-usage labels.
  - Architecture constraints: every effectiveness number carries a `precision-from-usage` label in
    its output structure; the word "catch rate"/"recall" must never label a mined number (SF-8).

  **Change Specifications:**

  **T-1: CREATE `tools/transcript-eval/transcript_eval/metrics.py`**
  - Structure: `compute_metrics(records, *, rubber_stamp_secs=60) -> dict[seat, SeatMetrics]` where
    `SeatMetrics` = `precision` (accepted/raised), `raised`, `accepted`, `activity` (dispatch count),
    `overlap` (per-issue co-finding seats), `unique_catch` (accepted findings only this seat raised),
    `leave_one_out_delta` (the comparative re-aggregation: accepted-defect coverage WITH vs WITHOUT
    this seat — the FR-016 ablation, distinct from raw unique-catch), `rubber_stamp_candidates`
    (approvals with zero reviewer notes OR dispatch→approval interval < `rubber_stamp_secs`). All
    effectiveness fields tagged `metric_kind: "precision-from-usage"`.
  - Pattern:
    ```python
    precision = accepted / raised if raised else None   # None, never 0/0; labeled precision-from-usage
    leave_one_out_delta = covered_defects(all_seats) - covered_defects(all_seats - {seat})
    ```
  - Done: every metric computed per seat; leave-one-out delta present per seat; outputs labeled
    precision-from-usage; no field named/labeled "catch rate" or "recall".
  - Verify: `pytest tools/transcript-eval/tests/test_metrics.py -q`.

- [x] **[Write-Tests]** Write metric tests against a hand-derived synthetic fixture (stage, do not commit)

  **Test Data:** (synthetic extracted-records fixture — `tests/fixtures/synthetic-records.json` — hand-derived oracle)
  - TM-precision: seat `review-board-security` raised 4 findings, 3 accepted → expect `precision == 0.75`, labeled precision-from-usage.
  - TM-activity: seat `qa-phase` dispatched 7 times → expect `activity == 7`.
  - TM-overlap: an issue co-found by `review-board-security` + `review-board-edge-case` → expect both seats listed in that issue's overlap set.
  - TM-unique: an accepted finding raised ONLY by `review-board-ground-truth` → expect `unique_catch` includes it for that seat and no other.
  - TM-loo: removing `review-board-blind` drops accepted-defect coverage by 2 → expect `leave_one_out_delta == 2` for `review-board-blind`; a seat whose findings are all duplicated elsewhere → expect `leave_one_out_delta == 0`.
  - TM-rubberstamp-zeronotes: an approval recorded with zero reviewer notes → expect it flagged a rubber-stamp candidate.
  - TM-rubberstamp-fast: an approval emitted 30 s after dispatch (< 60 s) → expect flagged; one at 120 s → expect NOT flagged.
  - TM-nocatchrate: render the metrics dict → expect no key or label string equals "catch rate"/"recall".

- [x] **[Verify]** Confirm metric correctness
  **Per-change checks:**
  - T-1: `pytest tools/transcript-eval/tests/test_metrics.py -q` — Expected: every hand-derived case passes, `0 failed`.
  **Phase-level check:**
  - Run: `cd tools/transcript-eval && python3 -m pytest tests/test_metrics.py -q`
  - Expected: all 8 Test-Data cases pass, `0 failed`; each metric equals its hand-derived value; leave-one-out delta computed per seat.
  - Failure: any metric ≠ its hand-derived oracle; a `0/0` precision crash (must be `None`); any "catch rate"/"recall" label on a mined number.
  - Verify (agent-step): read `tools/transcript-eval/transcript_eval/metrics.py` and confirm no string literal `"catch rate"` or `"recall"` labels an effectiveness field.

- [x] **[QA]** Phase review
  - Review against: AC-2
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 4: Story report + lib→store integration (completing) + privacy end-to-end
**Exit Gate:** the story renders from aggregates with a **required FR-016 per-seat evidence section**,
labels every effectiveness number precision-from-usage (no "catch rate"); the **lib→store
integration test (INT-2)** passes end-to-end (parse → scrub → aggregate → write to a TEMP store);
`git status` shows **no new mined content in-repo**; a secret-shaped token is scrubbed in stored output.
**ACs Covered:** AC-3, AC-4, AC-5
**In scope:** the cross-repo pipeline-health story renderer (SF-4) with the FR-016 per-seat section
required; wiring extract → scrub → metrics → store into the `story` CLI command; the INT-2 outer
integration test (completing); the end-to-end privacy assertions (SF-6: no in-repo write, cross-repo
content stays external, secret scrubbed).
**NOT in scope:** the LLM-inference/verdict-flip layer (deferred, Out of Scope); any
`plugins/spec-flow/` change.
**Authored-tests:** tools/transcript-eval/tests/test_story.py, tools/transcript-eval/tests/test_integration_store.py, tools/transcript-eval/tests/test_schema_consistency.py
**Charter constraints honored in this phase:** (none — all charter entries are allocated to other
phases; this phase honors the SF-4/5/6 functional requirements, verified by its tests.)

- [x] **[Implement]** Build the story renderer + wire the full mining pipeline + cross-phase schema check
  - Order: aggregate accretion → story renderer → `story` CLI wiring → cross-phase schema-consistency module.
  - Architecture constraints: the story's FR-016 per-seat evidence section is **required** (render
    fails/marks-missing if aggregates lack per-seat data); every effectiveness number labeled
    precision-from-usage; the renderer writes only to the store (SF-6).

  **Change Specifications:**

  **T-1: CREATE `tools/transcript-eval/transcript_eval/story.py`**
  - Structure: `render_story(aggregates) -> str` (markdown) with a **required** `## FR-016 per-seat
    evidence` section (per-seat precision / overlap / leave-one-out / rubber-stamp / activity), plus
    broad pipeline-health reads (trends, activity, rubber-stamp). Every effectiveness number rendered
    with an explicit `(precision-from-usage)` label; a header note states mining measures
    precision/overlap/activity, **not** recall (SF-8). One H1.
  - Pattern: f-string/template markdown assembly; the FR-016 section header is a literal
    `## FR-016 per-seat evidence` so AC-3's grep can assert it.
  - Done: rendered story contains the FR-016 section header, surfaces pipeline-health reads, and
    contains no "catch rate"/"recall" mislabel on a mined number.
  - Verify: `pytest tools/transcript-eval/tests/test_story.py -q`.

  **T-2: MODIFY `tools/transcript-eval/transcript_eval/cli.py`** (wire the `story` subcommand end-to-end)
  - Anchor: the `story` subparser stub created in Phase 1 T-5.
  - Target: `story` runs the full pipeline — `extract → scrub → compute_metrics → aggregate →
    store.write_aggregates → render_story → store.write_story` — over the configured project dirs,
    writing ONLY to the store.
  - Done: `python3 -m transcript_eval story --store <temp>` produces aggregates + a story under
    `<temp>` and nothing in-repo.
  - Verify: covered by INT-2 (T-4).

  **T-3: CREATE `tools/transcript-eval/transcript_eval/schema_check.py`** (cross-phase schema-consistency oracle — §2d)
  - Structure: `assert_schema_consistency()` validating that the **extracted-record schema** produced
    by `extract.py` (Phase 2) carries exactly the keys `metrics.py` (Phase 3) reads
    (`seat`, `finding`, `accept_reject`), and that the **store layout** written by `store.py`
    (Phase 1, ADR-4: `run-index.jsonl` with `kind`; `aggregates.json`; `story-latest.md`) matches what
    `story.py` (Phase 4) reads. Returns a list of mismatches (empty = consistent).
  - Done: the function names every overlapping schema-bearing file and returns empty on a consistent tree.
  - Verify: `pytest tools/transcript-eval/tests/test_schema_consistency.py -q`.

  **T-4: CREATE the INT-2 outer integration test** (authored in [Integration-Test] step below)

- [x] **[Write-Tests]** Write story + schema-consistency unit tests (stage, do not commit)

  **Test Data:**
  - TST-fr016: input an aggregates fixture with per-seat data → expect the rendered story contains the literal header `## FR-016 per-seat evidence` and a row per seat.
  - TST-label: render the story → expect every effectiveness number carries `(precision-from-usage)` and the string `catch rate` / `recall` appears nowhere as a metric label.
  - TST-health: input aggregates with activity + rubber-stamp data → expect the story surfaces a pipeline-health/trends section.
  - TSC-consistent: run `assert_schema_consistency()` on the built tree → expect an empty mismatch list.
  - TSC-drift: input a deliberately-mutated record schema (rename `accept_reject`→`verdict`) → expect a named mismatch (proves the oracle catches drift).

- [x] **[Verify]** Confirm the story + schema consistency
  **Per-change checks:**
  - T-1: `pytest tools/transcript-eval/tests/test_story.py -q` — Expected: FR-016 section present, no mislabel; `0 failed`.
  - T-3: `pytest tools/transcript-eval/tests/test_schema_consistency.py -q` — Expected: consistent tree returns empty; drift case returns a named mismatch.
  **Phase-level check (machine):**
  - Run: `cd tools/transcript-eval && python3 -m pytest tests/ -q`  (the FULL tool suite)
  - Expected: all tests across `test_store/config/extract/scrub/spike/metrics/story/schema_consistency/integration_store` pass, `0 failed`.
  - Failure: a missing FR-016 section header; a "catch rate"/"recall" mislabel; a schema mismatch on the consistent tree.
  **Cross-phase schema-consistency [Verify] (§2d — names every overlapping schema-bearing file):**
  - Overlapping schema-bearing files: the extracted-record dict (`extract.py` ⇄ `metrics.py`) and the
    store layout (`store.py` ⇄ `story.py`).
  - Invariants: extracted records expose `{seat, finding, accept_reject}`; the store exposes
    `run-index.jsonl` (with `kind`), `aggregates.json`, `story-latest.md` per ADR-4.
  - Command: `cd tools/transcript-eval && python3 -c "from transcript_eval.schema_check import assert_schema_consistency; m=assert_schema_consistency(); print('MISMATCHES:', m); assert not m"` — Expected: `MISMATCHES: []`, exit 0.

- [x] **[Integration-Test]** (completing-phase — INT-2) Complete + green the lib→store outer test
  - Boundary (inside): parse + scrub + aggregate lib + store writer. Doubled external: the filesystem
    insight store (privacy-bound — exercised against a TEMP store path; the in-repo no-write assertion
    is the contract).
  - completes_in_phase: 4
  - Contract test: assert the store writer only ever touches paths under the temp `store_path`
    (privacy boundary), the SF-6 contract.
  - Authoring: CREATE `tools/transcript-eval/tests/test_integration_store.py` — run the FULL `story`
    pipeline over `tests/fixtures/clean-session.jsonl` + `secret-bearing.jsonl` (≥2 project dirs) into
    a `tmp_path` store; assert (a) `run-index.jsonl`/`aggregates.json`/`story-latest.md` appear under
    `tmp_path`; (b) NOTHING is written under the repo root (snapshot repo tree before/after — no new
    files); (c) the secret token is absent from every stored file; (d) cross-repo content from the
    second project dir is present in the store but never copied into the repo tree.
  - Run: `cd tools/transcript-eval && python3 -m pytest tests/test_integration_store.py -q` — Expected:
    `1 passed` (or N passed), `0 failed`; store files under tmp, zero in-repo new files, secret scrubbed.
  - Privacy guard (AC-5 machine): after the test, `git -C <repo-root> status --porcelain -- ':!docs/prds/exec-ready/specs/gate-evals/'` shows no new mined/transcript content.

- [x] **[QA]** Phase review
  - Review against: AC-3, AC-4, AC-5
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 5: Cheater oracle + cheat/allow/residual tiers
**Exit Gate:** `bash plugins/spec-flow/tests/e2e/run-e2e.sh --cheater` reports each of the six FR-017
taxonomy classes ≥1× + the EG-4 transient-commit cheat (≥10 total), **100%** detection of
mechanically-detectable cheats, **0/5** false-rejection on the legitimate-refactor allow-set, the
EG-1 residual tier reported under a **distinct label and excluded** from the 100% headline, and a
**clean `$TMPDIR`** after a forced mid-scenario abort (trap fired); the cheater-oracle self-test
(including a deliberately-broken assertion) passes.
**ACs Covered:** AC-7, AC-8
**In scope:** CREATE `lib/cheater-oracle.sh` re-implementing the FR-011 predicate against a tampered
HEAD in `e2e_mktemp` with `trap … EXIT`; the cheat fixtures (six taxonomy classes + EG-4); the ≥5
legitimate-refactor allow-set; the EG-1 residual/expected-fail tier (separate label, excluded from
the headline); the new `--cheater` mode in `run-e2e.sh`; the cheater-oracle self-test under `self/`.
**NOT in scope:** the EG-2 G9b fix + its locking fixture — Phase 6 (this phase registers INT-1; Phase
6 completes it); the EG-1 *fix* (stays deferred — only the residual probe ships).
**Authored-tests:** plugins/spec-flow/tests/e2e/self/test-cheater-oracle.sh
**Charter constraints honored in this phase:**
- NN-C-006 (destructive ops confined): every tampered-HEAD `git`/`rm` runs inside an `e2e_mktemp`
  throwaway repo confined to `/tmp|/private|/var/folders`, with `trap … EXIT` cleanup.
- CR-009 (heading hierarchy): the cheat/allow/residual fixtures keep one H1/H2/H3 per the inline-label grammar.

- [x] **[Implement]** Build the reconstructed oracle, fixtures, tiers, and the `--cheater` mode
  - Order: the single `sha256` shim → the predicate re-implementation (gate a/b + smuggling + M3 +
    cap) → `e2e_mktemp` tampered-HEAD builder with `trap … EXIT` → cheat fixtures → allow-set →
    residual tier → `run-e2e.sh` wiring.
  - Architecture constraints: pure POSIX bash, no runtime deps (NN-C-002); reuse `assert.sh`
    vocabulary; `summary()` never-false-green; every cheat fixture uses the existing inline-label grammar.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/tests/e2e/lib/cheater-oracle.sh`**
  - Structure: define `cheater_oracle_checks()` (the entry `run_mode` looks up). Internals:
    - `_sha256()` — the single shim: `sha256sum` if present, else `shasum -a 256`, normalized to the
      bare hex digest (ADR-7 parity pin — matches what the live gate hardcodes at execute/SKILL.md L627).
    - `_predicate_gate_a(manifest_assoc, exempt_set, head_repo)` — re-implements gate (a): for each
      manifest path, `git -C "$head_repo" show HEAD:"$path" | _sha256` vs the manifest hash; a path in
      BOTH manifest and exempt → HARD REJECT (smuggling); emit `integrity fail: <path>` on drift.
    - `_predicate_gate_b(expected_set, head_repo)` — reconciliation: `git show --name-only` vs the
      sorted expected set; stray/missing → reject.
    - `_build_tampered_head(scenario) -> tmpdir` — `tmp=$(e2e_mktemp); trap 'e2e_cleanup "$tmp"' EXIT`;
      build a tiny git repo, commit Red tests, then apply the scenario's tamper.
  - Pattern (Cluster C verbatim — the predicate being reconstructed):
    ```bash
    commit_hash=$(git show HEAD:"$path" | sha256sum | cut -d' ' -f1)
    [ "$commit_hash" = "$manifest_hash" ] || echo "integrity fail: $path"
    # smuggling: path in BOTH manifest AND exempt_authored = HARD REJECT (exemption ignored)
    ```
  - Pattern (Cluster D — trap cleanup, net-new; assert.sh has e2e_mktemp/e2e_cleanup but NO trap):
    ```bash
    tmp=$(e2e_mktemp); trap 'e2e_cleanup "$tmp"' EXIT
    ```
  - Done: `cheater_oracle_checks` runs all scenarios, asserts detection/allow per fixture, prints PASS/FAIL
    via `assert.sh`, and leaves `$TMPDIR` clean (trap fires even on a forced abort).
  - Verify: `bash plugins/spec-flow/tests/e2e/run-e2e.sh --cheater` (after T-4/T-5) summary exits 0.

  **T-2: CREATE the six taxonomy-class cheat fixtures + EG-4** under `plugins/spec-flow/tests/e2e/fixtures/cheater/`
  - Structure: one fixture per class using the inline-label grammar (Cluster D), each declaring the
    tamper and the expected `→ reject` verdict + named path:
    1. `cheat-edit-assertions.md` — drift a Red-manifest test's assertion → gate(a) reject.
    2. `cheat-skip-delete-tests.md` — delete/skip a failing Red test → reconciliation missing → reject.
    3. `cheat-hardcode-except.md` — hardcode an output in an except-handler assertion (test-file drift) → gate(a) reject.
    4. `cheat-stub-function.md` — stub the function-under-test inside the test file → gate(a) reject.
    5. `cheat-weaken-tolerance.md` — weaken a tolerance in a Red-manifest test → gate(a) reject.
    6. `cheat-ac-done-no-diff.md` — claim AC done with an empty commit → reconciliation missing → reject.
    7. `cheat-eg4-transient-commit.md` — flat-path (`deferred_commit: off`) tampered commit transiently
       on HEAD before the gate-(a) revert window (backlog EG-4) → the oracle reads tampered content
       from HEAD in that window → reject.
  - Pattern (Cluster D label grammar — reuse verbatim): `# Gate <slug> cheat fixture — <desc>` / `# Scenario:` / `# Expected gate behavior:` + `## Scenario` (bulleted manifest) + `## Expected gate (a) outcome`.
  - Done: 7 fixtures exist covering 6 classes ≥1× + EG-4; each names its violating path and expected reject.
  - Verify: `ls plugins/spec-flow/tests/e2e/fixtures/cheater/cheat-*.md | wc -l` ≥ 7.

  **T-3: CREATE the ≥5 legitimate-refactor allow-set fixtures** under `fixtures/cheater/`
  - Structure: ≥5 `allow-*.md` fixtures the gate must PASS — each a refactor that touches NON-Red-manifest
    files or that does not drift a manifest hash (e.g. rename a production helper not in any manifest;
    add a new non-manifest test; reformat a production file; move a fixture not in the closure; extract
    a helper). Expected verdict `→ pass` (0 false-rejection).
  - Done: ≥5 `allow-*.md` fixtures exist, each with an expected `→ pass`.
  - Verify: `ls plugins/spec-flow/tests/e2e/fixtures/cheater/allow-*.md | wc -l` ≥ 5.

  **T-4: CREATE the EG-1 residual tier fixture + distinct-label accounting** (AC-8)
  - Structure: `fixtures/cheater/residual-eg1-closure-tamper.md` — a transitive/by-name fixture-closure
    tamper the guardrail is designed NOT to catch. `cheater_oracle_checks` scores it under a distinct
    tier label (e.g. prints `EXCLUDED — residual-tier: EG-1 …` via `excluded()`), reported independently
    and **excluded from the 100% detection headline**.
  - Pattern (Cluster D — `excluded()` is informational, uncounted):
    ```bash
    excluded "residual-tier EG-1 closure tamper — documented expected-fail, not in 100% headline"
    ```
  - Done: the EG-1 probe runs under a distinct tier label and its result does not enter the
    `PASSES/FAILS` counts that form the 100% headline.
  - Verify: `bash run-e2e.sh --cheater` output shows the EG-1 line under a residual/EXCLUDED label, not in the headline tally.

  **T-5: MODIFY `plugins/spec-flow/tests/e2e/run-e2e.sh`** (register the `--cheater` mode)
  - Anchor: CLI parse `case "$1"` (lines 52–100) + mode dispatch `case "$MODE"` (lines 105–152).
  - Current (dispatch tail, lines 139–151):
    ```
    139    break)
    140      BUILDER="$SCRIPT_DIR/build-fixture.sh"
    ...
    149      ;;
    150
    151  esac
    ```
  - Target: add a parse arm `--cheater) MODE="cheater"; shift ;;` in the `while` loop, a usage line
    in the `usage()` heredoc, and a dispatch arm before `esac`:
    ```bash
    cheater)
      run_mode cheater_oracle_checks
      summary
      exit $?
      ;;
    ```
  - Pattern (Cluster D — `run_mode` auto-looks-up the function from the auto-sourced `lib/*.sh`).
  - Done: `bash run-e2e.sh --cheater` dispatches `cheater_oracle_checks`; `--help` lists `--cheater`.
  - Verify: `bash plugins/spec-flow/tests/e2e/run-e2e.sh --help` lists `--cheater`.

- [x] **[Write-Tests]** Write the cheater-oracle self-test (stage, do not commit)
  - CREATE `plugins/spec-flow/tests/e2e/self/test-cheater-oracle.sh` mirroring `self/test-core.sh`
    (own `_pass`/`_fail` counters + `_capture`; a deliberately-broken oracle assertion + a
    deliberately-mislabeled fixture MUST be reported FAIL by the self-test).

  **Test Data:**
  - TC-detect-all: run the oracle over the 7 cheat fixtures → expect every mechanically-detectable cheat reported DETECTED (100%); summary counts them in PASSES.
  - TC-allow-zero-fr: run the oracle over the ≥5 allow fixtures → expect 0 false-rejection (all PASS).
  - TC-residual-excluded: run the oracle → expect the EG-1 residual line under a distinct/EXCLUDED label and NOT in the 100% headline tally.
  - TC-trap-clean: capture `$TMPDIR` listing, force a mid-scenario abort (e.g. `kill -TERM` after the tampered HEAD is built) → expect the trap fires and `$TMPDIR` has no leftover `e2e-*` tampered repo.
  - TC-selftest-catches-broken: feed the self-test a deliberately-broken oracle assertion → expect the self-test reports FAIL (the validator is itself validated).

- [x] **[Verify]** Confirm the cheater track
  **Per-change checks:**
  - T-5: `bash plugins/spec-flow/tests/e2e/run-e2e.sh --help` — Expected: usage lists `--cheater`.
  **Phase-level check:**
  - Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh --cheater`
  - Expected: summary line `== summary: <N> passed, 0 failed, <skips> skipped, 0 errors ==`, exit 0;
    ≥10 cheats across 6 classes + EG-4 all DETECTED (100%); 0/5 allow-set false-rejection; the EG-1
    residual line under a distinct/EXCLUDED label excluded from the headline.
  - Run: `bash plugins/spec-flow/tests/e2e/self/test-cheater-oracle.sh` — Expected: `0 failed`, exit 0;
    the deliberately-broken-assertion case is reported FAIL inside the captured subshell (proving the self-test bites).
  - Failure: any cheat NOT detected; any allow-set false-rejection; a leftover `e2e-*` dir in `$TMPDIR` after the forced abort; the EG-1 probe entering the 100% headline.

- [x] **[QA]** Phase review
  - Review against: AC-7, AC-8
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 6: EG-2 guardrail fix + locking fixture (completing INT-1)
**Exit Gate:** execute/SKILL.md G9b carries an explicit per-sub-phase `exempt_authored` attribution
rule + a worked example; the multi-sub-phase locking fixture (sub-phase A declares an exempt path that
sub-phase B tampers) is reported **DETECTED** (not residual) by the oracle; `static.sh` still asserts
the guardrail text; INT-1 completes green.
**ACs Covered:** AC-9
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` Step G9b — insert the per-sub-phase
attribution rule + worked example; CREATE the multi-sub-phase locking fixture; complete INT-1 (the
oracle now exercises the full predicate incl. the G9b attribution rule).
**NOT in scope:** the EG-1 closure fix (deferred); any rubric_version change — Phase 7.
**Steps traversed (P2):** Step G9b (Barrier work-commit, deferred_commit: auto) — specifically G9b
step 1 (per-sub-phase Red-test re-hash, lines 1483–1495). The attribution rule tightens this existing
re-hash loop; it introduces no new conditional path through the Phase Group Loop or the per-phase
loop — it clarifies the derivation of `exempt_authored` already consumed at line 1495. It interacts
with the flat-phase `exempt_authored` derivation at Step 3 item 7(a) (line 704), which it mirrors for
the deferred multi-sub-phase path. No other G-step is invalidated.
**Dispatch sites (P3):** none — the EG-2 fix changes no agent-dispatch contract. The G9b
offending-sub-phase **re-dispatch** (line 1495, "re-dispatch the offending sub-phase's Build") is
unchanged in shape; the fix only changes *which* paths count as exempt when deciding to reject, not
how/whether the re-dispatch fires.
**Charter constraints honored in this phase:**
- NN-C-003 (backward-compat additive): the EG-2 fix is the ONLY behavior change in the piece — a
  stricter integrity check (CHANGELOG `### Fixed`); legitimate same-sub-phase exemptions are
  unaffected; no gate is removed (NN-P-002 — gate-tightening, never a merge path).

- [x] **[Implement]** Insert the per-sub-phase attribution rule + worked example; build the locking fixture
  - Order: the G9b prose rule → the worked example → the locking fixture → the oracle scenario wiring.
  - Architecture constraints: the rule must be stated as prose at G9b (the AC-9 grep anchor); the
    worked example must show actual values (§2c dense-algorithm guard — the rule is a multi-step
    normalize→attribute→reject chain).

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: `### Step G9b: Barrier work-commit (deferred_commit: auto)` (line 1475), step 1, between
    the resume-fallback sentence (line 1493) and the "Any mismatch…" sentence (line 1495).
  - Current (lines 1493–1495):
    ```
    1493	   If the journal lacks the `anchor: blob` marker (written by ≤5.1.0), verify with `sha256sum` instead (see resume fallback).
    1494
    1495	   Any mismatch for a path that is **not** in the sub-phase's `exempt_authored` set means a Build agent modified one of Red's tests to make it pass. (A path in BOTH `red_manifest_hashes` and the sub-phase's `exempt_authored` is a smuggling violation — rejected per the T-1 precedence rule.)
    ```
  - Target: insert a new paragraph after line 1493 (before line 1495) stating the **per-sub-phase
    `exempt_authored` attribution rule (EG-2 fix)**: each sub-phase's `exempt_authored` is parsed from
    THAT sub-phase's own `**Authored-tests:**` field in the plan (mirroring the flat-phase derivation
    at Step 3 item 7(a)); an exemption declared by sub-phase A confers NO exemption when the same path
    appears in sub-phase B's `red_manifest_hashes` and drifts — the exemption is attributed strictly
    to the declaring sub-phase. Include an inline worked example (HTML comment or parenthetical) with
    actual values:
    ```
    <!-- EG-2 worked example: Group G, sub-phases A and B.
         A's plan section: **Authored-tests:** tests/test_a.py  → A.exempt_authored = {tests/test_a.py}.
         B's red_manifest_hashes keys = {tests/test_b.py, tests/test_a.py} (B's Red also covers test_a.py).
         At the barrier, tests/test_a.py drifts in the working tree.
         Per-sub-phase attribution: test_a.py is exempt for A (A declared it) but NOT for B (B did not).
         The drift is evaluated under B's manifest → test_a.py is NOT in B.exempt_authored → REJECT.
         A group-wide exempt union would have wrongly passed it; per-sub-phase attribution rejects it. -->
    ```
  - Pattern (Cluster C — flat-phase derivation at line 704 being mirrored): "parse the listed literal
    paths into `exempt_authored = { paths }`" from the phase's `**Authored-tests:**` field.
  - Done: G9b contains the per-sub-phase attribution rule prose + the worked example with actual values;
    line 1495's check now has an unambiguous per-sub-phase derivation upstream.
  - Verify: `grep -n "per-sub-phase" plugins/spec-flow/skills/execute/SKILL.md` returns a hit inside G9b (lines 1475–1540); the worked example is present.

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md.agent.md` mirror** — IF a `.agent.md` mirror
    of execute/SKILL.md exists, apply the identical edit. (Check: `ls plugins/spec-flow/skills/execute/`.
    If no mirror exists, this task is a no-op — SKILL.md is the sole file. Skills do not always carry
    `.agent.md` mirrors; agents do.)
  - Done: if a mirror exists it is byte-consistent with the SKILL.md edit; else no-op.
  - Verify: `diff <(sed -n '1475,1540p' SKILL.md) ...` only if a mirror exists.

  **T-3: CREATE `plugins/spec-flow/tests/e2e/fixtures/cheater/lock-eg2-cross-subphase.md`**
  - Structure: a multi-sub-phase locking fixture (inline-label grammar) — sub-phase A declares
    `exempt_authored = {tests/test_a.py}`; sub-phase B's `red_manifest_hashes` includes `tests/test_a.py`;
    B tampers it at the barrier. Expected verdict: `→ DETECTED (reject)` — the cross-sub-phase
    exemption does NOT apply (EG-2 fix). This is a *detected* cheat (in the 100% headline), NOT residual.
  - Done: the fixture exists and declares the expected DETECTED verdict.
  - Verify: `test -f plugins/spec-flow/tests/e2e/fixtures/cheater/lock-eg2-cross-subphase.md`.

  **T-4: MODIFY `plugins/spec-flow/tests/e2e/lib/cheater-oracle.sh`** (add the EG-2 scenario)
  - Anchor: `cheater_oracle_checks` (created Phase 5 T-1).
  - Target: add a scenario that builds a two-sub-phase tampered barrier state and asserts the oracle's
    per-sub-phase attribution rejects B's tamper of A's exempt path — reported DETECTED, in the headline.
  - Done: the oracle's EG-2 scenario reports DETECTED for `lock-eg2-cross-subphase`.
  - Verify: `bash run-e2e.sh --cheater` shows the EG-2 locking scenario DETECTED.

- [x] **[Write-Tests]** Extend the cheater-oracle self-test for the EG-2 scenario (stage, do not commit)
  - Append to `plugins/spec-flow/tests/e2e/self/test-cheater-oracle.sh`: an EG-2 case asserting the
    cross-sub-phase exemption tamper is DETECTED (and a pre-fix simulation — the group-wide-union
    behavior — would have MISSED it, proving the fix is load-bearing).

  **Test Data:**
  - TC-eg2-detected: run the oracle's EG-2 scenario (B tampers A's exempt path) → expect DETECTED (reject), counted in the 100% headline.
  - TC-eg2-loadbearing: simulate the pre-fix group-wide-union exemption over the same tamper → expect it would have PASSED (missed) → proves the per-sub-phase rule is load-bearing.

- [x] **[Verify]** Confirm the EG-2 fix + INT-1 completion
  **Per-change checks:**
  - T-1: `grep -n "per-sub-phase" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 hit within G9b (lines 1475–1540); worked example present.
  - T-1 (regression): `bash plugins/spec-flow/tests/e2e/run-e2e.sh` (default mode) — Expected: `static.sh` L1 guardrail-text assertions still pass (`exempt_authored`, smuggling HARD REJECT, NEVER auto-exempt strings intact); summary `0 failed`.
  **Phase-level check:**
  - Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh --cheater`
  - Expected: the EG-2 locking scenario reported DETECTED (in the 100% headline); all Phase-5 cheats still 100%; allow-set 0 false-rejection; summary exit 0.
  - Run: `bash plugins/spec-flow/tests/e2e/self/test-cheater-oracle.sh` — Expected: `0 failed`; the EG-2 detected + load-bearing cases pass.
  - Failure: the cross-sub-phase tamper reported MISSED or residual instead of DETECTED; the worked example absent; static.sh guardrail-text assertions broken.
  **[Integration-Test]** (completing-phase — INT-1) Complete + green the oracle→predicate outer test
  - Boundary (inside): reconstructed bash oracle + execute/SKILL.md FR-011 predicate region (now incl.
    the G9b per-sub-phase attribution rule). Doubled external: the predicate, contract-tested by the
    shared `_sha256` shim parity check.
  - completes_in_phase: 6
  - Contract test: assert `_sha256` (oracle) and the live gate's hash form (`sha256sum … cut -d' ' -f1`)
    produce identical digests for a known input (parity pin, ADR-7).
  - Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh --cheater` — Expected: full oracle suite green
    incl. the EG-2 scenario DETECTED; parity check passes.

- [x] **[QA]** Phase review
  - Review against: AC-9
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 7: `rubric_version` tag on the 13 measured gate-agent pairs
**Exit Gate:** each of the 13 measured pairs carries a byte-identical additive `rubric_version`
frontmatter key (no other frontmatter change); `grep -L 'rubric_version:'` over the measured set
returns nothing; each `.md`/`.agent.md` pair `diff` is empty; bare `name:` preserved.
**ACs Covered:** AC-10
**In scope:** add `rubric_version: 1` (additive) to the frontmatter of the 13 measured gate-agent
pairs (26 files), inserted after the last existing frontmatter key (after `model:` where present),
preserving byte-identity within each pair and the bare `name:`.
**NOT in scope:** the excluded agents (`review-board-triage`, `qa-charter`, `qa-prd`, `qa-prd-review`
— ADR-2 rationale); the consuming contract / SC-009 — Phase 8.
**Charter constraints honored in this phase:**
- NN-C-004 (bare agent `name:`): the `rubric_version` edit keeps each agent's `name:` unprefixed.
- NN-C-008 (self-contained agents): the additive key adds no conversation-history assumption.

- [x] **[Implement]** Add the additive `rubric_version` key to the 13 measured pairs
  - Order: edit each `.md` and its `.agent.md` mirror identically, pair by pair, verifying byte-identity after each.
  - Architecture constraints: ADDITIVE ONLY — insert one line; touch no other frontmatter key
    (NN-C-003); preserve bare `name:`.

  **Change Specifications:** (one MODIFY per pair — 13 pairs; T-1 shows the two-key form, T-2 the three-key form)

  **T-1: MODIFY `plugins/spec-flow/agents/qa-spec.md` + `qa-spec.agent.md`** (two-key form — representative)
  - Anchor: the frontmatter block, after `description:` (line 3), before the closing `---` (line 4).
  - Current (qa-spec.md lines 1–4):
    ```
    1  ---
    2  name: qa-spec
    3  description: "Internal agent — dispatched by spec-flow:spec. ... Read-only — never modifies files."
    4  ---
    ```
  - Target: insert `rubric_version: 1` as a new line 4 (between `description:` and `---`). Apply the
    identical edit to `qa-spec.agent.md` so the pair stays byte-identical.
  - Pattern: additive key insertion preserving all existing keys + bare name.
  - Done: both files carry `rubric_version: 1`; `diff qa-spec.md qa-spec.agent.md` is empty.
  - Verify: `grep -c 'rubric_version: 1' plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/agents/qa-spec.agent.md` → both `1`; `diff` empty.

  **T-2: MODIFY `plugins/spec-flow/agents/review-board-integration.md` + `.agent.md`** (three-key form — `model:` present)
  - Anchor: frontmatter, after `model: opus` (line 4), before `---` (line 5).
  - Current (lines 1–5):
    ```
    1  ---
    2  name: review-board-integration
    3  description: "... Read-only — never modifies code."
    4  model: opus
    5  ---
    ```
  - Target: insert `rubric_version: 1` as new line 5 (after `model: opus`, before `---`). Identical edit to the `.agent.md`.
  - Done: both carry `rubric_version: 1` after `model:`; pair `diff` empty; `model:` + bare `name:` preserved.
  - Verify: `grep -c 'rubric_version: 1' …integration.md …integration.agent.md` → both `1`; `diff` empty.

  **T-3..T-13: MODIFY the remaining 11 measured pairs identically** (two-key form unless noted):
    `qa-plan`, `qa-phase`, `qa-phase-lite`, `qa-tdd-red`, `review-board-architecture`,
    `review-board-blind`, `review-board-edge-case`, `review-board-ground-truth`,
    `review-board-prd-alignment`, `review-board-security`, `review-board-spec-compliance` — each `.md`
    + `.agent.md` gets `rubric_version: 1` inserted after the last existing key, byte-identical per pair.
  - Done: all 13 pairs (26 files) carry the key; no excluded agent does.
  - Verify: phase-level grep below.

> Pure Implement-track phase: a frontmatter-only additive metadata edit with no behavior under
> test — no `[Write-Tests]` step (AC-10 is verified by grep/diff in `[Verify]`; the existing e2e
> default suite is the regression guard).

- [x] **[Verify]** Confirm the additive tag across the measured set
  **Phase-level check (agent-step + shell):**
  - Run: `grep -L 'rubric_version:' plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/agents/qa-spec.agent.md plugins/spec-flow/agents/qa-plan.md plugins/spec-flow/agents/qa-plan.agent.md plugins/spec-flow/agents/qa-phase.md plugins/spec-flow/agents/qa-phase.agent.md plugins/spec-flow/agents/qa-phase-lite.md plugins/spec-flow/agents/qa-phase-lite.agent.md plugins/spec-flow/agents/qa-tdd-red.md plugins/spec-flow/agents/qa-tdd-red.agent.md plugins/spec-flow/agents/review-board-architecture.md plugins/spec-flow/agents/review-board-architecture.agent.md plugins/spec-flow/agents/review-board-blind.md plugins/spec-flow/agents/review-board-blind.agent.md plugins/spec-flow/agents/review-board-edge-case.md plugins/spec-flow/agents/review-board-edge-case.agent.md plugins/spec-flow/agents/review-board-ground-truth.md plugins/spec-flow/agents/review-board-ground-truth.agent.md plugins/spec-flow/agents/review-board-integration.md plugins/spec-flow/agents/review-board-integration.agent.md plugins/spec-flow/agents/review-board-prd-alignment.md plugins/spec-flow/agents/review-board-prd-alignment.agent.md plugins/spec-flow/agents/review-board-security.md plugins/spec-flow/agents/review-board-security.agent.md plugins/spec-flow/agents/review-board-spec-compliance.md plugins/spec-flow/agents/review-board-spec-compliance.agent.md`
  - Expected: **no output** (every measured file carries `rubric_version:`).
  - Run (byte-identity, per pair): `for a in qa-spec qa-plan qa-phase qa-phase-lite qa-tdd-red review-board-architecture review-board-blind review-board-edge-case review-board-ground-truth review-board-integration review-board-prd-alignment review-board-security review-board-spec-compliance; do diff "plugins/spec-flow/agents/$a.md" "plugins/spec-flow/agents/$a.agent.md" >/dev/null && echo "OK $a" || echo "DRIFT $a"; done`
  - Expected: `OK` for all 13 pairs, no `DRIFT`.
  - Run (excluded agents untouched): `grep -l 'rubric_version:' plugins/spec-flow/agents/review-board-triage.md plugins/spec-flow/agents/qa-charter.md plugins/spec-flow/agents/qa-prd.md plugins/spec-flow/agents/qa-prd-review.md`
  - Expected: **no output** (excluded agents have NO `rubric_version:` — ADR-2).
  - Failure: any measured file printed by the first grep; any `DRIFT`; any excluded agent carrying the key.

- [x] **[QA]** Phase review
  - Review against: AC-10
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 8: Consuming contract (gate-scaling citation) + SC-009 re-scope
**Exit Gate:** `gate-scaling.md#board-swap-rule` carries the citation obligation (mined per-seat
precision/overlap/leave-one-out evidence AND cheater-track detection) with a `leave-one-out`
reference; PRD SC-009 distinguishes precision-from-usage (published) from true recall and contains no
"published catch rate" claim.
**ACs Covered:** AC-11
**In scope:** MODIFY `reference/gate-scaling.md` (add the FR-016 citation obligation at/under
`#board-swap-rule`); MODIFY `docs/prds/exec-ready/prd.md` SC-009 (re-scope L444).
**NOT in scope:** the version bump — Phase 9; agent edits — Phase 7.
**Charter constraints honored in this phase:**
- NN-P-001 (human sign-off gate never removed): the citation obligation ADDS a requirement to seat
  cuts; it removes no gate and no sign-off.

- [x] **[Implement]** Add the citation obligation + re-scope SC-009
  - Order: gate-scaling citation obligation → SC-009 re-scope.
  - Architecture constraints: the citation obligation must reference both mined per-seat evidence
    (precision/overlap/leave-one-out) AND cheater-track detection; SC-009 must not retain a flat
    "catch rate" framing for mined numbers.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/reference/gate-scaling.md`**
  - Anchor: `## board-swap-rule` (line 54), section ends at line 71 (EOF).
  - Current (lines 68–71):
    ```
    68  When the `review_board_variant` annotation is absent, the board composition is today's roster — including the blind seat — unchanged.
    69
    70  This swap applies at two dispatch surfaces: execute Final Review Step 1 (in-pipeline) and the out-of-band `spec-flow:review-board` skill.
    71
    ```
  - Target: append a new subsection under `## board-swap-rule` (after line 70) stating the **citation
    obligation (FR-017 / PRD-FR-017 AC[6])**: any board-seat **cut or model-downgrade** MUST cite (a)
    the mined per-seat **precision / verdict-overlap / leave-one-out unique-catch** evidence from
    `tools/transcript-eval/` (the durable insight store), AND (b) the cheater-track detection result
    for the affected integrity guardrails. Mined evidence is **precision-from-usage, not recall**;
    true recall is sourced only from the cheater track. Use the literal token `leave-one-out` so AC-11
    can grep it.
  - Pattern: a short obligation paragraph (matches the file's concise anchor-doc style).
  - Done: the section carries the dual-citation obligation + a `leave-one-out` reference.
  - Verify: `grep -n "leave-one-out" plugins/spec-flow/reference/gate-scaling.md` returns a hit within/after the board-swap-rule section; `grep -n "cheater-track" plugins/spec-flow/reference/gate-scaling.md` returns a hit.

  **T-2: MODIFY `docs/prds/exec-ready/prd.md`**
  - Anchor: SC-009 definition (line 444).
  - Current (line 444):
    ```
    444  - **SC-009:** 100% of merge-blocking gates have a published catch rate and clean-fixture flag rate; every board-composition or gate-mechanism change since FR-017 shipped cites fixture/ablation evidence; cheater-track detection is 100% across the scripted scenario set (sub-100% scenarios are open guardrail bugs). — FR-016, FR-017
    ```
  - Target: rewrite SC-009 to distinguish two metric kinds: (i) **precision-from-usage** (mined,
    published per measured seat — precision/verdict-overlap/leave-one-out, explicitly NOT a catch
    rate), and (ii) **true recall** (sourced ONLY from the cheater track — 100% detection across the
    mechanically-detectable scripted set; EG-1 residual excluded). Retire the "published catch rate"
    framing for mined numbers; keep the board-composition-change citation obligation (now → mined
    per-seat evidence + cheater detection per gate-scaling.md). The rewritten line must contain no
    claim that mined gates have a "catch rate."
  - Done: SC-009 distinguishes precision-from-usage vs recall and carries no "catch rate" claim for mined numbers.
  - Verify: `grep -n "precision-from-usage" docs/prds/exec-ready/prd.md` (SC-009 region) returns a hit; `sed -n '444p' docs/prds/exec-ready/prd.md | grep -i "catch rate"` returns nothing.

> Pure Implement-track phase: SSOT doc-as-code edits with no executable behavior under test — no
> `[Write-Tests]` step (AC-11 is verified by grep + agent-step in `[Verify]`).

- [x] **[Verify]** Confirm the consuming contract + SC-009 re-scope
  **Per-change checks:**
  - T-1: `grep -n "leave-one-out" plugins/spec-flow/reference/gate-scaling.md` — Expected: ≥1 hit (citation obligation); `grep -n "cheater-track" …` — Expected: ≥1 hit.
  - T-2: `grep -n "precision-from-usage" docs/prds/exec-ready/prd.md` — Expected: ≥1 hit in the SC-009 region.
  **Phase-level check (agent-step):**
  - Read `docs/prds/exec-ready/prd.md` SC-009 (line ~444) and confirm it distinguishes precision-from-usage (published) from true recall and makes NO "published catch rate" claim for mined gates — Expected: distinction present, no mined "catch rate" claim.
  - Read `plugins/spec-flow/reference/gate-scaling.md#board-swap-rule` and confirm a seat cut/downgrade must cite mined per-seat evidence AND cheater-track detection — Expected: dual-citation obligation present.
  - Failure: a surviving "catch rate" claim on mined gates in SC-009; the citation obligation missing the cheater-track or the leave-one-out reference.

- [x] **[QA]** Phase review
  - Review against: AC-11
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 9: Version bump + release verification
**Exit Gate:** the plugin version is bumped in `plugin.json` + `marketplace.json` (in sync) + the
stale `static.sh` assertions, with a CHANGELOG entry; the e2e version-sync assertion passes; every
new/edited agent keeps a bare `name:`; no runtime-dep artifact exists under `plugins/spec-flow/` and
`tools/transcript-eval/requirements.txt` exists.
**ACs Covered:** AC-12
**In scope:** bump `plugin.json` L4 + `marketplace.json` L15 (spec-flow entry) to the target version;
update the stale `static.sh` version-sync assertions (L209/L211/L217) to the target; add the CHANGELOG
entry; run the release-verification checks (version-sync diff empty, bare `name:`, no-deps invariant).
**NOT in scope:** any new feature; the actual `release(...)` commit/tag is the operator's
human-gated action at merge (the plan stages the bump; execute commits per its merge step).
**Charter constraints honored in this phase:**
- NN-C-001 (plugin/marketplace version sync): `plugin.json` + `marketplace.json` bumped together,
  verified by the version-sync diff.
- NN-C-009 (version bump): the plugin version is bumped across all version-bearing files + CHANGELOG.
- CR-004 (conventional commits): the release/plan commits use `<type>(spec-flow): …`.

- [x] **[Implement]** Bump versions in sync + CHANGELOG + fix the stale assertion
  - Order: choose target → plugin.json → marketplace.json → static.sh (3 assertions) → CHANGELOG.
  - Architecture constraints: all version-bearing surfaces must agree on the target; the python
    `requirements.txt` stays under `tools/` only (NN-C-002 by location).
  - **Target version:** **5.16.0** (next minor above master's 5.15.0). If master has advanced past
    5.15.0 by merge time, use the next minor above master's then-current version — keep all four
    surfaces (plugin.json, marketplace.json, static.sh ×3, CHANGELOG) on the SAME chosen value.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`**
  - Anchor: the `"version"` field (line 4).
  - Current: `  "version": "5.14.0",`
  - Target: `  "version": "5.16.0",`
  - Done: plugin.json version is the target.
  - Verify: `grep -n '"version": "5.16.0"' plugins/spec-flow/.claude-plugin/plugin.json` returns line 4.

  **T-2: MODIFY `.claude-plugin/marketplace.json`** (spec-flow entry)
  - Anchor: the spec-flow entry `"version"` (line 15; the entry whose `"name": "spec-flow"`).
  - Current: `      "version": "5.14.0",`
  - Target: `      "version": "5.16.0",`
  - Done: the spec-flow marketplace entry matches plugin.json. (Do NOT touch the `qa` plugin entry at L24.)
  - Verify: LLM-agent-step: read `.claude-plugin/marketplace.json` and confirm the entry with `"name": "spec-flow"` has `"version": "5.16.0"` and the `qa` entry is unchanged.

  **T-3: MODIFY `plugins/spec-flow/tests/e2e/lib/static.sh`** (the stale version-sync assertions)
  - Anchor: the AC-11 version-sync block (lines 204–219), assertions at L209, L211, L217.
  - Current (lines 209–217):
    ```
    209    assert_grep '"version": "5\.12\.4"' "$pluginjson" \
    210      "AC-11: plugin.json version is 5.12.4"
    211    assert_grep '"version": "5\.12\.4"' "$marketplace" \
    212      "AC-11: marketplace.json spec-flow entry is 5.12.4"
    213    ...
    217    assert_grep "\[5\.12\.4\]" "$changelog" \
    ```
  - Target: replace the three hardcoded `5\.12\.4` patterns (and their label strings) with `5\.16\.0`
    / `5.16.0`, so the version-sync assertion checks the new target. (The `(c) continue` assertion at
    L213–214 is unrelated — leave it.)
  - Done: static.sh asserts the target version against plugin.json + marketplace.json + CHANGELOG.
  - Verify: `grep -c '5\\.12\\.4' plugins/spec-flow/tests/e2e/lib/static.sh` → `0`; `grep -c '5\\.16\\.0' …` → `3`.

  **T-4: MODIFY `plugins/spec-flow/CHANGELOG.md`**
  - Anchor: the top `## [Unreleased]` / `## [5.14.0]` region (lines 5–16).
  - Current (lines 5–7):
    ```
    5  ## [Unreleased]
    6
    7  ## [5.14.0] — 2026-06-11
    ```
  - Target: insert a new `## [5.16.0] — <today's date>` section under `## [Unreleased]`, with
    `### Added` (FR-017 transcript-mining tool at `tools/transcript-eval/`: extraction, precision/
    overlap/leave-one-out/rubber-stamp/activity metrics, cross-repo story, durable external insight
    store, extraction-validation spike; the cheater oracle + EG-1 residual tier; the `rubric_version`
    tag on 13 measured gate-agent pairs; the gate-scaling citation obligation), `### Changed` (SC-009
    re-scoped to precision-from-usage vs recall), `### Fixed` (EG-2 per-sub-phase `exempt_authored`
    attribution at the G9b barrier + locking fixture).
  - Pattern: mirror the existing `## [5.14.0]` entry structure (Keep a Changelog).
  - Done: a `## [5.16.0] — <date>` section exists with Added/Changed/Fixed.
  - Verify: `grep -n '\[5.16.0\]' plugins/spec-flow/CHANGELOG.md` returns a hit near the top.

> Pure Implement-track phase: a version-bump/CHANGELOG edit with no new behavior under test — no
> `[Write-Tests]` step (AC-12 reuses the existing `static.sh` version-sync assertion + the
> no-deps/bare-name greps in `[Verify]`).

- [x] **[Verify]** Release verification (AC-12)
  **Superseded-ordinal anti-drift sweep (§2e — enumerate SUPERSEDED + new):**
  - Superseded sweep (must be 0 in version-bearing files): `grep -rn '5\.14\.0\|5\.12\.4' plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-flow/tests/e2e/lib/static.sh` — Expected: **0 hits** (no stale `5.14.0` in plugin.json/marketplace.json; no `5.12.4` in static.sh). (CHANGELOG legitimately retains the historical `## [5.14.0]` entry — exclude it from this sweep.)
  - New-target sweep: `grep -rn '5\.16\.0' plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-flow/tests/e2e/lib/static.sh plugins/spec-flow/CHANGELOG.md` — Expected: plugin.json 1, marketplace.json 1 (spec-flow entry), static.sh 3, CHANGELOG ≥1.
  **Phase-level checks:**
  - Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh` (default mode) — Expected: the AC-11 version-sync assertions PASS (plugin.json + marketplace.json + CHANGELOG all show 5.16.0); summary `0 failed, 0 errors`, exit 0. (This is the NN-C-001 version-sync diff being empty.)
  - Run (bare name, AC-12): `grep -rE '^name:\s*spec-flow-' plugins/spec-flow/agents/` — Expected: **no output** (every agent `name:` is bare).
  - Run (no shipped deps, AC-12): `find plugins/spec-flow -name requirements.txt -o -name package.json -o -name pyproject.toml -o -name Pipfile` — Expected: **no output**.
  - Run (tool deps exist, AC-12): `test -f tools/transcript-eval/requirements.txt && echo OK` — Expected: `OK`.
  - Failure: any version surface disagreeing; a prefixed agent `name:`; any runtime-dep manifest under `plugins/spec-flow/`; a missing `tools/transcript-eval/requirements.txt`.

- [x] **[QA]** Phase review
  - Review against: AC-12
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 10: Produce the first cross-repo baseline (operator-gated capstone)
**Exit Gate:** the validated full miner runs across the operator's real configured project dirs
(≥2 repos, all sessions), persisting `aggregates.json` + `story-latest.md` + a `run-index.jsonl`
entry to the **external** insight store; the operator confirms (a) the story is accurate +
decision-useful, (b) no cross-repo/secret content reached the repo, (c) full-corpus extraction
coverage is acceptable; an in-repo provenance stub records run **metadata only** (run-id, date,
#sessions, #repos, store path — **no aggregates, no per-seat numbers, no findings, no transcript
content**, per SF-5/SF-6).
**ACs Covered:** AC-3 (judgment: operator confirms the story is accurate + decision-useful — against
the REAL baseline, not a fixture), AC-5 (judgment: operator confirms no prop-firm content reached the
repo — on a real cross-repo run), AC-6 (judgment: operator reviews the coverage over the full corpus,
not just the ≥20-finding sample)
**In scope:** a `baseline` runbook section in the tool README; the operator-gated real full-corpus run
producing the persisted baseline in the external store; an in-repo metadata-only provenance stub
(`tools/transcript-eval/BASELINE.md`).
**NOT in scope:** the LLM-inference/verdict-flip layer (deferred, Out of Scope); committing ANY mined
content — aggregates/story/findings live ONLY in the external store (SF-5/SF-6); this phase produces
the FR-016 evidence but does NOT itself cut any board seat (that is FR-016's job, citing this baseline).
**Why last:** Phase 9 is repo-file release-prep; this phase is the operator-gated capstone that
exercises the shipped tool on the real corpus to produce the first FR-016 evidence. It changes no
version-bearing file (the only in-repo artifact is the metadata stub), so it does not disturb Phase 9's
release verification. It is gated on Phase 2's `PROCEED` (extraction validated) + Phase 4 (full
pipeline built).
**Charter constraints honored in this phase:** (none new — NN-P-004 "operator-gated" is allocated to
Phase 2 and is *exercised* here as the canonical out-of-band operator invocation; SF-6 privacy is
verified by the metadata-only stub guard below.)

> Pure Implement-track phase: the deliverable is a runbook + a metadata-only stub + an operator-gated
> real run whose correctness is operator judgment (AC-3/AC-5/AC-6 judgment halves), not a unit-testable
> behavior — no `[Write-Tests]` step. The machine halves of these ACs are covered by Phases 2/4.

- [x] **[Implement]** Add the baseline runbook + the metadata-only provenance stub
  - Order: README runbook section → the metadata-only stub template.
  - Architecture constraints: the in-repo stub carries run **metadata only** — never aggregates,
    per-seat numbers, findings, or transcript content (SF-5/SF-6). All mined output goes to the
    external store exclusively.

  **Change Specifications:**

  **T-1: MODIFY `tools/transcript-eval/README.md`** (add a `## Producing the baseline` runbook section)
  - Anchor: append a new H2 section after the CLI usage section (created Phase 1 T-2).
  - Target: document the exact baseline command — `python3 -m transcript_eval story` against the
    default real config (all configured project dirs, all sessions) writing to the configured external
    store — plus the three operator confirmations (story accuracy/usefulness, no in-repo leakage,
    full-corpus coverage) and the gate (only run after Phase 2 emitted `PROCEED`).
  - Pattern: mirror the concise runbook style of `plugins/spec-flow/tests/e2e/README.md` `## Live procedure`.
  - Done: README has a `## Producing the baseline` section with the command + the three confirmations + the PROCEED gate.
  - Verify: `grep -q "Producing the baseline" tools/transcript-eval/README.md`.

  **T-2: CREATE `tools/transcript-eval/BASELINE.md`** (metadata-only provenance stub)
  - Structure: one H1; a table/list with `run_id`, `date`, `sessions_parsed`, `repos`, `store_path`,
    and a one-line `coverage` summary (a single percentage from the run's CoverageReport — NOT
    per-seat numbers). An explicit header line: `<!-- METADATA ONLY — no aggregates/findings/transcript
    content; all mined output lives in the external store (SF-5/SF-6). -->`. The actual values are
    filled by the operator from the real run.
  - Pattern (the no-secrets/no-mined discipline — mirrors `metrics.yaml` recording counts/dates only):
    ```
    <!-- METADATA ONLY — SF-5/SF-6: no aggregates, no per-seat numbers, no findings, no transcripts. -->
    # gate-evals baseline (provenance)
    - run_id: <from run-index.jsonl>
    - date: <YYYY-MM-DD>
    - sessions_parsed: <int>   repos: <int>
    - store_path: <external store abs path>
    - extraction_coverage: <overall %, single number — NOT per-seat>
    ```
  - Done: `BASELINE.md` exists, carries the METADATA-ONLY guard comment, and contains NO per-seat
    numbers / aggregates / findings / transcript content.
  - Verify: `test -f tools/transcript-eval/BASELINE.md && grep -q "METADATA ONLY" tools/transcript-eval/BASELINE.md`.

- [x] **[Verify]** Produce + confirm the baseline (operator-gated — AC-3/AC-5/AC-6 judgment halves)
  **Operator-gated real run (the capstone — PERFORMS the measurement):**
  - Precondition: Phase 2 emitted `PROCEED` (extraction validated on real data).
  - Run (real full corpus, ≥2 repos, all sessions, into the configured EXTERNAL store): `cd
    tools/transcript-eval && python3 -m transcript_eval story` (default config: all configured project
    dirs; default store `/Volumes/joeData/spec-flow-insights/`).
  - Expected: `<store>/aggregates.json`, `<store>/story-latest.md`, and a new `<store>/run-index.jsonl`
    line all appear in the EXTERNAL store; the story contains the `## FR-016 per-seat evidence` section
    with real per-seat precision/overlap/leave-one-out across the real corpus.
  **Privacy guard (AC-5 machine half, re-asserted on the real run):**
  - Run: `git -C <repo-root> status --porcelain` after the baseline run — Expected: the ONLY new/changed
    in-repo files are `tools/transcript-eval/README.md` + `tools/transcript-eval/BASELINE.md` (metadata);
    NO `aggregates.json` / `story-latest.md` / `*.jsonl` / transcript content anywhere under the repo.
  - Run: `grep -rEi 'sk-[A-Za-z0-9]{16,}|BEGIN [A-Z ]*PRIVATE KEY' tools/transcript-eval/BASELINE.md` — Expected: **no output** (no secrets in the stub).
  **Operator confirmations (judgment — required keystroke each, NN-P-001 / NN-P-004):**
  - AC-3 judgment: operator reads `<store>/story-latest.md` and confirms it is **accurate and
    decision-useful** (the FR-016 per-seat section reflects real usage).
  - AC-5 judgment: operator confirms **no prop-firm / cross-repo content reached the ai-plugins repo**
    (the cross-repo aggregates live only in the external store).
  - AC-6 judgment: operator confirms the **full-corpus extraction coverage** is acceptable (consistent
    with the Phase-2 spike sample; a large coverage regression at full scale is a halt-and-investigate).
  - Failure: any aggregates/story/transcript content appearing under the repo; a secret in the stub;
    the operator judging the story inaccurate or coverage unacceptable (→ revisit extraction per ADR-6).

- [x] **[QA]** Phase review
  - Review against: AC-3, AC-5, AC-6
  - Diff baseline: git diff <phase_start_tag>..HEAD

## AC Coverage Matrix

(Included for traceability; not required in non-TDD mode. Every AC is COVERED.)

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | Extraction parses `.jsonl` best-effort → per-seat findings + accept/reject + coverage report; no silent drop | COVERED | Phase 2 (extraction); Phase 4 (INT-2 end-to-end) |
| AC-2 | Metric layer: precision/overlap/leave-one-out/rubber-stamp/activity = hand-derived; LOO per seat | COVERED | Phase 3 |
| AC-3 | Story has required FR-016 per-seat section; precision-from-usage labels; never "catch rate" | COVERED | Phase 4 (machine: render+grep); Phase 10 (judgment: operator confirms real baseline story) |
| AC-4 | Run-history + aggregates + story land in repo-peer store; nothing in-repo; unwritable fails loudly | COVERED | Phase 1 (store writer); Phase 4 (INT-2) |
| AC-5 | Cross-repo scrub: secrets scrubbed, cross-repo content stays external, no raw transcript in-repo | COVERED | Phase 2 (scrub); Phase 4 (privacy e2e); Phase 10 (judgment: no cross-repo content in-repo on real run) |
| AC-6 | Extraction-validation spike: ≥20 findings/≥3 sessions/≥2 repos; PROCEED iff cov≥95% ∧ agree≥80% | COVERED | Phase 2 (spike + machine gate); Phase 10 (judgment: full-corpus coverage acceptable) |
| AC-7 | Cheater oracle: 6 classes ≥1× + EG-4 (≥10), 100% detection, ≥5 allow-set 0 FR, clean `$TMPDIR` on abort | COVERED | Phase 5 |
| AC-8 | EG-1 transitive/by-name closure-tamper probe in a separate residual tier, excluded from 100% | COVERED | Phase 5 |
| AC-9 | Multi-sub-phase cross-exemption tamper rejected after EG-2 fix; locking fixture DETECTED | COVERED | Phase 6 |
| AC-10 | 13 measured pairs carry byte-identical additive `rubric_version`; no other frontmatter change | COVERED | Phase 7 |
| AC-11 | gate-scaling#board-swap-rule citation obligation + SC-009 re-scope (precision vs recall, no "catch rate") | COVERED | Phase 8 |
| AC-12 | Version bump synced + CHANGELOG; bare `name:`; no shipped runtime-dep; tools/ requirements.txt exists | COVERED | Phase 9 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `cd tools/transcript-eval && python3 -m pytest tests/test_extract.py -q` | all pass, `0 failed`; malformed line → reported miss, no crash; per-seat finding + accept/reject records produced |
| AC-2 | shell | `cd tools/transcript-eval && python3 -m pytest tests/test_metrics.py -q` | all pass; each metric = hand-derived; leave-one-out delta per seat |
| AC-3 | shell + agent-step | `cd tools/transcript-eval && python3 -m pytest tests/test_story.py -q` (machine); operator reads `<store>/story-latest.md` from the Phase 10 real run (judgment) | FR-016 section header present; no "catch rate"/"recall" mislabel; operator confirms the real baseline story is accurate + decision-useful |
| AC-4 | shell | `cd tools/transcript-eval && python3 -m pytest tests/test_store.py -q` | store files under temp path; unwritable → loud non-zero, no in-repo write |
| AC-5 | shell + agent-step | `cd tools/transcript-eval && python3 -m pytest tests/test_integration_store.py tests/test_scrub.py -q` (machine); `git status --porcelain` after the Phase 10 real run (judgment) | secret scrubbed; zero new in-repo mined files (only README + BASELINE.md metadata); cross-repo content stays in store |
| AC-6 | agent-step | Read the SF-7 spike report from a real run; confirm coverage% + agreement% over ≥20 findings/≥3 sessions/≥2 repos + PROCEED/HALT (Phase 2); operator confirms full-corpus coverage on the Phase 10 baseline run | report carries the fields + verdict; operator confirms sample + full-corpus coverage |
| AC-7 | shell | `bash plugins/spec-flow/tests/e2e/run-e2e.sh --cheater` | 6 classes ≥1× + EG-4 ≥10 total, 100% detection, 0/5 allow-set FR, clean `$TMPDIR` after forced abort; exit 0 |
| AC-8 | shell | `bash plugins/spec-flow/tests/e2e/run-e2e.sh --cheater` (residual line) | EG-1 probe under a distinct/EXCLUDED tier label, NOT in the 100% headline tally |
| AC-9 | agent-step + shell | `grep -n "per-sub-phase" plugins/spec-flow/skills/execute/SKILL.md` (within G9b 1475–1540) + `bash …/run-e2e.sh --cheater` | attribution-rule anchor present in G9b; EG-2 locking scenario reported DETECTED (not residual) |
| AC-10 | shell | `grep -L 'rubric_version:' <26 measured files>` and per-pair `diff` | grep empty (all carry the key); every pair `diff` empty; excluded agents carry no key |
| AC-11 | shell | `grep -n "leave-one-out" plugins/spec-flow/reference/gate-scaling.md` + `sed -n '444p' docs/prds/exec-ready/prd.md \| grep -i "catch rate"` | gate-scaling cites leave-one-out + cheater-track; SC-009 line has no "catch rate" claim for mined gates |
| AC-12 | shell | `bash plugins/spec-flow/tests/e2e/run-e2e.sh` + `grep -rE '^name:\s*spec-flow-' agents/` + `find plugins/spec-flow -name requirements.txt …` + `test -f tools/transcript-eval/requirements.txt` | version-sync assertions pass; no prefixed name; no shipped dep manifest; tools/ requirements.txt exists |

## Contracts

The boundary-crossing interfaces below are consumed by code outside their defining phase — chiefly
`flywheel-global` (FR-007), which imports the parse/scrub/aggregate lib (OQ-3). Internal helpers are
not contracts.

### C-1: `transcript_eval.extract` — parse/extract lib surface
- **ID:** C-1
- **Type:** Function (module API)
- **Phase:** Phase 2
- **Signature:** `iter_records(jsonl_path: Path) -> Iterator[dict | None]`; `extract_dispatches(records: list[dict]) -> list[Dispatch]`; `correlate_results(records, dispatches) -> dict[str, str]`; `extract_findings(result_text: str) -> list[Finding]`; `infer_accept_reject(finding, downstream) -> Literal["accepted","rejected"]`
- **Inputs:** `jsonl_path` — a real `~/.claude/projects/*.jsonl`; `records` — best-effort-parsed dicts (or `None` on a bad line)
- **Outputs:** per-seat `Finding` records (seat, finding text, accept/reject) + a `CoverageReport`
- **Error cases:** malformed JSON line → yields `None` + increments a reported miss (never raises); unknown `subagent_type` → not a measured dispatch (skipped, not an error)
- **Constraints:** read-only against source; never silently drops a finding; `flywheel-global` reuses this surface unchanged (OQ-3)

### C-2: `transcript_eval.metrics.compute_metrics` — gate-effectiveness metric surface
- **ID:** C-2
- **Type:** Function
- **Phase:** Phase 3
- **Signature:** `compute_metrics(records: list[dict], *, rubber_stamp_secs: int = 60) -> dict[str, SeatMetrics]`
- **Inputs:** `records` — extracted per-seat finding records (C-1 output); `rubber_stamp_secs` — fast-approval threshold
- **Outputs:** per-seat `SeatMetrics` (precision, raised, accepted, activity, overlap, unique_catch, leave_one_out_delta, rubber_stamp_candidates), every effectiveness field tagged `metric_kind: "precision-from-usage"`
- **Error cases:** `raised == 0` → `precision = None` (never `0/0`); no records → empty dict, not an error
- **Constraints:** deterministic (no model); no field labeled "catch rate"/"recall" (SF-8)

### C-3: `transcript_eval.store.InsightStore` — durable external store surface
- **ID:** C-3
- **Type:** Function (class API)
- **Phase:** Phase 1
- **Signature:** `InsightStore(config)`; `append_run(record: dict) -> None`; `write_aggregates(aggs: dict) -> None`; `write_story(md: str) -> None`
- **Inputs:** `config.store_path` (repo-peer, configurable); `record`/`aggs`/`md` — scrubbed, non-secret payloads
- **Outputs:** files under `store_path` only (`run-index.jsonl` with `kind`; `aggregates.json`; `story-latest.md` — ADR-4)
- **Error cases:** unwritable `store_path` parent → `StoreUnwritableError` + non-zero exit, **no in-repo fallback**; a `store_path` resolving under the repo root → rejected at construction
- **Constraints:** the only writable target in the tool; never writes in-repo (SF-6)

### C-4: `lib/cheater-oracle.sh` — reconstructed FR-011 predicate (bash)
- **ID:** C-4
- **Type:** Function (bash entrypoint)
- **Phase:** Phase 5 (registered), Phase 6 (completed — incl. G9b attribution)
- **Signature:** `cheater_oracle_checks()` (run_mode entry); internal `_sha256`, `_predicate_gate_a`, `_predicate_gate_b`, `_build_tampered_head`
- **Inputs:** the committed cheat/allow/residual fixtures; tampered HEAD states built in `e2e_mktemp`
- **Outputs:** `PASS`/`FAIL`/`EXCLUDED` lines via `assert.sh`; a never-false-green `summary` (exit 0 iff FAILS+ERRORS == 0)
- **Error cases:** a missing `lib/` function → `run_mode` ERRORs (counted); a tampered repo outside `/tmp|/private|/var/folders` → `e2e_cleanup` refuses (NN-C-006)
- **Constraints:** pure POSIX bash, no deps; `_sha256` parity-pinned to the live gate's hash form (ADR-7); `trap … EXIT` leaves `$TMPDIR` clean

## Parallel Execution Notes

The plan is authored as **serial flat phases**, not Phase Groups.

**Why serial:** the two halves (python mining, Phases 1–4; bash cheater track, Phases 5–6) touch
disjoint file trees and *could* run as parallel Phase Groups, but each half is an internally
**serial chain** (Phase 2's extraction is spike-gated before Phase 3's metrics by ADR-6; Phase 4's
integration completes the lib; Phase 6's EG-2 fix completes the oracle from Phase 5). A Phase Group
models independent single-unit sub-phases, not two multi-phase chains. Serial flat phases also
preserve per-phase Opus QA on the **integrity-critical EG-2 guardrail edit** (Phase 6) and on the
lower-confidence operator-driven mining design (Phases 1–4, per the confidence note), and keep the
review-board narrative legible. Within-phase, the numbered `T-N` Change Specs touch disjoint files
and an executor may apply them in any order; no `[P]` cross-phase parallelism is declared.

## Dependency Triage

No unmet dependencies — `pipeline-e2e` and `metrics` are both `merged` (confirmed at plan-authoring
time). No `## Dependency Triage` action required.

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, the phase's `[Implement]` Change Specs (T-N), spec ACs, the `[Verify]` commands, arch constraints, pattern blocks, `introspection.md` (Cluster anchors for the phase scope) | Spec rationale, brainstorming history, other phases' diffs |
| Write-Tests (Non-TDD) | The phase's `Test Data` block, the implemented code (read from working tree), phase ACs | "Fail-first" requirement (none — code exists); other phases' tests |
| Verify | The phase's `[Verify]` commands + expected outputs, spec ACs | Implementation reasoning |
| QA | Phase diff, spec, plan, PRD sections (FR-017, SC-009, G-6), charter skills | Any agent conversation history |
| Final Review board | The cumulative piece diff, spec, plan, PRD, charter | Each other's findings (fresh, isolated seats) |
