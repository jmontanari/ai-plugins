## Brainstorm Inference Digest

**Piece purpose (FR-019 / US-019 / SC-011 / G-7).** Extract execute's inline Step 6c synchronous-discovery triage into a standalone `spec-flow:triage` skill invocable from ANY session (campaign, ad-hoc, intake-routed) — not only mid-execute. Given a discovery (agent-found or operator-stated), classify it to exactly one of **five** dispositions, dispatch the spike agent in **scope mode** as a bounded isolated Opus dispatch when the change needs design (never main-window thinking), and write a recorded manifest/backlog entry with provenance. Execute keeps its inline Step 6c unchanged (additive extraction); both share **one documented triage contract**. Preserves NN-P-002 (no silent mid-stream change), NN-P-004 (no silent defer), honors NN-P-006 (a bug-classified disposition carries the red-first obligation out of band). Reachable from intake routing.

**The disposition delta — the central design problem.** FR-019 names **5** dispositions: `small-change` / `plan-amend` / `new-piece` / `note-on-scheduled` / `explicit-defer-with-rationale`. Execute Step 6c today has **3**: `amend` / `fork` / `defer`. Mapping:

| FR-019 disposition | execute Step 6c analog | Context dependency |
|---|---|---|
| `plan-amend` | `amend` (plan-amend dispatch) | **Execute-bound** — needs an active piece + `plan.md` to amend + `piece_start_sha` + amendment-budget counters. Out of band there is no active plan → this disposition is reachable ONLY when the operator names a target in-progress piece. The standalone skill must DIVERGE: it cannot assume `$piece_start_sha`, the per-phase loop, or the in-memory budget counters; it must resolve an active piece/worktree the way `/spec-flow:defer` does (`git worktree list` + manifest reverse-lookup) or refuse. |
| `new-piece` | `fork` (manifest authoring + `depends_on`) | **Mostly context-free** — fork authors a new manifest entry today via the orchestrator; standalone version authors a manifest piece directly but DIVERGES on the `depends_on`/current-piece-`blocked` coupling (there is no "current executing piece" to block out of band). |
| `explicit-defer-with-rationale` | `defer` (`/spec-flow:defer` structured form) | **Context-free** — `/spec-flow:defer` already supports a manual form AND a structured form; the standalone skill routes here. Requires `--rationale` (NN-P-004). |
| `small-change` | **NEW** (no Step 6c analog) | **Context-free** — Step 6c has no "fix-now via small-change" path; this is a genuinely new disposition. Routes into `/spec-flow:small-change` exactly as `review-board --fix` does (seeded-input handoff). Bug-classified → NN-P-006 red-first. |
| `note-on-scheduled` | **NEW** (no Step 6c analog) | **NEW** — attach a note to an already-scheduled/queued (`open`/`specced`/`planned`) manifest piece rather than create a new one. No existing `notes` field on a piece exists today (only the manifest-level `coverage.notes`); design decision: where the note attaches (manifest piece field vs piece backlog vs spec). Open ambiguity for the brainstorm. |

**Design constraints inferred.** (1) Standalone any-session pattern = the **review-board sibling pattern** (Step 0 best-effort config, no active piece/manifest/worktree required, routes into other skills, never patches). (2) Spike scope-mode is the ONE sanctioned Opus dispatch — reuse `agents/spike.md` + `reference/spike-agent.md` verbatim; BLOCKED → record an open needs-scoping item with the blocker, never a fabricated disposition. (3) The 50% diff-ratio threshold gate decides spike-vs-direct — but out of band there is no `cumulative-diff-size` baseline, so the threshold semantics must DIVERGE (no `$piece_start_sha`; likely "always scope-spike a design-needing change" or a different sizing input). (4) Thin-orchestrator (CR-008): the skill parses input, classifies, dispatches at most the spike agent, routes into small-change/defer, writes manifest/backlog — no implementation logic, no sub-agent fan-out. (5) Markdown-only, no runtime deps (NN-C-002). (6) Version bump + CHANGELOG (NN-C-009); plugin currently at 5.17.0.

