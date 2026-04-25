# Charter Stage + Codified `docs/` Structure — Design Spec

**Date:** 2026-04-20
**Status:** Proposal (pending review — do not auto-commit)
**Target version:** spec-flow v2.0.0 (major — introduces new pipeline stage, breaking folder-layout changes, two-namespace NN model)
**Prior conversation:** brainstorm session establishing decisions A (Socratic charter), B (folder of focused files), A1+B3 (artifact-first layout + hybrid research), B (two NN namespaces).

---

## 1. Goal

Introduce a new **pre-PRD charter stage** to spec-flow that produces a codified, binding set of project-wide constraints (architecture, non-negotiables, tools, processes, flows, coding rules) via Socratic dialogue. Simultaneously codify the `docs/` folder layout — which today is implicit and inconsistent — into a documented structure that every downstream skill reads from and writes to.

Charter content becomes binding context for every subsequent PRD, spec, plan, implementation, and review. Specs cite specific charter entries (`NN-C-xxx`, `NN-P-xxx`, `CR-xxx`) and QA agents check compliance.

## 2. Non-goals

- Redesigning the existing TDD/Implement track split
- Changing agent naming or the 5-agent review-board shape
- Altering existing `.spec-flow.yaml` keys (only new `charter:` block added)
- Introducing new model assignments (Opus for QA, Sonnet for implementer unchanged)
- Building divergence-resolution automation (flagged only; human resolves)
- Fetching external URL content for verification (v1 trusts the link)

## 3. Folder layout

Hybrid: artifact-first for project-wide artifacts, per-piece co-location for piece-scoped artifacts.

```
docs/
├── charter/                          NEW: project-wide binding constraints
│   ├── architecture.md
│   ├── non-negotiables.md            NN-C-001… (project-wide)
│   ├── tools.md
│   ├── processes.md
│   ├── flows.md
│   └── coding-rules.md               CR-001… (numbered, citable)
│
├── prd/
│   ├── prd.md                        FR/NFR/SC + NN-P-001… (product-specific)
│   └── manifest.yaml                 piece tracking (moved from docs/ root)
│
├── specs/
│   └── <piece>/
│       ├── spec.md                   per-piece spec
│       ├── plan.md                   per-piece plan (co-located with spec)
│       ├── learnings.md              per-piece retro
│       └── research/                 piece-scoped research (plan-exploration + user drops)
│
├── research/
│   └── <topic>/                      OPTIONAL v1: standalone cross-piece research (scaffolded, not wired)
│
├── backlog/
│   └── backlog.md                    reflection stage output (was docs/improvement-backlog.md)
│
└── archive/                          legacy artifacts preserved
```

Migration from legacy layout:
- `docs/prd.md` → `docs/prd/prd.md`
- `docs/manifest.yaml` → `docs/prd/manifest.yaml`
- `docs/improvement-backlog.md` → `docs/backlog/backlog.md`
- Per-piece artifacts already match new layout (`docs/specs/<piece>/…`)

## 4. Charter artifact structure

Six focused files in `docs/charter/`, each with `last_updated: YYYY-MM-DD` front-matter.

### 4.1 Numbered-entry files

`non-negotiables.md` and `coding-rules.md` use structured entries with a `Type` field.

**Entry types:**
- **`Rule`** — inline, self-contained. The statement IS the binding rule.
- **`Reference`** — defers to external content (URL or local file path). `Source` is what specs/plans/agents must consult.

**Entry schema:**
```markdown
### NN-C-007: No PII in logs
- **Type:** Rule
- **Scope:** All logging output
- **Rationale:** GDPR compliance (legal requirement)
- **How QA verifies:** grep for PII fields in structured log calls; architecture reviewer checks

### CR-001: Follow Maven standard directory layout
- **Type:** Reference
- **Source:** https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html
- **Scope:** All Java modules
- **Rationale:** Build tooling and CI assume standard layout
```

### 4.2 Narrative files

`architecture.md`, `tools.md`, `processes.md`, `flows.md` use narrative + bullets. Free to embed external links inline. Optional top-of-file `## External References` block for binding external docs (not numbered — context, not citable atoms).

### 4.3 Per-file content

