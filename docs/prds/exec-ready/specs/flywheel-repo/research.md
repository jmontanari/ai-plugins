# research.md — exec-ready / flywheel-repo

## Brainstorm Inference Digest

**Piece purpose.** Establish a repo-level self-hardening flywheel: recurring avoidable-discovery patterns become countable against a durable, stable-ID YAML registry at `docs/patterns.yaml`. On recording a finding, the flywheel LLM-proposes a pattern-ID match (or "new"); the operator confirms classification + scope at execute **Step 6c** (no silent write, per NN-P-004). Count = dated occurrences (provenance: piece, date, source). At a threshold (default 2, configurable via a new `.spec-flow.yaml` key, lean name `flywheel_threshold`) a single batched hardening proposal routes to its repo home (charter amendment / local QA hardening / PRD work). Rejections are recorded with rationale and never re-proposed. Non-blocking: emit `[FLYWHEEL-DEGRADED: repo registry unavailable]` when `docs/patterns.yaml` is unwritable, and the finding still flows to normal end-of-piece reflection. This piece must establish registry + match + count mechanics in a way the later `flywheel-global` piece (FR-007, `dependencies: [flywheel-repo]`) reuses verbatim — only the registry location (`docs/patterns.yaml` → machine-global `~/`) and the routing target differ.

**Design constraints the spec author must resolve (drawn from PRD Open Questions + edge cases + charter):**
- **Pattern occurrence granularity** — one occurrence per piece-where-the-pattern-appeared, vs one per reflection finding. PRD leaves this open (prd.md Open Questions; backlog.md "Pattern occurrence granularity"). This decision shapes both the YAML schema and the count semantics.
- **`docs/patterns.yaml` schema + stable-ID scheme** — no registry file exists yet (confirmed absent). The schema must carry: pattern ID (stable, human-readable or generated), a description, scope (charter/project/PRD or, for flywheel-global reuse, plugin), occurrence list with provenance `{piece, date, source}`, threshold-state, and a rejections list with rationale. Mirror existing provenance shape (defer entries: `Source` = qualified `<prd-slug>/<piece-slug>` phase `<phase-id>` (agent: `<agent>`), `Finding (verbatim)`, `Why…`, `Captured` date).
- **`flywheel_threshold` key shape** — follow `.spec-flow.yaml` house style: scalar with an `auto`/`<int>` idiom (cf. `qa_max_iterations: auto|<int>`, `refactor: auto|always|never`), default 2. Two sibling FO findings in backlog (`spike_threshold`, `admission-false-positive` pattern-type) suggest the flywheel may host multiple config scalars and pattern-types later — design the key/schema for extension but keep this piece to `flywheel_threshold`.
- **Match-proposal + confirm flow at Step 6c** — must reuse the existing single-aggregated-prompt-per-phase convention (NFR-6), the operator-confirm idioms already present, and must NOT introduce a silent-write path (CAP-F invariant: `/spec-flow:defer` is the sole backlog write path; the flywheel adds a *new* durable registry that is NOT a backlog and is NOT owned by defer — but it must obey the same no-silent-write + operator-gate doctrine).
- **Routing of batched hardening proposal** — three repo homes: charter amendment (`.claude/skills/charter-*/SKILL.md`), local QA hardening (qa-agent criteria / SKILL prose), PRD work (a manifest piece). All operator-gated.
- **Degraded path** — `[FLYWHEEL-DEGRADED: repo registry unavailable]` marker mirrors the existing non-blocking-marker convention (`[RESEARCH-UNAVAILABLE]`, `[TEST-DATA-ABSENT]`, `[SPIKE]`): a single bracketed line in orchestrator output, non-blocking, with normal reflection continuing.