**Open ambiguities for the brainstorm.** (a) Where does `note-on-scheduled` write — a new manifest piece `notes:` field, the target piece's `backlog.md`, or its `spec.md`? (b) How does the standalone skill resolve the threshold/sizing when there is no `$piece_start_sha` cumulative diff? (c) For `plan-amend` out of band: does triage itself dispatch `plan-amend`, or does it refuse unless inside the piece's worktree and hand the operator back to execute? (d) How is the input discovery supplied — positional finding text + flags, or a structured block like `/spec-flow:defer`'s structured form? (e) The single shared triage contract: a new `reference/triage-contract.md` that both execute Step 6c and the skill cite (CR-008/NN-C-008 "definitions live in one place"), OR does the skill cite the execute Step 6c prose? (f) NN-P-006 reach: where is the red-first obligation recorded when a bug-classified discovery routes to small-change/plan-amend/new-piece? `bugfix-redfirst` (the piece that fully implements NN-P-006) is **open/not-yet-merged** — gather what exists, flag the dependency seam. (g) Intake reachability: AC-5 needs an "investigation/discovery" classification in intake's Q-tree to point here.

## Codebase Conventions

- **Skill frontmatter (CR-002):** `name:` matches directory; `description:` third-person when-to-use triggers. `argument-hint:` is optional — only `review-board/SKILL.md` uses it today (`argument-hint: "<...> [--flag]"`), and it is the closest structural analog for an arg-taking out-of-band skill. No `model:` key on skills (skills run in the main window; agents carry `model:`).
- **Standalone/out-of-band skill shape (review-board):** `## Step 0: Load config (best-effort)` reads `.spec-flow.yaml` for `docs_root` (default `docs`), confirms a git repo, never requires an active piece. Explicit `## Boundaries — what this skill does NOT do` section (no merge, no pipeline mutation it does not own, no sign-off gate, no direct code edits). Routes into `/spec-flow:small-change` for fixes rather than patching.
- **Agent dispatch:** `Agent({ description, prompt, model })`; every dispatch prepends a `WORKTREE: <abs-path>` preamble (`reference/coordinator-contract.md`). Spike agent is `model: "opus"`, isolated, ≤2K digest, `STATUS: OK|BLOCKED`.
- **Reference-doc citation (CR-008 / NN-C-008):** "definitions live in one place." Skills cite anchors (e.g. `reference/spike-agent.md ## Threshold reuse`, `reference/flywheel.md ## Match + confirm flow`) and explicitly say "do NOT restate." Expect a single shared triage-contract reference doc for this piece.
- **`${CLAUDE_PLUGIN_ROOT}`** used for agent/template/script paths inside skills (e.g. `${CLAUDE_PLUGIN_ROOT}/agents/review-board-<lens>.md`, `${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query`).
- **Provenance + no-silent-write idioms:** `/spec-flow:defer` requires `--rationale`, refuses silently-missing optionals (NN-C-005), records qualified `<prd-slug>/<piece-slug>` source always. `.discovery-log.md` one-row-per-discovery with a Resolution-commit cell convention. Conventional-commits chore type with piece scope (CR-004): `chore(<piece-slug>): <verb> — <summary>`.
- **Manifest mutation:** `${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query set-status <slug> <status>`; status vocabulary `open|specced|planned|in-progress|merged|done|superseded|blocked`. Manifest is orchestrator-owned (the spike agent MUST NOT touch it).

## Execute Step 6c — the extraction source

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/execute/SKILL.md` lines 1015–1338 (`### Step 6c: Discovery Triage`). Sub-sections: Aggregation (4 discovery sources, lines 1021–1045), Operator-initiated change admission FR-008 (1046–1066), Triage prompt (1068–1088), Flywheel pattern recording FR-006 (1090–1104), Auto-mode threshold FR-17 (1106–1145), Amend dispatch + scope-spike pre-step (1147–1215), Fork dispatch (1216–1235), Defer dispatch (1237–1247), Amendment budget tracking (1249–1304), `.discovery-log.md` authoring (1306–1329), Recursion semantics (1331–1333), NN-P-002 preservation (1335–1337).

### Dependency Map
**Dependency Map:** Step 6c dispatches `agents/spike.md` (scope mode, Opus), `agents/plan-amend.md` (Phase-4 output), `agents/spec-amend.md` (Phase-5 output), `agents/qa-plan.md` / `qa-spec.md` (iter-until-clean), and `/spec-flow:defer` (structured form). It writes `manifest.yaml` (fork), `plan.md`/`spec.md` (amend), `.discovery-log.md` (all), `docs/patterns.yaml` (flywheel FR-006), and the metrics artifact (`reference/metrics-artifact.md` `execute.discoveries.{spike_attributed,unmarked}`, `execute.amendments.{total,repeat_scope}`). Cites `reference/spike-agent.md` (`## Threshold reuse`, `## Placement rule`, `## No-bypass gate`, `## Amendment budget`), `reference/flywheel.md`, `reference/qa-iteration-loop.md`, `reference/metrics-artifact.md`.

