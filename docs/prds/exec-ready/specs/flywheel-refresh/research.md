# Research — exec-ready/flywheel-refresh

## Brainstorm Inference Digest

**Piece purpose.** flywheel-refresh extends the merged flywheel-repo registry (`docs/patterns.yaml`, defined canonically in `plugins/spec-flow/reference/flywheel.md`) with a *lifecycle*: patterns gain `state` (`active`/`hardened`/`archived`), a `last_seen` marker, and a hardening-outcome record (spike artifact ref + landing site). Applying a hardening transitions a pattern `active → hardened`; a post-hardening confirmed occurrence re-opens it to `active` with an `ineffective-hardening` flag (the "did the fix actually work?" check). An operator-gated **refresh pass** proposes archival for stale patterns (configurable window) and clean hardened patterns; archived entries stay in-file (audit) and leave the match-proposal candidate set. Malformed registry → `[FLYWHEEL-DEGRADED: lifecycle unavailable]`, propose nothing, file untouched. Covers FR-015. This is pure doc-as-code / orchestrator-prose work — NO runtime code (NN-C-002).

**Design constraints inferred.**
- This is an EXTEND, not a rewrite. `reference/flywheel.md` is the SSOT (CR-008 / NN-C-008: cite, don't restate). The new lifecycle fields slot into the existing `patterns:` schema (alongside `occurrences`, `rejections`, `hardenings`); the new exclusion-from-candidates and refresh logic slot into the existing `## Threshold + batched proposal` and `## Match + confirm flow` sections; the degraded marker text mirrors the existing `[FLYWHEEL-DEGRADED: repo registry unavailable]`.
- Backward compatibility is mandatory and already AC-stated: registries without the new fields read as `active` (NN-C-003). Mirrors the existing `flywheel_threshold` absent-key-⇒-default pattern.
- `hardenings` ALREADY exists (added in flywheel-repo's final-review amendment `phase_final_amend_1`) with `{date, outcome: resolved|blocked, spike_artifact, amend_commit, at_count}`. flywheel-refresh's `state` transition must reconcile with these existing records — a `resolved` hardening is exactly the `active → hardened` trigger; the `spike_artifact` + `amend_commit` ARE the "hardening outcome (spike ref + landing site)" FR-015 names. The piece likely formalizes a derived/stored `state` over the already-present `hardenings`/`occurrences` data rather than inventing parallel fields.
- Nothing archives silently (NN-P-004): refresh proposals are operator-confirmed, same gate model as the batched hardening proposal.
- Hardening fixes route through the sanctioned spike → plan-amend → re-review loop (NN-P-005, NN-P-002) — flywheel-refresh adds no new fix mechanism; it only changes *which* patterns are eligible and *what state* they carry.

**Open ambiguities to resolve in brainstorm (do NOT answer here):**
1. **Staleness window units** — N pieces, N days, or both? (PRD Open Question, prd.md ~494: "Staleness window for pattern archival — N pieces, N days, or both? — open"). What counts as a "piece" for the window — does the registry track a global piece ordinal, or is it derived from `occurrences[].piece` count / `date` span? No global ordinal exists in the current schema.
2. **`last_seen` representation** — ISO `date` vs piece-ordinal. The existing schema stores per-occurrence `date` (ISO) and `piece` (`<prd>/<piece>` slug); `last_seen` could be the max occurrence `date` (date-window-friendly) or a piece pointer (piece-count-window-friendly). Choice is coupled to ambiguity #1.
3. **Refresh trigger** — end-of-piece Step 4.5 auto-surface (alongside the existing batched hardening proposal), an operator on-demand command, or both? FR-015 says "end-of-piece or on demand". No `commands/` dir and no existing refresh/lifecycle skill exist (see Cluster D) — on-demand would be net-new surface.
4. **`ineffective-hardening` flag** — a stored field on the pattern, or a computed condition surfaced at the next batched review? (Symmetric with the existing `rejections`/`hardenings`-vs-computed-exclusion design.)
5. **Revive mechanism** for archived patterns — how does the operator explicitly revive (un-archive) a pattern back into the candidate set?
6. **FW-2 scope question** — does flywheel-refresh also address FW-2 (registry-integrity lint for schema-valid-but-structurally-wrong registries) given it adds new fields, or is that a separate piece? flywheel-repo's `learnings.md` (line 26) and the manifest's PRD backlog flag FW-1/FW-2/FW-3 as candidates.

## Codebase Conventions

Empirical conventions confirmed by scanning peer components (flywheel-repo + sibling FR pieces):

- **SSOT-and-cite pattern (CR-008 / NN-C-008).** Mechanics are defined ONCE in a `reference/*.md` file; skills cite the section heading and explicitly say "Do NOT restate those rules here." Confirmed at `execute/SKILL.md:1083` ("see `plugins/spec-flow/reference/flywheel.md` ... Do NOT restate ... (CR-008 / NN-C-008)"). flywheel-refresh must add lifecycle to `reference/flywheel.md` and only *cite* it from `execute/SKILL.md`.
- **Schema-open / wire-narrow.** Reserved fields are representable in the schema but emitted by no path until a later piece wires them (e.g. `originating_repo` reserved for flywheel-global, `metric` source_type reserved until FR-010). Pattern for additive, non-restructuring growth.
- **Registry envelope house style.** `docs/patterns.yaml` mirrors `manifest.yaml`: top-level `schema_version` / `generated` / `last_updated` + a list under a plural key, each item a stable kebab `id`. Lifecycle fields follow this (lowercase snake_case keys, inline `#` comment enumerating valid values).
- **Degraded-marker convention.** Single bracketed orchestrator line `[<NAME>-DEGRADED: <reason>]` / `[<NAME>-UNAVAILABLE: <reason>]` / `[<NAME>-ABSENT]`; non-blocking; no write; pipeline proceeds. flywheel-refresh's `[FLYWHEEL-DEGRADED: lifecycle unavailable]` follows this exactly (note the distinct reason suffix vs flywheel-repo's `repo registry unavailable`).
- **Config-key documentation (CR-007).** Keys live in the TRACKED `plugins/spec-flow/templates/pipeline-config.yaml` (NOT gitignored `.spec-flow.yaml`) with a multi-line `# <key>:` comment block: purpose, valid values, default, "Absent ⇒ <default> (non-blocking; NN-C-003)", and a `See plugins/spec-flow/reference/...` pointer. A `staleness_window` (or similar) key would be added here in that exact style.
- **Operator-gate convention (NN-P-004).** Every registry write is preceded by an operator confirmation prompt; matches/proposals are LLM-proposed, human-confirmed. "Nothing auto-applied; nothing silently deferred."
- **Spec structure (mirror target).** flywheel-repo `spec.md` shape: `# Spec` → `## Goal` → `## In Scope` → `## Out of Scope / Non-Goals` → `## Requirements` (`### Functional Requirements` SF-N, `### Non-Functional Requirements`, `### Non-Negotiables Honored`, `### Coding Rules Honored`) → `## Acceptance Criteria` (AC-N, Given/When/Then) → `## Technical Approach` (with a "naming-collision note" callout + schema block) → `## Testing Strategy` (grep recipes + manual smoke scenarios + adversarial-gate verification; doc-as-code = no test runner) → `## Integration Coverage` (boundary-contract audit by `review-board-integration`, no mocked doubles) → `## Explicitly Out of Scope / Deferred`. flywheel-refresh's spec should mirror this.
- **Version bump (NN-C-009).** Any change under `plugins/<plugin>/` bumps the plugin version in all version-bearing files (flywheel-repo shipped as 5.8.0).

## Flywheel SSOT (reference/flywheel.md)

### File Inventory
**File Inventory:** `plugins/spec-flow/reference/flywheel.md` (145 lines, the file flywheel-refresh EXTENDS). Sections: `## Registry schema` (L5), `## Count rule` (L37), `## Match + confirm flow (no silent write)` (L50), `## Source taxonomy` (L61), `## Threshold + batched proposal` (L73), `## Hardening dispatch (reuse)` (L95), `## Rejection rule` (L107), `## Degraded path` (L122), `## No secrets` (L135), `## See also` (L139).

### Dependency Map
**Dependency Map:** Cited by `execute/SKILL.md` (Step 6c record/match hook + Step 4.5 batched proposal). Reused by `flywheel-global` (FR-007). Depends on `agents/spike.md` (scope mode) + `agents/plan-amend.md` for the hardening dispatch. flywheel-refresh edits THIS file (schema + threshold/match sections + degraded path) and only cites it from execute. Lifecycle `state` derives from existing `hardenings` (`outcome: resolved` ⇒ hardened) and `occurrences[].date`/`piece` (⇒ `last_seen` / staleness). New `state`/`last_seen`/archival slot into `## Registry schema` (L27 field rules) + a new lifecycle section; candidate-exclusion of `archived` slots into `## Match + confirm flow` (L50) AND the batched-proposal exclusion list (L83–91); the re-open-on-recurrence rule pairs with the existing resolved-exclusion rule (L86).

### Test Landscape
**Test Landscape:** No test runner (NN-C-002, charter-tools). Verification = grep/inspection recipes against shipped prose + manual smoke scenarios + adversarial gates (`qa-spec`, `qa-plan`, Final Review `review-board-spec-compliance` / `review-board-integration`). flywheel-repo modeled exactly this in its `## Testing Strategy`.

### Pattern Catalog
**Pattern Catalog:** Current schema item with the `hardenings`/`rejections` lists (where lifecycle fields will slot):

```yaml
patterns:
  - id: stale-charter-snapshot         # stable kebab slug; LLM-proposed, operator-confirmed
    description: charter_snapshot drift not re-checked before authoring
    scope: charter                      # charter | qa | prd
    occurrences:
      - piece: exec-ready/plan-concrete
        date: 2026-06-07
        source: "reflection-future-opportunities: ..."
        source_type: reflection-finding # reflection-finding | execute-discovery | metric
    rejections: []                      # each: { date, rationale, rejected_at_count }
    hardenings: []                      # each: { date, outcome (resolved|blocked), spike_artifact, amend_commit, at_count }
```

Existing batched-proposal exclusion rules (the re-open and archival logic pair with these):

```
A pattern at count ≥ threshold is excluded when ANY hold:
  1. rejections entry and count ≤ rejected_at_count
  2. hardenings entry outcome: resolved and count ≤ at_count   ← the "hardened, clean window" basis
  3. hardenings entry outcome: blocked  and count ≤ at_count
Evaluate each rule against the highest (most-recent) at_count / rejected_at_count.
```

Degraded-marker text to mirror (note distinct reason suffix for FR-015):

```
[FLYWHEEL-DEGRADED: repo registry unavailable]   ← existing (FR-006)
[FLYWHEEL-DEGRADED: lifecycle unavailable]       ← new (FR-015), malformed registry at refresh
```

## Execute wiring (skills/execute/SKILL.md)

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/execute/SKILL.md` (2082 lines). Flywheel anchors: `#### Flywheel pattern recording (FR-006)` at L1079 (Step 6c record/match hook + degraded path L1085–1091); `### Step 4.5: Reflection` at L1846 (end-of-piece, after Final Review board + Human Sign-Off, before merge); `#### Routing reflection findings through Step 6c` at L1879; `#### Flywheel batched hardening proposal (FR-006)` at L1913 (reads `flywheel_threshold`, surfaces the batched proposal). NOTE the naming collision: a SEPARATE per-phase `### Step 4.5: Completing-phase [Integration-Test] sub-cycle` at L793 — the flywheel juncture is the END-OF-PIECE Reflection one (L1846/L1913), NOT the per-phase L793.

### Dependency Map
**Dependency Map:** L1083 / L1091 cite `reference/flywheel.md` and say "Do NOT restate (CR-008 / NN-C-008)." The refresh pass (FR-015) would fire at the existing end-of-piece Step 4.5 juncture — adjacent to / inside the L1913 batched hardening proposal (after recording, alongside or after the hardening proposal). Match-candidate exclusion of `archived` patterns must be enforced at BOTH the per-phase Step 6c match site (L1079–1081, the "propose a match" step) and is conceptually defined in `reference/flywheel.md` `## Match + confirm flow`. If on-demand refresh is chosen, that's a net-new surface (no host exists — see Cluster D). The `step-4.5-reflection` `.discovery-log.md` source-phase token (L1883) is the convention any refresh-originated discovery row would reuse.

### Test Landscape
**Test Landscape:** Wiring phases (L1079, L1913 edits) are the ones flywheel-repo's two-tier QA dispatched Opus `qa-phase` on (behavioral correctness not grep-assertable); structurally-verifiable phases (reference-doc, config-key, version-bump) were skip-eligible. Same split expected here.

### Pattern Catalog
**Pattern Catalog:** The degraded-path block flywheel-refresh mirrors for its lifecycle marker:

```
**Degraded path.** If `docs/patterns.yaml` is unwritable or unparseable, the flywheel
emits the single verbatim line:

[FLYWHEEL-DEGRADED: repo registry unavailable]

No registry write is performed. Execute is NOT blocked or failed. The triggering finding
still flows through its normal Step 6c triage / reflection resolution path unchanged.
```

The batched-proposal anchor where the refresh pass would attach (L1913):

```
#### Flywheel batched hardening proposal (FR-006)
After this piece's reflection findings have been recorded through the Step 6c flywheel hook
(above), read `flywheel_threshold` from `.spec-flow.yaml` ... Surface one batched proposal
listing every pattern whose distinct-piece count ≥ flywheel_threshold AND that is not
currently excluded by a rejection, a resolved hardening, or a blocked hardening ...
```

## Config + docs (pipeline-config.yaml)

### File Inventory
**File Inventory:** `plugins/spec-flow/templates/pipeline-config.yaml` — the TRACKED committed config source (the live `.spec-flow.yaml` is gitignored; flywheel-repo's PR-FW-2 learning: a config-file AC must grep `.gitignore`). `flywheel_threshold: 2` documented at L82–86. A `staleness_window` (or equivalent) refresh key would be added here in the same CR-007 comment style.

### Dependency Map
**Dependency Map:** Keys are read at runtime from `.spec-flow.yaml` (absent ⇒ documented default, NN-C-003); the template documents them. The flywheel section sits between `reflection: auto` (L80) and `metrics: auto` (L93). A new refresh/staleness key belongs adjacent to `flywheel_threshold`. Each key's comment ends with a `See plugins/spec-flow/reference/flywheel.md` pointer.

### Test Landscape
**Test Landscape:** Verified by grep recipe (key present + comment documents purpose/values/default) + the version-sync check. flywheel-repo's AC-10 ("config key documented") is the template to mirror; PR-FW-2 says qa-spec should grep `.gitignore` for any config-file AC.

### Pattern Catalog
**Pattern Catalog:** The exact CR-007 comment+key house style to mirror for a staleness key:

```yaml
# flywheel_threshold: repo-level self-hardening flywheel — occurrence count at which a pattern's
#   batched hardening proposal is surfaced at end-of-piece reflection (new in v5.8.0; FR-006).
#   <int> — distinct-piece occurrence count threshold (default 2). Absent ⇒ 2 (non-blocking; NN-C-003).
#   See plugins/spec-flow/reference/flywheel.md `## Threshold + batched proposal`.
flywheel_threshold: 2
```

## On-demand command surface (skills/)

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/` contains: `charter/`, `defer/`, `execute/`, `intake/`, `manifest/`, `plan/`, `prd/`, `review-board/`, `small-change/`, `spec/`, `status/`. There is **no `commands/` directory** in `plugins/spec-flow/`. No existing skill is named refresh/lifecycle/flywheel.

### Dependency Map
**Dependency Map:** FR-015 says the refresh pass fires "end-of-piece or on demand." End-of-piece has a natural host (execute Step 4.5, L1913). On-demand has NO existing host: candidates would be (a) a flag/sub-mode on `status` (read-only dashboard — but refresh WRITES on confirm, which conflicts with status's read-only posture), (b) a flag on `manifest` (query/mutate manifest, not patterns.yaml), (c) `defer` (sole backlog write path — wrong registry), or (d) a NET-NEW skill. Report only — the spec author decides. NN-P-004 requires whatever host carries an operator confirmation gate before any archival write.

### Test Landscape
**Test Landscape:** N/A (no behavior-bearing code). Whichever surface is chosen, verification is grep/inspection of the SKILL.md prose + a manual smoke scenario (operator runs refresh → sees archival proposal → confirms → pattern state flips to archived, stays in-file, leaves candidate set).

### Pattern Catalog
**Pattern Catalog:** `defer` is the closest precedent for a single-purpose registry-writing skill (sole write path, requires `--rationale`, commits itself):

```
- defer: Record a non-blocking finding to backlog.md with provenance. Sole write path
  for improvement-backlog.md and prds/<slug>/backlog.md. Requires --rationale.
```

`status` posture (read-only — a refresh that writes cannot simply fold into it):

```
- status: Pipeline dashboard ... read-only snapshot. Shows PRD coverage, current piece
  state, phase progress, recommends the next spec-flow action.
```

## Prior art / structure (flywheel-repo spec + learnings)

### File Inventory
**File Inventory:** `docs/prds/exec-ready/specs/flywheel-repo/spec.md` (the structural mirror target) and `docs/prds/exec-ready/specs/flywheel-repo/learnings.md` (FW-1/FW-2/FW-3 + hardening-schema lessons). Plus `docs/prds/exec-ready/prd.md` (FR-015 ACs at ~L327–333, US-015 at ~L325, NN-P-004 at L552, NN-P-005 at L559, Open Question "staleness window" at ~L494).

### Dependency Map
**Dependency Map:** flywheel-refresh `depends_on: [flywheel-repo]` (merged); it gates flywheel-global (lifecycle mechanics must exist before a second registry is built). flywheel-repo's `learnings.md` L26 explicitly hands off to flywheel-global AND flags that `hardenings` undercounts the "one added field" reuse story — flywheel-refresh inherits this tension because it formalizes `state` over `hardenings`. learnings PR-FW-1/2/3 are direct inputs: name the schema field that carries any recorded outcome (PR-FW-1), grep `.gitignore` for config ACs (PR-FW-2), grep-verify each concrete dispatch identifier (PR-FW-3).

### Test Landscape
**Test Landscape:** flywheel-repo's `## Testing Strategy` is the template: doc-as-code ⇒ no runner; per-AC grep recipes + per-AC manual smoke scenarios (with stated expected outcome) + adversarial-gate verification naming which board reviewer audits which AC. `## Integration Coverage` lists each wired boundary as `inside:{...}; boundary contract: ...; verified by review-board-integration; AC-N`. flywheel-refresh should produce both sections in the same shape (e.g. an Integration row for flywheel→`docs/patterns.yaml` lifecycle read/write, and for the refresh→archival-proposal→operator-confirm path).

### Pattern Catalog
**Pattern Catalog:** flywheel-repo AC house style (Given/When/Then, numbered, grep- or smoke-verifiable) to mirror:

```
AC-5: Given `flywheel_threshold: N`, When the end-of-piece Step 4.5 batched-proposal fires,
Then only patterns with distinct-piece count ≥ N are listed ...
AC-10: Given `.spec-flow.yaml` has no `flywheel_threshold` key, Then the threshold defaults to 2 ...
```

The hardening-schema lesson that directly shapes flywheel-refresh's `state` field (learnings L20):

```
Enumerate the schema home for any "record-this-outcome" behavior at spec/plan time.
The hardening-schema gap traced to a single spec omission: "the accepted outcome … is
recorded against the pattern" named no concrete schema field and no re-proposal exclusion
rule. (PR-FW-1)
```

The flywheel-global handoff note flagging the FW-2 lint candidate (learnings L26):

```
A registry-integrity lint for schema-valid-but-structurally-wrong patterns.yaml is also a
candidate. (FW-1/2/3 in the PRD backlog.)
```

## Charter constraints in play

### File Inventory
**File Inventory:** Binding rules sourced from `.claude/skills/charter-non-negotiables/SKILL.md` (NN-C-002 L17, NN-C-003 L24, NN-C-008 L59, NN-C-009 L67+), `.claude/skills/charter-coding-rules/SKILL.md` (CR-007 L48, CR-008 L54, CR-009 L60), and `docs/prds/exec-ready/prd.md` (NN-P-004 L552, NN-P-005 L559 — the NN-P rules live in the PRD, not the charter skills).

### Dependency Map
**Dependency Map:** Each binding rule maps to a flywheel-refresh obligation — NN-C-002: markdown+config only, no runtime code. NN-C-003: legacy registries without lifecycle fields read as `active`; new config keys are optional with documented defaults. NN-C-008: agent prompts (if any) self-contained; no "Do NOT restate SSOT" violations. NN-P-004: every lifecycle write (state transition, archival) operator-gated, nothing silent. NN-P-005: hardening fixes via the Opus spike → plan-amend loop, no silent upgrade. CR-007: any new config key documented inline in `pipeline-config.yaml`. CR-008: thin orchestrator — cite `reference/flywheel.md`, don't restate. CR-009: heading hierarchy (one H1, H2 sections, H3 subsections; never skip levels).

### Test Landscape
**Test Landscape:** Verified by Final Review board — `review-board-spec-compliance` checks NN-P-004 no-silent-write gate against the diff; `review-board-architecture` inspects the diff for runtime-dependency artifacts (NN-C-002); `review-board-integration` traces wired lifecycle paths.

### Pattern Catalog
**Pattern Catalog:** The two load-bearing verbatim rules for this piece:

```
NN-C-003: Within a single major version, plugins must not break existing user projects.
Config keys may gain new optional fields; existing fields must retain their meaning.
```

```
NN-P-004: Both registries ... are written only after operator confirmation at triage.
Pattern matches are LLM-proposed, human-confirmed. ... Nothing is auto-applied; nothing
is silently deferred.
```

```
CR-008: Skills orchestrate ... A skill that contains implementation logic beyond
orchestration ... is a separation-of-concerns violation.  [⇒ cite reference/flywheel.md]
```