**Open ambiguities for brainstorm:** (1) occurrence granularity (above); (2) what counts as a "pattern" source — is it only reflection findings (process-retro + future-opportunities), or also Step 6c discoveries / admission `n`-events / unmarked execute-time discoveries (the backlog flags "unmarked execute-time discovery" as a candidate flywheel pattern-type)? (3) where in the lifecycle the threshold-batched-proposal fires (Step 6c per finding, vs Step 4.5 end-of-piece batch, vs a new step); (4) stable-ID generation (operator-named vs auto-slug vs sequential); (5) how `flywheel-global` will factor in — the spec must keep registry-location + routing-target as the only two variation points so flywheel-global is a thin reuse.

## Codebase Conventions

- **Toolchain (NN-C-002 / charter-tools):** markdown + YAML + JSON + POSIX-bash only; no runtime dependencies. The flywheel is a skill/agent/reference + YAML registry change — no new language or runtime. The defer skill is the prior art for "no external parser/runtime"; YAML is read/written via the LLM agent's native parsing, not `yq`/`jq`/`python3`.
- **Reference-doc pattern:** every non-trivial mechanic lives in a single canonical `plugins/spec-flow/reference/<topic>.md` (one source of truth), cited from skills/agents by path + `## Heading` anchor (e.g. `plugins/spec-flow/reference/spike-agent.md` `## Threshold reuse`). A new `reference/flywheel.md` should follow `coordinator-contract.md` / `spike-agent.md` shape: a one-line "single source of truth … Cited by …" preamble, then `## `-level sections (modes/schema/location/classification/rules/See also). Definitions live in the reference and "nowhere else."
- **Marker convention:** non-blocking markers are single bracketed lines emitted in orchestrator progress output (not written into artifacts): `[RESEARCH-UNAVAILABLE: <reason>]`, `[TEST-DATA-ABSENT: …]`, `[SPIKE: <unknown>]`. `[FLYWHEEL-DEGRADED: repo registry unavailable]` follows this exactly.
- **Provenance shape:** the defer entry is the canonical provenance record — qualified `<prd-slug>/<piece-slug>` source, phase id, agent name, verbatim finding, operator rationale, `date +%F` capture date. `patterns.yaml` occurrences should mirror these fields.
- **`.spec-flow.yaml` config idiom:** each key documented inline with a comment block listing the literal allowed values and the default; behavioral keys use the `auto | <explicit>` pattern (`refactor`, `qa_max_iterations`, `model_policy`, `phase_groups`, `deferred_commit`, `reflection`). New keys are added to BOTH the live `.spec-flow.yaml` (repo root) and the `templates/pipeline-config.yaml` template. Backward compat (NN-C-003): absent key ⇒ behavior identical to before.
- **Operator-gate idiom (NN-C-006 / NN-P-004):** every state-changing or registry-writing operation emits an explicit `(y/n)` (or multi-option) confirmation prompt; structured-invocation paths that already collected the choice upstream skip the re-prompt (cf. defer's structured form).
- **Version sync (NN-C-001/004/007/009):** any plugin-behavior change bumps the version in **four** version-bearing files and adds a CHANGELOG section — see the Version/Marketplace Sync cluster.
- **Conventional Commits (CR-004):** resolution commits use `chore(<scope>): …` with the piece slug as scope.
- **Reflection findings are read-only:** reflection agents NEVER write backlog/registry files directly — they emit structured `## Findings` to the orchestrator, which routes via operator-gated Step 6c. The flywheel must follow this same surface-then-operator-gate discipline.

## Cluster 1 — Execute Step 6c discovery/triage (the flywheel's record + propose + confirm gate)

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/execute/SKILL.md` (1986 lines). Relevant regions: Step 6c "Discovery Triage" (lines ~975–1274) — sub-sections `Aggregation` (983), `Operator-initiated change admission (FR-008)` (1004), `Triage prompt` (1026), `Auto-mode threshold (FR-17)` (1048), `Amend dispatch` (~1091), `Fork dispatch` (~1160), `Defer dispatch` (1179), `Amendment budget tracking` (1191), `.discovery-log.md authoring` (1245), `Recursion semantics` (1268), `NN-P-002 preservation` (1272); Step 4.5 reflection dispatch note (181, 945); Step 6/QA `Deferred to reflection` surfacing (921–945); model-policy report (49–55).

### Dependency Map
**Dependency Map:** Step 6c runs once per phase, after Step 6b hook sweep and before Step 7 progress commit. It aggregates three sources into one ordered discovery list: (1) `phase_<id>_routed_discoveries` (Step 4 Reason-routed AC-matrix rows), (2) QA `Deferred to reflection:` findings from Step 6, (3) Build oracle missing-prerequisite escalations. FR-008 added a fourth admission path (operator-initiated change, detect-and-confirm). Triage emits ONE aggregated prompt per phase (NFR-6) with per-discovery options `(a) amend (f) fork (d) defer` plus conditional `(s) amend-spec`. Resolutions route to: `plan-amend`/`spec-amend` agents, manifest fork, or `/spec-flow:defer`. Every resolution appends a `.discovery-log.md` row in the SAME commit. Step 4.5 reflection findings (process-retro → `docs/improvement-backlog.md`; future-opportunities → `docs/prds/<prd-slug>/backlog.md`) flow THROUGH Step 6c per-finding triage. The flywheel's record+propose+confirm gate is the natural hook here — it sits alongside the spike-agent's scope-spike gate at the same Step 6c juncture. Key design question: does the flywheel fire per-discovery during Step 6c, or as an end-of-piece batch over accumulated occurrences (Step 4.5)? PRD says "single batched operator review" for the threshold proposal, implying record-at-6c + propose-batched.

### Test Landscape
**Test Landscape:** No automated test harness — spec-flow is documentation-as-code (markdown skills/agents). "Tests" are independent-test recipes in spec ACs and the qa-plan/qa-spec/review-board adversarial gates. Verification of new Step 6c behavior is by review-board spec-compliance + qa-plan criteria, plus grep-recipe ACs (cf. spike-agent AC-9 version-sync grep). The plan for this piece will mostly use the Implement/doc-as-code track (`tdd: false` ⇒ `qa_max_iterations: auto` = 5).

### Pattern Catalog
**Pattern Catalog:**
Operator-confirm admission gate (FR-008 detect-and-confirm — the model for the flywheel's match-confirm prompt):
```
That reads as a scope change: "<one-line summary of the change>". Route it through scope → amend → execute? (y/n)
```
Single-aggregated-prompt-per-phase convention (NFR-6) the flywheel's batched proposal must mirror:
```
<N> discoveries surfaced in <phase-id>:
  [1] <type> from <source-agent>: <finding-summary>
      Options: (a) amend  (f) fork  (d) defer
Choose for each (or 'A' to amend all that fit < 50% threshold, 'D' to defer all):
```
No-silent-write doctrine (defer is sole backlog path; flywheel adds a registry, not a backlog, but inherits the gate):
```
Per the CAP-F invariant ... /spec-flow:defer is the sole supported path for backlog writes — there is no orchestrator-side auto-append code path ... The operator triages it at Step 6c — only after the operator chooses ... does the orchestrator invoke /spec-flow:defer
```

## Cluster 2 — Reflection finding pipeline (the SOURCE of recurring patterns)

### File Inventory
**File Inventory:** `plugins/spec-flow/agents/reflection-future-opportunities.md` (92 lines), `plugins/spec-flow/agents/reflection-process-retro.md` (101 lines). Plus the orchestrator-side Step 4.5 dispatch + routing note in `execute/SKILL.md` (lines 181, 945).

### Dependency Map
**Dependency Map:** Both agents are Sonnet-tier, read-only, dispatched by execute at end-of-piece reflection (Step 4.5). They emit a structured `## Findings` report to the orchestrator; they NEVER write backlog/registry files. Routing: process-retro findings → `docs/improvement-backlog.md` (global, cross-PRD); future-opportunities → `docs/prds/<prd-slug>/backlog.md` (PRD-local). The orchestrator routes each finding through Step 6c per-finding triage, and only the operator-chosen `defer` writes (via `/spec-flow:defer`). process-retro findings carry a `**Category:**` field (`process-improvement | piece-candidate | observation`) that drives a batched-vs-per-finding triage UI (a `'D'` shortcut batch-defers all `process-improvement`). These are the canonical "recurring patterns" the flywheel counts: a finding recurring across pieces/PRDs is exactly what `patterns.yaml` must make countable. The flywheel's recording step likely hooks where these findings reach Step 6c, proposing a pattern-ID match against the durable registry before (or alongside) the existing defer-or-amend triage.

### Test Landscape
**Test Landscape:** Agent contracts verified by review-board + the agents' own first-turn entrypoint-check (BLOCKED-on-violation). No unit tests. The flywheel-recording addition to these agents (if any) must preserve their read-only / structured-findings-only contract and self-contained-prompt invariant (NN-C-008).

### Pattern Catalog
**Pattern Catalog:**
future-opportunities finding shape (clean `**Type:**` literal for single-pass routing):
```markdown
### Finding 1
**Type:** future-opportunity
**Rationale:** <why ... anchored to a concrete artifact (deferred AC ID, plan section, file:symbol, manifest piece)>
**Dependencies:** <... or "none">
**Candidate piece sketch:** <2-3 line description>
```
process-retro finding shape (carries Category for batched triage — a precedent for flywheel pattern-type/scope fields):
```markdown
### Finding 1
**Type:** process-retro
**Sub-type:** <must-improve | worked-well | metrics>
**Category:** <process-improvement | piece-candidate | observation>
**Body:** <verbatim retro item text>
```
Routing rule (process-retro → global; future-opportunities → PRD-local) — the flywheel correlates ACROSS these per-PRD boundaries:
```
process-retro findings ALWAYS route to docs/improvement-backlog.md (global, cross-PRD).
Future-opportunities findings route to the PRD-local backlog ... The two agents are paired
```

## Cluster 3 — Defer skill + backlog format (provenance the registry must mirror)

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/defer/SKILL.md` (177 lines); `docs/improvement-backlog.md` (global, ~290+ entries); `docs/prds/exec-ready/backlog.md` (PRD-local — already contains TWO flywheel-relevant FO findings: "flywheel-repo spec should include unmarked-execute-time-discovery as a first-class metric" and three spike-agent FOs FO-1/FO-2/FO-3 to fold into the flywheel spec). The `.discovery-log.md` per-piece audit file (format defined in execute/SKILL.md `.discovery-log.md authoring`).

### Dependency Map
**Dependency Map:** `/spec-flow:defer` is the SOLE write path for `improvement-backlog.md` and `prds/<slug>/backlog.md` (CAP-F invariant). It is a thin orchestrator (CR-008): parses args, formats one entry, appends under `## Recent findings`, commits `chore(<piece-slug>): defer <summary>`. Two invocation forms: manual (`(y/n)` confirm) and structured (orchestrator-driven from Step 6c, skips the confirm because the operator already chose `defer`). Reads `.spec-flow.yaml` for `docs_root`/`worktrees_root`. Resolves active piece via `git worktree list` + manifest reverse-lookup. **Relevance to the flywheel:** `patterns.yaml` is a NEW durable registry, NOT a backlog — so it is OUTSIDE defer's CAP-F scope and defer should NOT own it (or the spec must decide whether the flywheel writes the registry directly via its own operator-gated path, or extends defer). The occurrence-entry fields in `patterns.yaml` should mirror defer's six-field provenance so the two stay consistent. The degraded path mirrors defer's "refuse rather than guess/silently-fail" discipline (NN-C-005). Note the no-defer-in-ai-plugins memory: in THIS repo, findings should be fixed/forked rather than backlog-deferred as default — but the defer entry FORMAT remains the provenance template.

### Test Landscape
**Test Landscape:** defer has explicit ACs (AC-1 six required fields, AC-2 verbatim REFUSED string, AC-3 `--global` target, AC-4 structured skips confirm). No unit harness; verified by spec/qa/review-board. The flywheel registry-write path should likewise carry per-AC independent-test recipes (e.g. "given unwritable patterns.yaml, the `[FLYWHEEL-DEGRADED]` marker is emitted and execute is not blocked").

### Pattern Catalog
**Pattern Catalog:**
defer entry format (the provenance template `patterns.yaml` occurrences should mirror):
```markdown
### [Deferred via /spec-flow:defer] <finding-summary> — YYYY-MM-DD

**Source:** `<prd-slug>/<piece-slug>` phase `<phase-id>` (agent: `<agent-name>`)
**Finding (verbatim):** <finding-text>
**Why this does not block <piece-slug>'s goals:** <operator-rationale>
**Captured:** YYYY-MM-DD
```
Existing flywheel-relevant FO already parked in `docs/prds/exec-ready/backlog.md` (the spec MUST fold these):
```
FO-1: Configurable spike_threshold key (fold into flywheel-repo spec)
FO-2: Confirm-then-n recording for admission-heuristic calibration (fold into flywheel-repo spec)
FO-3: Cross-piece resolved-spike index (fold into flywheel-repo spec or follow-on piece)
... plus: "add 'unmarked execute-time discovery' as a first-class flywheel pattern-type:
each Step 6c discovery event that was NOT a [SPIKE]-routed resolution increments a
per-plan-quality counter in docs/patterns.yaml"
```
`.discovery-log.md` row format (audit trail every Step 6c resolution appends — the flywheel proposal/rejection should leave a comparable trail):
```markdown
| Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |
|---|---|---|---|---|---|
| phase_3 | requires-amendment | qa-phase | Auth helper missing X | amend | abc1234 chore(plan): amend — ... |
```

## Cluster 4 — `.spec-flow.yaml` config conventions (`flywheel_threshold` house style)

### File Inventory
**File Inventory:** `.spec-flow.yaml` (repo root, live config, ~110 lines) and `plugins/spec-flow/templates/pipeline-config.yaml` (the template shipped with the plugin, the canonical reference for documented keys — note it carries the newer `model_policy`, `qa_max_iterations`, `default_branch` keys that the live file does not yet have).

### Dependency Map
**Dependency Map:** Read at execute Step 0 / Phase Scheduler and by skills like defer (Step 0). New keys must be added to BOTH files. The template is the canonical documentation source. The flywheel must add `flywheel_threshold` (default 2) following the `auto | <int>` idiom of `qa_max_iterations`. The PRD/backlog also flag possible siblings (`spike_threshold` from spike-agent FO-1) — design the comment block so the threshold key reads consistently with `qa_max_iterations`. Backward-compat (NN-C-003): absent `flywheel_threshold` ⇒ default 2; the flywheel is non-blocking so an absent key never breaks execute.

### Test Landscape
**Test Landscape:** No parser test; the key is "tested" by being read at the threshold-check site and by an independent-test AC (e.g. "set `flywheel_threshold: 3`; a pattern with 2 occurrences does NOT trip; 3 does"). Existing keys document the default inline in a comment block — the AC should assert the documented default matches the code-path default (2).

### Pattern Catalog
**Pattern Catalog:**
House-style key documentation (the `auto | <int>` circuit-breaker idiom `flywheel_threshold` should follow):
```yaml
# qa_max_iterations: configurable QA fix-loop circuit-breaker limit (new in v5.6.0)
#   auto  — resolve per piece track: 5 for doc-as-code/Implement pieces ...
#   <int> — explicit cap applied uniformly to all five QA-agent fix-loops
qa_max_iterations: auto
```
Multi-value behavioral knob idiom (default flagged inline):
```yaml
# refactor: controls Step 5 (Refactor) dispatch
#   auto    — skip when Build reports oracle clean ... (default)
#   always  — always run Refactor
#   never   — never run Refactor ...
refactor: auto
```

## Cluster 5 — Spike-agent piece (Step 6c neighbor + reference-doc + version-sync model)

### File Inventory
**File Inventory:** `docs/prds/exec-ready/specs/spike-agent/spec.md` (~170 lines, just merged as spec-flow 5.7.0); `plugins/spec-flow/reference/spike-agent.md` (4.7K — the canonical reference-doc the flywheel's `reference/flywheel.md` should structurally imitate); `plugins/spec-flow/agents/spike.md` (the Opus spike agent); `plugins/spec-flow/reference/coordinator-contract.md` (model-policy table cited from execute). Spike artifacts live at `docs/prds/<prd-slug>/specs/<piece-slug>/spikes/<id>.md`.

### Dependency Map
**Dependency Map:** spike-agent wired TWO call sites into Step 6c: ROLE 1 (`[SPIKE]` resolve at Step 1c) and ROLE 2 (scope spike above the 50% diff-ratio gate before `plan-amend`). The flywheel sits ALONGSIDE this at the same Step 6c juncture but is orthogonal: the spike-agent governs *whether/how a change amends the plan*; the flywheel governs *whether a recurring finding is counted + hardened*. The 50% diff-ratio gate (`reference/spike-agent.md` `## Threshold reuse`, no new config key) is the precedent the flywheel's `flywheel_threshold` deliberately diverges from (the flywheel DOES add a config key, because a count-threshold is conceptually different from a diff-ratio). The soft-checkpoint amendment budget (5 total / 1 spec, `## Soft-checkpoint budget`) is explicitly kept by spike-agent as "the flywheel's 'this piece was under-scoped' signal" — i.e. amendment-count is itself a candidate flywheel input. spike-agent's reference doc + commit/version conventions are the closest template for this piece.

### Test Landscape
**Test Landscape:** spike-agent verified via spec ACs (11 ACs, AC-9 = version-sync grep recipe) + qa-plan + review-board spec-compliance enforcing NN-P-002 no-bypass. The flywheel will follow the same verification model: spec ACs with independent-test recipes + adversarial gates; NN-P-004 (operator-gated, no silent write) is the analog of NN-P-002's no-bypass invariant for the spec-compliance reviewer to check.

### Pattern Catalog
**Pattern Catalog:**
Reference-doc preamble (single-source-of-truth + Cited-by — flywheel.md should open this way):
```
Single source of truth for the spike agent (plugins/spec-flow/agents/spike.md), its two modes,
the spike-artifact schema ... Cited by plugins/spec-flow/agents/spike.md,
plugins/spec-flow/skills/execute/SKILL.md (Step 6c ...) ... Definitions live here and nowhere else.
```
Spike-artifact schema (bold-label block schema — a model for the patterns.yaml occurrence record / the proposal artifact):
```
**Mode:** `resolve` or `scope`
**Trigger:** the unknown or change text
**Classification:** (scope mode only) one of: `blocking-on-current` | `blocking-on-later: <phase-id>` | `additive: <after-phase-id>`
**Scope / Task list:** enumerated task list
**Resolution:** (resolve mode) the concrete answer to the unknown
```
spike-agent In-Scope version-bump line (the flywheel's equivalent obligation):
```
- **Plugin version bump** 5.6.0 → 5.7.0 across all four version-bearing files + a CHANGELOG.md section, with a sync-verify on touch.
```

## Cluster 6 — Reference-doc conventions + skill citation style

### File Inventory
**File Inventory:** `plugins/spec-flow/reference/` (17 docs). Closest structural models for a new `reference/flywheel.md`: `coordinator-contract.md` (4.9K — `## Model Policy`, `## Coordinator Return Discipline`, `## Resume-Critical State`), `spike-agent.md` (4.7K), `research-artifact.md` (7.7K — schema + location + marker contract + return contract, a strong model since the flywheel also defines a marker `[FLYWHEEL-DEGRADED]` and a registry schema). `CLAUDE.md` for the plugin lists the pipeline and entry-point skills.

### Dependency Map
**Dependency Map:** Skills/agents cite reference docs by full path + `## Heading` anchor (e.g. "see `plugins/spec-flow/reference/spike-agent.md` `## Threshold reuse`"). The pattern is: keep the SKILL lean, push mechanics/schemas/contracts into one reference doc, cite by anchor. `research-artifact.md` is explicitly "the single source of truth … cited by [agent] and [two skills]; any schema detail, marker definition, or return-contract rule lives here and nowhere else." The flywheel should create exactly one `reference/flywheel.md` holding: the `docs/patterns.yaml` schema, stable-ID scheme, match-proposal + confirm flow, count/threshold/batched-routing mechanics, the `[FLYWHEEL-DEGRADED]` marker contract, and the `flywheel_threshold` key — cited from execute/SKILL.md (Step 6c hook), the reflection agents (if they gain a recording note), and reused by the flywheel-global piece.

### Test Landscape
**Test Landscape:** Reference docs are prose contracts; "tested" by being the cited authority and by review-board consistency checks. NFR-004 ("documentation as source of truth") makes the reference doc itself the contract.

### Pattern Catalog
**Pattern Catalog:**
Marker-contract section shape from `research-artifact.md` (the `[FLYWHEEL-DEGRADED]` marker should be defined with an identical trigger/emitter/placement structure):
```markdown
### `[RESEARCH-UNAVAILABLE: <reason>]`
Emitted by the **spec** skill. Triggers when ANY of the following occur: ...
The marker is **non-blocking**: the spec skill logs it inline and continues ...
```
`## See also` footer (cross-reference convention to reproduce):
```
## See also
- plugins/spec-flow/agents/spike.md
- plugins/spec-flow/skills/execute/SKILL.md
- plugins/spec-flow/agents/plan-amend.md
```

## Cluster 7 — Version / marketplace sync (NN-C version-bump obligations)

### File Inventory
**File Inventory:** The FOUR version-bearing files (per `plugins/spec-flow/docs/releasing.md`): (1) `plugins/spec-flow/plugin.json`, (2) `plugins/spec-flow/.claude-plugin/plugin.json`, (3) `.claude-plugin/marketplace.json` (spec-flow entry), (4) `plugins/spec-flow/CHANGELOG.md` (prepend `## [X.Y.Z] — YYYY-MM-DD`). All currently at **5.7.0**. Also: `plugins/spec-flow/docs/releasing.md` (the grep recipe + "why four files"), `plugins/spec-flow/hooks/copilot-hooks.json` and `plugins/spec-flow/skills/execute/SKILL.md` contain version-ish strings but are NOT the four canonical version-bearing files.

### Dependency Map
**Dependency Map:** NN-C-001 (version ⇄ marketplace sync), NN-C-007 (CHANGELOG Keep-a-Changelog), NN-C-009 (always bump, all files, per-semver scope). A new capability (the flywheel) is a MINOR bump (NN-C-003): 5.7.0 → 5.8.0. All four files must print the same version (the releasing.md grep recipe is the independent test). The flywheel piece's final phase must bump all four + add a CHANGELOG `### Added` section (new `docs/patterns.yaml` registry, `reference/flywheel.md`, `flywheel_threshold` key, `[FLYWHEEL-DEGRADED]` marker, Step 6c flywheel-recording hook). Charter human-gates (CLAUDE.md): AI must NOT `git push` / `gh pr create` / `gh pr merge` — the piece commits but never pushes/PRs.

### Test Landscape
**Test Landscape:** AC-9-style grep recipe (from spike-agent): `grep '"version"' plugins/spec-flow/plugin.json` + the two other JSONs + CHANGELOG top section must all print the same value. `/release spec-flow` (the `release` skill) handles tag+publish (human-run).

### Pattern Catalog
**Pattern Catalog:**
The four-file sync table (from releasing.md — the flywheel must touch all four):
```
| 1 | plugins/spec-flow/plugin.json | "version" field → new version |
| 2 | plugins/spec-flow/.claude-plugin/plugin.json | "version" field → new version |
| 3 | .claude-plugin/marketplace.json | spec-flow entry "version" → new version |
| 4 | plugins/spec-flow/CHANGELOG.md | Prepend ## [X.Y.Z] — YYYY-MM-DD section |
All four must match exactly. Any drift is a NN-C-009 / NN-C-001 violation.
```
CHANGELOG section shape (the spike-agent 5.7.0 precedent to imitate):
```markdown
## [5.7.0] — 2026-06-07
### Added
- **`agents/spike.md` (Opus spike agent, resolve+scope modes):** ...
### Changed
- **Step 6c amend now scope-spikes above-threshold changes before plan-amend:** ...
```
Marketplace entry (where version 3 lives):
```json
{ "name": "spec-flow", "source": "./plugins/spec-flow",
  "description": "PRD-to-code pipeline ...", "version": "5.7.0", "author": { "name": "Joe" } }
```

## Cluster 8 — Registry / YAML-schema prior art (no patterns.yaml exists yet)

### File Inventory
**File Inventory:** `docs/patterns.yaml` does NOT exist (confirmed absent) — this piece creates it. Existing YAML registries to mirror for house style: `docs/prds/exec-ready/manifest.yaml` (the pieces registry — `schema_version`, `generated`, `last_updated`, `prd_source`, then a `pieces:` list of records with `name`/`slug`/`description`/`prd_sections`/`dependencies`/`status`), and `.spec-flow.yaml` / `templates/pipeline-config.yaml` (config-style YAML with heavy inline comments).

### Dependency Map
**Dependency Map:** The manifest is the closest precedent for a durable, dated, list-of-records YAML registry: it carries a `schema_version` integer, `generated`/`last_updated` ISO dates, a source pointer, and a list of structured records each with a stable `slug`. `patterns.yaml` should likely adopt the same envelope (`schema_version`, dates) + a `patterns:` list where each pattern has a stable ID, description, scope, an `occurrences:` list (each `{piece, date, source}`), a count (derivable as `len(occurrences)`), threshold-state, and a `rejections:` list (each with rationale + date). The `flywheel-global` piece (FR-007) reuses this schema verbatim at a `~/` location adding an `originating_repo` field per occurrence — so the schema must reserve room for that field cleanly (the spec should design the occurrence record so flywheel-global adds one field, not restructures). Stable-ID scheme is an open question (operator-named vs auto-slug vs sequential) — the manifest's human-readable `slug` is a precedent for human-readable stable IDs.

### Test Landscape
**Test Landscape:** No YAML-schema validator in the toolchain (no `yq`/JSON-schema — NN-C-002). Validity is enforced by the LLM agent's native YAML read/write + spec ACs (e.g. "an occurrence record contains piece + date + source"; "count = occurrences length"; "a rejected pattern is not re-proposed"). The degraded-path AC ("unwritable patterns.yaml ⇒ `[FLYWHEEL-DEGRADED]`, execute not blocked, finding still flows to reflection") is the key robustness test.

### Pattern Catalog
**Pattern Catalog:**
manifest.yaml envelope + record shape (the registry-YAML house style to mirror):
```yaml
schema_version: 1
generated: 2026-06-06
last_updated: 2026-06-07
prd_source: "docs/prds/exec-ready/prd.md"

pieces:
  - name: research-unify
    slug: research-unify
    description: |
      One deep codebase-gathering pass ...
    prd_sections: [FR-001, NFR-001, NFR-003, G-1]
    dependencies: []
    status: merged
```
Provenance fields each occurrence should carry (mirroring the defer `**Source:**` line — piece, agent, date):
```
**Source:** `<prd-slug>/<piece-slug>` phase `<phase-id>` (agent: `<agent-name>`)
**Captured:** YYYY-MM-DD
```