### Test Landscape
**Test Landscape:** No unit tests on Step 6c prose directly. `pipeline-e2e` (merged, FR-013) is the e2e smoke harness asserting dispatch sequence + artifact ordering incl. discovery-log rows on triage; it is the regression net any Step 6c change rides on. The coherence linter validates cross-file anchor references (a new shared triage-contract doc must keep its citations resolvable). No fixtures exist for an out-of-band triage flow yet.

### Pattern Catalog
**Pattern Catalog:** Context-bound vs context-free split — the load-bearing extraction map:

```
EXECUTE-BOUND (cannot survive extraction unchanged):
 - $piece_start_sha, cumulative-diff-size, the 50% ratio computation (line 1119-1127)
 - amendment budget counters piece_amendment_count / piece_spec_amendment_count (1253-1304)
 - phase_<id>_routed_discoveries aggregation + per-phase loop position (1021-1044)
 - blocking-on-current / blocking-on-later / additive placement into an active plan (1198-1206)
 - "current WIP finishes first" preemption semantics (no WIP out of band)

CONTEXT-FREE (extracts cleanly into the standalone skill):
 - classification of a discovery to a disposition
 - spike scope-mode dispatch + BLOCKED handling (1151-1164)
 - provenance recording / .discovery-log.md row convention (1306-1329)
 - /spec-flow:defer structured invocation (1237-1247)
 - flywheel match-propose-confirm (FR-006, operator-gated)
```

Operator-initiated change admission (FR-008) — the "operator-stated discovery" half of FR-019's input, lifted from execute:

```
That reads as a scope change: "<one-line summary of the change>". Route it through scope → amend → execute? (y/n)
- On y: append with source_agent: operator, default_triage: amend, row_text = verbatim
- On n: treat as a comment; no routing
```

## Spike agent — scope mode (the sanctioned bounded Opus dispatch)

### File Inventory
**File Inventory:** `plugins/spec-flow/agents/spike.md` (the agent, Opus, 2 modes), `plugins/spec-flow/reference/spike-agent.md` (single source of truth: modes table, artifact schema/location, classification vocabulary, placement rule, threshold reuse, amendment budget, no-bypass gate).

### Dependency Map
**Dependency Map:** Cited by `execute/SKILL.md`, `agents/plan-amend.md`, `agents/spike.md`, `skills/plan/SKILL.md`. Scope-mode inputs: change text (`row_text` / operator request) + current plan + diff/neighborhood scope. Output: scoping artifact at `docs/prds/<prd-slug>/specs/<piece-slug>/spikes/<id>.md`. The standalone skill DIVERGES on "current plan" and "diff/neighborhood scope" — out of band there may be no current plan; the brainstorm must decide what scope-mode inputs are when triage runs without an active piece.

### Test Landscape
**Test Landscape:** `spike-agent` piece is **merged** (dependency satisfied). The `[SPIKE]`-resolution → test-data round-trip is a named `pipeline-e2e` case; scope-mode out-of-band has no fixture.

### Pattern Catalog
**Pattern Catalog:** Scope-mode contract and BLOCKED semantics (artifact NOT written on BLOCKED):

```
| scope | an admitted mid-execution change above threshold | the change text + current plan
        + diff/neighborhood scope | the scoping artifact (classification + enumerated task list)
        consumed by plan-amend |
Both modes: Opus, isolated context, ≤2K digest, STATUS: OK|BLOCKED.
A BLOCKED result writes no partial artifact and dispatches no sub-agents.

Classification (scope mode only): blocking-on-current | blocking-on-later: <phase-id> | additive: <after-phase-id>
```

Threshold reuse (DIVERGES out of band — no cumulative-diff baseline):

```
ratio = absorption-size / cumulative-diff   (50% gate)
- ratio >= 0.5 (or undefined / zero-cumulative-diff) -> scope spike before plan-amend
- ratio < 0.5 -> direct amend
```