| File | Content |
|---|---|
| `architecture.md` | Top-level layers, dependency direction, component ownership, module boundaries |
| `non-negotiables.md` | `NN-C-001…` entries (structured) |
| `tools.md` | Language(s) + versions, framework(s), test runner, linter, formatter, package manager, CI, approved/banned libraries |
| `processes.md` | Branching model, review policy, release cadence, CI gates, incident response |
| `flows.md` | Request flow, auth flow, data-write path, other critical flows, diagrams |
| `coding-rules.md` | `CR-001…` entries (structured, numbered) + style conventions |

## 5. `/spec-flow:charter` skill

New skill at `plugins/spec-flow/skills/charter/SKILL.md`. Three auto-detected modes.

### 5.1 Modes

| Mode | Trigger | Behavior |
|---|---|---|
| **Bootstrap** | `docs/charter/` doesn't exist | Full Socratic → write six files → QA → sign-off |
| **Update** | `docs/charter/` exists, plain invocation | Scoped Socratic on selected files → QA touched files only |
| **Retrofit** | Legacy `docs/prd.md` or unprefixed `NN-xxx` detected | Reclassify existing NN → migrate layout → rewrite specs |

### 5.2 Bootstrap phases

**Phase 1.1 — Auto-detect signals:**
- `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`
- Build manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`
- Lint/TS configs: `tsconfig.json`, `.eslintrc*`, `.ruff.toml`, `.prettierrc*`
- CI: `.github/workflows/*`, `.pre-commit-config.yaml`
- Existing `docs/architecture/` or `docs/adr/`
- Recent `git log --oneline -n 50`

**Phase 1.2 — Prompt user for additional sources:**
- **Local paths** — folders/files in this repo I wouldn't auto-detect (e.g., `internal/handbook/`)
- **External URLs** — team wikis, Notion pages, engineering handbooks, RFCs
- **Sibling repos** — shared convention repos (user provides local path)

For local paths: read with Glob/Grep/Read and fold into signal summary.
For external URLs: attempt WebFetch; if fails, record as pending reference and ask user to summarize during Socratic.

**Phase 1.3 — Confirm combined signal summary** with user before Socratic begins.

**Phase 2 — Socratic by file, one question at a time:**
1. `tools.md`
2. `architecture.md`
3. `flows.md`
4. `coding-rules.md` (numbered `CR-xxx` entries, Rule or Reference type)
5. `processes.md`
6. `non-negotiables.md` (numbered `NN-C-xxx` entries, structured form)

Unresolved questions → `[NEEDS CLARIFICATION]` markers → QA must-fix.

**Phase 3 — Write files** to `docs/charter/` (main branch, no worktree — charter is project-global).

**Phase 4 — QA loop** via `qa-charter` agent (see section 6).

**Phase 5 — Human sign-off.**

**Phase 6 — Commit per file** so `git blame` is useful:
```
charter: add architecture
charter: add tools
charter: add non-negotiables
...
```

**Phase 7 — Doctrine wiring** — update session-start hook to conditionally load charter files per `.spec-flow.yaml` `charter.doctrine_load` config.

### 5.3 Update mode

1. User: "update the charter" / "change non-negotiables".
2. Skill lists six files, asks which to edit.
3. Scoped Socratic on selected files.
4. QA re-runs on touched files only.
5. Each changed file → separate commit.
6. `last_updated` bumped.
7. `/spec-flow:status` flags diverged in-flight pieces.

### 5.4 Retrofit mode

See section 9 for full migration pipeline.

## 6. `qa-charter` agent

New agent at `plugins/spec-flow/agents/qa-charter.md`. Opus, read-only, adversarial.

### 6.1 Review checks

**Per-file:**
1. Completeness (required sections, no empty headings)
2. No surviving `[NEEDS CLARIFICATION]` markers
3. Structured-entry schema compliance (`Type`, `Scope`, `Rationale`; `Reference` entries have `Source`)
4. Reference surface validity (URL format or local path exists — no content fetching)
5. `last_updated: YYYY-MM-DD` front-matter present

**Cross-file:**
6. Tools ↔ coding-rules consistency (language/framework alignment)
7. Tools ↔ processes consistency (CI platform alignment)
8. Architecture ↔ flows consistency (flows respect declared layers)
9. NN-C ↔ architecture consistency (layer/boundary rules align)
10. CR ID sequentiality and uniqueness

**Scope/meta:**
11. Binding-vs-advisory classification (non-negotiables must be genuinely binding)
12. Specificity (rules must be verifiable)
13. Duplication across files

**Retrofit-mode additions:**
14. Re-keying completeness (every original `NN-xxx` now in `NN-C` or `NN-P`, none dropped)
15. Spec back-reference integrity (pieces citing old NN-xxx now cite new namespaces)

### 6.2 QA loop

Reuses existing pattern from `qa-spec` / `qa-plan`:

1. **Iter 1** (full): Dispatch with `Input Mode: Full` + charter files + signals + user sources.
2. **Iter 2+** (focused): If must-fix found → `fix-doc` produces diff → re-dispatch `qa-charter` with `Input Mode: Focused re-review` + prior findings + fix diff. No full re-send.
3. **Circuit breaker:** 3 iterations max → escalate to human.
4. **Empty-diff escape:** If `fix-doc` reports all blocked → escalate.
5. Clean iteration → human sign-off.

Reuses existing `fix-doc.md` agent — no `fix-charter.md` needed.

## 7. Non-negotiables namespaces

Two namespaces, both first-class throughout the pipeline.

- **`NN-C-xxx`** (Charter): project-wide binding rules. Security, compliance, architecture, tooling. Live in `docs/charter/non-negotiables.md`. Rarely change.
- **`NN-P-xxx`** (Product): product-specific binding rules. Tied to current PRD. Live in `docs/prd/prd.md` under `## Non-Negotiables (Product)` section. Grow with each PRD import.

Both use structured entry schema (Type, Scope, Rationale, How QA verifies). Both cited in spec's `### Non-Negotiables Honored` section.

**Coding rules** (`CR-xxx`) are a separate citable namespace in `docs/charter/coding-rules.md`. Cited in spec's `### Coding Rules Honored` section.

**Write-once IDs:** numbers never re-key. Retired entries stay as tombstones (see section 10).

## 8. Pipeline wiring

How every downstream skill, template, and agent integrates with charter.

### 8.1 Templates

**`templates/prd.md`:**
- Remove existing `## Non-Negotiables` section
- Add `**Charter:** docs/charter/` reference line near top
- Add `## Non-Negotiables (Product)` section with structured `NN-P-xxx` entries

**`templates/spec.md`:**
- Rename `### Non-Negotiables (from PRD)` → `### Non-Negotiables Honored`
- Split into **Project (NN-C)** and **Product (NN-P)** subsections
- Spec must enumerate every NN-C and NN-P its scope touches
- Add `### Coding Rules Honored` section citing relevant `CR-xxx`
- Add `charter_snapshot:` front-matter capturing charter file dates at write time

**`templates/plan.md`:**
- Each phase block gains **Charter constraints honored in this phase** slot citing `NN-C`/`NN-P`/`CR` with "how honored" lines
- Top-of-plan `**Charter:** docs/charter/` reference line
- Add `charter_snapshot:` front-matter

### 8.2 Skills

**`skills/prd/SKILL.md`:**
- Charter prereq check (if `charter.required: true` and `docs/charter/` missing → fail with "run /spec-flow:charter first")
- Import mode: NN extracted → route to NN-P namespace
- Legacy path detect → trigger retrofit flow

**`skills/spec/SKILL.md`:**
- Phase 1 step 3: change `Read docs/architecture/` → `Read docs/charter/` (all six files)
- Phase 1 step 5: scan `docs/charter/non-negotiables.md` (NN-C), `docs/prd/prd.md` (NN-P), `docs/charter/coding-rules.md` (CR)
- Phase 2 adds step: identify which NN/CR entries the piece touches, confirm with user
- Phase 4 QA prompt includes charter files
- Spec write includes `charter_snapshot` front-matter

**`skills/plan/SKILL.md`:**
- Exploration reads `docs/charter/`
- Per-phase charter-constraints slot auto-populated
- `qa-plan` prompt includes charter
- Plan write includes `charter_snapshot`

**`skills/execute/SKILL.md`:**
- `qa-phase` interpolates phase's cited charter entries
- Final review-board: architecture reviewer gains full charter context; spec-compliance reviewer verifies NN/CR claims honored in diff

**`skills/status/SKILL.md`:**
- Top-line `charter: present (last_updated YYYY-MM-DD)` indicator
- Per-piece `⚠ charter diverged` flag with diff summary

### 8.3 Agents

**`agents/implementer.md`:**
- Rule 4 path hint: `docs/architecture/` → `docs/charter/`
- Rule 4 explicitly names NN-C, NN-P, CR as binding entries plan may cite

**`agents/qa-spec.md`, `qa-plan.md`, `qa-phase.md`:**
- Verify cited NN/CR IDs exist in charter/PRD (no hallucinated IDs)
- Verify "how honored" specificity is checkable

**`agents/qa-prd-review.md`:**
- End-of-pipeline audit: every NN-C and NN-P honored across set of `done` pieces

**`agents/review-board/architecture.md`:**
- Expanded scope: CR-xxx compliance in addition to architecture patterns
- Input: all six charter files

**`agents/review-board/spec-compliance.md`:**
- Verify every NN-C/NN-P/CR the spec claims is honored in final diff

**`agents/review-board/prd-alignment.md`:**
- Verify NN-P entries preserved and honored in implementation

### 8.4 Hooks

**`hooks/session-start.md` (or equivalent):**
- Conditionally load charter files per config
- Silent no-op if `docs/charter/` missing
- Default: `doctrine_load: [non-negotiables, architecture]`

### 8.5 Config

**`.spec-flow.yaml` additions:**
```yaml
charter:
  required: true                                    # downstream skills fail if docs/charter/ missing
  doctrine_load: [non-negotiables, architecture]    # files auto-loaded via SessionStart
```

Default for new projects: `required: true`.

## 9. Charter evolution & versioning

### 9.1 Change semantics

| Operation | Numbering | Downstream |
|---|---|---|
| **Add** | Next sequential ID | Open pieces pick up at spec time; in-flight pieces warned |
| **Modify** | Same ID, new statement | All diverged pieces warned |
| **Remove** | ID retired (not reused) | Pieces citing retired IDs → QA must-fix |

No bulk renumbering — ever. Write-once IDs.

### 9.2 Divergence detection

Each piece's `spec.md` and `plan.md` gets `charter_snapshot: { non-negotiables: "2026-03-01", architecture: "2026-03-01", ... }` front-matter at write time.

Current `last_updated` > snapshot → piece is **diverged**.

| Piece status | Behavior |
|---|---|
| `open` | No effect (picks up latest at spec time) |
| `specced` | `⚠ charter diverged` in `/spec-flow:status` with diff summary; user decides: re-spec, accept with rationale, or block |
| `planned` | Same as specced + plan-level warning |
| `done` | No effect (history is history) |

Divergence is informational, not blocking. Human judgment.

### 9.3 Retire semantics

Retired entries stay visible with tombstone format:

```markdown
### ~~NN-C-012: Transactional boundaries per aggregate~~ (RETIRED 2026-04-20)
- **Original statement:** ...
- **Reason for retirement:** Superseded by NN-C-018 (outbox pattern)
- **Pieces that cited this:** auth-service-v2, billing-reconcile
```

Specs citing retired entries → `qa-spec` must-fix (drop citation or upgrade to superseder). End-of-pipeline `/prd --review` audits done pieces against retired entries (flag for review, not auto-fix).

## 10. Retrofit migration pipeline

Nine-step, commit-per-step, fully revertable pipeline. User confirmation required to enter.

**Step 1** — Snapshot pre-state to `docs/archive/pre-charter-migration-<date>/` (copy only, originals unchanged). Commit: `chore: snapshot pre-charter state to archive/`

**Step 2** — Socratic NN-xxx reclassification (one at a time): C, P, or R (retired). Record mapping in in-memory state. No file changes yet.

**Step 3** — Bootstrap Socratic for remaining five charter files (using detection signals). Promote NN-C entries to `docs/charter/non-negotiables.md` with new sequential IDs. Persist mapping table to `docs/archive/pre-charter-migration-<date>/nn-mapping.md`. Commit per charter file.

**Step 4** — Layout migration using `git mv` (preserves history):
- `docs/prd.md` → `docs/prd/prd.md`
- `docs/manifest.yaml` → `docs/prd/manifest.yaml`
- `docs/improvement-backlog.md` → `docs/backlog/backlog.md`

Commit: `chore: migrate docs/ layout to charter structure`

**Step 5** — Rewrite `docs/prd/prd.md`: drop unprefixed NN section, add NN-P section with renumbered entries, add Charter reference line, update inline references. Commit: `prd: add NN-P namespace, reference charter`

**Step 6** — Per-piece spec rewrite via `fix-doc` dispatch: map every NN-xxx citation to new NN-C/NN-P, update `charter_snapshot` front-matter. Retired citations escalate to user. Commit per piece: `spec(<piece>): update NN citations to charter namespaces`

**Step 7** — Per-piece plan rewrite (same pattern).

**Step 8** — `.spec-flow.yaml` gains charter block. Commit: `config: enable charter stage`

**Step 9** — Full QA sweep: `qa-charter` on charter, `qa-spec` on every rewritten spec, `qa-plan` on every rewritten plan. Human sign-off.

### 10.1 Dry run

`/spec-flow:charter --retrofit --dry-run` — walks pipeline, produces combined diff preview, no commits.

### 10.2 Opt-out

`/spec-flow:charter --decline` writes `.spec-flow.yaml` with `charter.required: false` + marker file `docs/.charter-declined`. Downstream skills skip charter checks. Reversible — run charter later to enter retrofit mode.

### 10.3 Rollback

No destructive commands anywhere. Any step's commit is `git revert`-able. Pre-state snapshot is the ultimate restore.

## 11. Release shape — v2.0.0

Single feature release. Seven pieces in PRD (to be imported after this design is approved):

1. Charter skill + templates + `qa-charter` agent (bootstrap mode)
2. Template updates + `pipeline-config.yaml` + session-start doctrine load
3. Downstream skill charter wiring (prd/spec/plan/execute/status)
4. Agent updates (implementer + QA agents + review-board)
5. Update mode + divergence detection
6. Retrofit mode + migration pipeline
7. README + CHANGELOG + diagrams

Dependencies: 2 depends on 1; 3 depends on 2; 4 depends on 3; 5 depends on 3; 6 depends on 3,5; 7 depends on all.

Each piece follows the normal spec → plan → execute → merge cycle.

## 12. Backlog (deferred from v1)

Captured in `docs/backlog/backlog.md` after merge:

- Validate charter structure against a mature existing product
- Fetch-and-summarize external URLs for Reference-type entries
- Auto-generated architecture/flow diagrams from code
- `docs/research/<topic>/` (non-piece) wiring beyond scaffolding
- Automated divergence resolution runners
- Cross-piece retirement impact analysis
- Charter version tags and git-tag integration
- Automated retry on QA failures during retrofit
- Step-specific rollback tooling
- Stale-reference detector for external URLs

## 13. Files touched (summary)

**New:**
- `plugins/spec-flow/skills/charter/SKILL.md`
- `plugins/spec-flow/agents/qa-charter.md`
- `plugins/spec-flow/templates/charter/{architecture,non-negotiables,tools,processes,flows,coding-rules}.md`

**Modified:**
- Skills: `prd`, `spec`, `plan`, `execute`, `status`
- Agents: `implementer`, `qa-spec`, `qa-plan`, `qa-phase`, `qa-prd-review`, `review-board/{architecture,spec-compliance,prd-alignment}`
- Templates: `prd.md`, `spec.md`, `plan.md`, `pipeline-config.yaml`
- Hooks: `session-start` (or equivalent)
- Docs: `README.md`, `CHANGELOG.md`

## 14. Open design questions

None. All decisions resolved during brainstorm:

- Charter population: Socratic (with user-provided sources) ✓
- Artifact shape: six focused files ✓
- Folder layout: hybrid artifact-first + per-piece co-location ✓
- NN namespaces: two (NN-C, NN-P) ✓
- External reference entries: Type=Reference schema, trust for v1 ✓
- Binding model: SessionStart doctrine + numeric refs ✓
- Versioning: write-once IDs, retire with tombstone ✓
- Divergence: informational, human-resolved ✓
- Retrofit: nine-step pipeline with pre-state snapshot ✓

## 15. Next step

After user review and approval of this spec, invoke the **writing-plans** skill to produce a detailed implementation plan covering the seven pieces in section 11.