## Structural analogs — standalone any-session skill

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/review-board/SKILL.md` (the canonical out-of-band sibling — standalone, no active piece, routes into small-change via `--fix`, explicit Boundaries section, `argument-hint`), `plugins/spec-flow/skills/small-change/SKILL.md` (the `small-change` disposition target; its `## Step 6: Seeded input` provision treats a handed-off digest as authoritative requirements; bug-signal keywords `fix`/`bug`/`broken`/`regression`/`patch`), `plugins/spec-flow/skills/defer/SKILL.md` (the `explicit-defer` target; manual + structured invocation forms, `--rationale` refusal contract, `.discovery-log.md` row authoring, NN-C-005 silent-on-missing-optional), `plugins/spec-flow/skills/intake/SKILL.md` (AC-5 reachability — Q4 "Exploration" + Step 2 auto-classify `exploratory`; a new "investigation/discovery" route must point at `spec-flow:triage`).

### Dependency Map
**Dependency Map:** review-board → `/spec-flow:small-change` (fix routing, Ownership check) → execute (separate session per NN-P-001). small-change → `/spec-flow:defer` (deferred-item disposition #2) and creates `change/<slug>` worktree. defer → `improvement-backlog.md` / `prds/<slug>/backlog.md` (sole write path) + `.discovery-log.md`. intake → `status` skill + `manifest-query` + routes to pipeline skills. The triage skill will sit alongside these as a 12th skill and route INTO small-change/defer/manifest.

### Test Landscape
**Test Landscape:** review-board, small-change, defer all merged/stable; no shared triage test harness. intake AC-IN-5 ("no silent routing — operator must explicitly select") is the precedent the triage-reachability AC mirrors.

### Pattern Catalog
**Pattern Catalog:** review-board standalone declaration + Boundaries (the template to copy):

```
This skill is standalone — it does NOT require an active piece, a manifest, or even a
spec-flow project layout. It only requires a git repository to compute a diff.

## Boundaries — what this skill does NOT do
- No merge.  - No pipeline mutation (never amends a plan/spec, forks, writes backlog...).
- No sign-off gate.  - No direct code edits (--fix routes into /spec-flow:small-change).
```

review-board → small-change handoff (the `small-change` disposition wire), and small-change's seeded-input acceptance:

```
review-board: "Hand off to /spec-flow:small-change, passing the digest as the change
  description ... source: review-board ... small-change treats a review-board digest as
  authoritative requirements (it confirms scope rather than re-brainstorming from zero)."
small-change Step 6: "When this skill is invoked with a pre-formed requirement set ...
  treat that digest as the authoritative requirements ... Record provenance in brief.md
  (a ## Source line naming the run/target)."
```

defer structured form (the `explicit-defer` disposition wire — skips operator-prompt, requires rationale):

```
Structured fields: source_piece, source_phase, source_agent, finding_text,
  operator_rationale, target (optional), discovery_type (optional).
Structured invocation skips the operator-confirmation prompt (operator already chose defer
upstream). Refuses if rationale missing. Writes backlog entry + .discovery-log.md row in
one chore(<piece-slug>): defer commit.
```

## Manifest + backlog write surfaces (new-piece / note-on-scheduled)

### File Inventory
**File Inventory:** `docs/prds/exec-ready/manifest.yaml` (piece schema: `name`/`slug`/`description`/`prd_sections`/`dependencies`/`status`, plus `merged_at`; manifest-level `coverage.notes` but NO per-piece `notes:` field today), `plugins/spec-flow/skills/manifest/SKILL.md` + `${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query` (open/deps/ready/table/set-status), execute Step 6c Fork dispatch (1216–1235, the existing manifest-authoring path), `/spec-flow:defer` (backlog write path).

### Dependency Map
**Dependency Map:** `new-piece` reuses fork's manifest-authoring (author entry with `status: open`, `dependencies:`/`depends_on`); DIVERGES by dropping the "set current piece blocked" coupling (no current executing piece out of band). `note-on-scheduled` has NO existing surface — a scheduled/queued piece = a manifest piece in `open`/`specced`/`planned`; where the note attaches is an open design decision (candidate: a per-piece `notes:` list on the manifest entry — additive per NN-C-003 — or the target piece's `backlog.md`). `explicit-defer` reuses `/spec-flow:defer` structured form unchanged.

### Test Landscape
**Test Landscape:** `manifest-query` has a fixture-backed test suite (`scripts/tests/fixtures/exec-ready.yaml`) covering open/deps/ready/table/set-status — but no `add-piece` or `add-note` subcommand exists; a `note-on-scheduled` or `new-piece` write either reuses fork's free-form YAML authoring (LLM-edits the file) or needs a new manifest-query verb. metrics-artifact records `source: campaign`/triage occurrences (`reference/metrics-artifact.md`) — the FR-019 dispositions should surface as flywheel occurrences (FR-006) operator-gated.

### Pattern Catalog
**Pattern Catalog:** Fork manifest-authoring (the `new-piece` base, minus the blocked-coupling):

```
1. Author a new piece entry in manifest.yaml with depends_on: [<current-piece-slug>];
   slug operator-supplied at fork time; status starts as open.
2. Set the current piece's status to blocked (DIVERGES: no current piece out of band).
3. Append .discovery-log.md row + commit manifest:
   git commit -m "chore(<piece-slug>): fork — <reason — discovery summary>"
```

Piece status vocabulary (the scheduled/queued states `note-on-scheduled` targets):

```
open | specced | planned | in-progress | merged | done | superseded | blocked
ready = status: open AND every dependency merged/done
```

## NN-P-006 red-first out-of-band reach + the shared contract seam

### File Inventory
**File Inventory:** PRD `NN-P-006` (lines 698–703) + `FR-022` (464–482) + the `bugfix-redfirst` manifest piece (474–511, **status: open / NOT merged**). `reference/spike-agent.md`, `reference/flywheel.md`, `reference/metrics-artifact.md`, `reference/gate-scaling.md` (the existing shared reference docs — the model for a new `reference/triage-contract.md`). Charter: `.claude/skills/charter-coding-rules/SKILL.md` (CR-001/002/008/009), `.claude/skills/charter-non-negotiables/SKILL.md` (NN-C-002/003/004/008/009).

### Dependency Map
**Dependency Map:** `bugfix-redfirst` (FR-022/NN-P-006) is **open** — it owns the small-change/hotfix/qa red-first implementation. This piece (discovery-triage) only HONORS NN-P-006: when triage routes a bug-classified discovery to small-change / plan-amend / new-piece, that fix carries the red-first obligation. Today the small-change skill has bug-signal keywords (`fix`/`bug`/`broken`/`regression`/`patch`) but does NOT yet route them to a red-first cycle (that wiring lands in bugfix-redfirst). **Seam to flag:** the triage skill must mark/record the bug classification + red-first obligation in a forward-compatible way (e.g. in the small-change handoff digest provenance and/or the manifest/backlog entry) so that when bugfix-redfirst merges the obligation is honored — but it cannot DEPEND on bugfix-redfirst's machinery existing. Intake already records `small_change_signals_detected` for the same keyword set (intake Step 2) — a precedent for forward-recording a bug signal without acting on it.

### Test Landscape
**Test Landscape:** No NN-P-006 enforcement exists in code yet (its piece is open). The triage skill's NN-P-006 honoring is therefore documentation + provenance-recording only at this point; the actual red-first gate is bugfix-redfirst's `qa-plan`/`qa-spec`/small-change/hotfix edits. The PRD edge-case table already lists "`spec-flow:triage` routes a bug-classified discovery to a fix → the spawned fix runs the red-first cycle (NN-P-006 follows the fix out of band)" (FR-019/FR-022 row) as the binding behavior.

### Pattern Catalog
**Pattern Catalog:** NN-P-006 out-of-band reach (the binding rule this piece honors):

```
NN-P-006 ... governs every fix path ... AND the out-of-band inter-execution fix routes —
when spec-flow:triage (FR-019) routes a bug-classified discovery to a fix, or a
spec-flow:campaign (FR-020) finding becomes a fix, that fix is red-first too.
A bug "fix" whose test was written after the fix and never observed failing against the
broken code does not satisfy this rule.
```

Shared-contract convention (CR-008/NN-C-008 "definitions live in one place") — the model for the single documented triage contract execute Step 6c + the skill both cite:

```
reference/spike-agent.md: "Single source of truth for the spike agent ... Definitions
  live here and nowhere else."
execute Step 6c: "Do NOT restate those rules here (CR-008 / NN-C-008)."
```

NN-C invariants the piece must satisfy: NN-C-002 (markdown/bash/yaml only, no runtime dep), NN-C-003 (additive — any new manifest `notes:` field is optional), NN-C-008 (self-contained agent prompts — the spike dispatch carries all context), NN-C-009 (version bump from 5.17.0 + CHANGELOG in all version-bearing files), CR-002 (skill frontmatter `name`+`description`, optional `argument-hint`), CR-008 (thin orchestrator — no sub-agent fan-out beyond the single spike dispatch).
