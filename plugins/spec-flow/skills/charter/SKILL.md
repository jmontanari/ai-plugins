---
name: charter
description: >-
  Bootstrap project architecture constraints via Socratic dialogue. Outputs charter skills:
  non-negotiables, architecture, tools, processes, flows, coding-rules, integrations. Modes:
  create, update. Triggers: "set up charter", "define architecture", "establish
  non-negotiables", "onboard project".
---

## Pre-flight: Model Check

Before any other step, verify the active model is an Opus-class model.

Determine the active model using the platform-appropriate method:

- **Copilot CLI** — read the `<model_information>` system tag injected into this session's context. The model name and ID are present there explicitly.
- **Claude Code** — no equivalent tag is injected. Use Claude's self-knowledge: introspect your own model identity (Claude reliably knows which model variant it is from training) and treat that as the model name for the check below.

If the active model name does **not** contain `opus` (case-insensitive):

1. Use `ask_user` to block and prompt the user:

   > ⚠️ **Model mismatch.** Charter authoring is thinking work per NN-P-005, but the active model appears to be **[model-name]**.

   Choices:
   - "Override — proceed on [model-name]"
   - "Change now — I'll switch models"
   - "Cancel charter"

2. If the user selects **"Cancel charter"** → stop immediately and emit:
   `Charter cancelled. Re-run after switching to an Opus model.`

3. If the user selects **"Override — proceed on [model-name]"** → proceed to Step 0 immediately on the current model. Emit a one-line acknowledgment first:
   `Overriding model check — proceeding on [model-name]. Charter quality may be reduced.`

4. If the user selects **"Change now — I'll switch models"** → **close the prompt and return control to the user.** The model cannot be switched while an `ask_user` prompt is blocking, and there is no programmatic model-change event to listen for — so leave the dialog and wait for the user to signal. Emit:
   `Switch to an Opus model now. When ready, type "proceed" to resume, or "cancel" to stop.`
   Then wait for the user's free-text reply:
   - On `proceed` (or any "I've switched / continue" phrasing) → re-run this model check (re-introspect your model identity on Claude Code, or re-read the `<model_information>` tag on Copilot CLI). If the model now contains `opus`, proceed to Step 0. If it still does not, re-present the three choices above.
   - On `cancel` → stop and emit the cancellation line from step 2.

If the model already contains `opus` → proceed to Step 0 immediately with no prompt.

# Charter — Project-Wide Binding Constraints

Produce a codified, binding set of project-wide constraints, published as charter **skills** under the project's host-native skills root — either `.github/skills/charter-*/` or `.claude/skills/charter-*/` (resolve per `plugins/spec-flow/reference/charter-location.md`). Charter skills are the single source of truth — there is no `docs/charter/` directory. Charter content is referenced by every downstream skill (`prd`, `spec`, `plan`, `execute`) and binds every implementation.

Charter skills use a **two-tier loading model** to balance coverage against context cost:

| Tier | Mechanism | Default domains |
|---|---|---|
| **Always-on doctrine** | `doctrine_load` in `.spec-flow.yaml` — injected by session-start hook | `non-negotiables`, `architecture` |
| **On-demand** | Description-triggered invocation by the host | `tools`, `flows`, `processes`, `coding-rules`, `integrations` |

The session-start hook (v4) reads `doctrine_load` and injects only those charter skills at startup. On-demand skills must have project-specific, trigger-accurate descriptions so the host invokes them when relevant.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` for docs-rooted paths below. Charter skill files live under the resolved charter root (`.github/skills/charter-*/` or `.claude/skills/charter-*/`) regardless of `docs_root` — resolve it per `plugins/spec-flow/reference/charter-location.md`. If `.spec-flow.yaml` is missing, default `docs_root` to `docs`.

Charter-specific config keys (safe defaults if absent):
- `charter.required` — default `true`
- `charter.doctrine_load` — default `[non-negotiables, architecture]` when absent
- `charter_root` — `.github` or `.claude`; the resolved charter location, written at bootstrap (see Phase 0)

## Modes

Detected from current state:

- **Bootstrap mode** — No `charter-*/SKILL.md` files exist under either skills root. Full Socratic flow → resolve a write location (Phase 0) → write seven files → QA → sign-off.
- **Update mode** — `charter-*/SKILL.md` files exist under the resolved charter root. User wants to change a charter file.

Explicit mode flag (optional): `/spec-flow:charter --update`. Without a flag, mode is auto-detected.

## Phase 0: Resolve charter location

Before writing any charter file, resolve where charter lives per `plugins/spec-flow/reference/charter-location.md`:

- **Update mode / charter already exists:** use the existing root (detect by existence, or `charter_root` from `.spec-flow.yaml`).
- **Bootstrap mode / no charter yet:** detect which host directory the project already has — `.github/` or `.claude/` — and recommend that root; if both exist, present both and let the user pick; if neither exists, ask the user which root to use. **Never assume a default.** After the user confirms, persist `charter_root: .github` (or `.claude`) to `.spec-flow.yaml` and write charter to `<charter_root>/skills/charter-<domain>/SKILL.md`.

## Bootstrap Mode Workflow

### Phase 1.1: Auto-detect signals

**Preflight — verify HEAD is the development branch:**
```bash
git branch --show-current && git log --oneline -n 3
```
If HEAD appears to be a release tag or non-development branch, warn the user before proceeding.

Read lightweight config signals first — these orient the scan agent:

- `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`
- Build manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`
- TS/lint configs: `tsconfig.json`, `.eslintrc*`, `.ruff.toml`, `.prettierrc*`
- CI: `.github/workflows/*`, `.pre-commit-config.yaml`
- Existing `docs/architecture/` or `docs/adr/`
- Recent `git log --oneline -n 50`

**Determine scan tier** before dispatching the agent:
```bash
git ls-tree -r --name-only HEAD | grep -E '\.(java|py|ts|go|rb|rs|kt|scala|cs|cpp|c)$' | wc -l
```

| Tier | Source file count | Files to sample | Pattern threshold |
|------|------------------|-----------------|-------------------|
| Small | < 50 | 3–5 total | 2+ files |
| Medium | 50–500 | 8–15 total | 4+ files |
| Large | 500–2000 | 20–30 total | 8+ files |
| Very large | 2000+ | 30–50 total | 15+ files (~10% of same-layer files) |

**Dispatch the scan agent:**

```
Agent({
  description: "Charter repo scan — comprehensive pattern and architecture analysis",
  agent_type: "explore",
  prompt: """
You are scanning a codebase to produce a structured Signal Summary for a project charter.
Repo root: <absolute path>
Source file count: <N>
Scan tier: <small/medium/large/very-large>
Pattern threshold (min files for a pattern to count): <threshold from table above>

## Exclusions (DO NOT sample these — they are generated or vendored, not design choices)
Exclude all files matching: vendor/, node_modules/, *_generated.*, *.pb.go, *.pb.py,
dist/, build/, .git/, db/migrations/ (SQL only), __pycache__/, .cache/, *.min.js,
any path listed in .gitignore as generated output.
Treat test files as a SEPARATE stratum — patterns from tests do not populate production coding rules.

## Step 1 — File type inventory
Run:
  git ls-tree -r --name-only HEAD 2>/dev/null | grep -v -E '(vendor/|node_modules/|dist/|build/|\.pb\.|_generated\.|__pycache__)' \
    | grep -E '\\.[a-zA-Z0-9]+$' | sed 's/.*\\.//' | sort | uniq -c | sort -rn | head -30

Categorize every extension into:
- Source languages (.java, .py, .ts, .go, .rb, .rs, .kt, .scala, .cs, .cpp, .c, etc.)
- Tests (files under test*/, *_test.*, *.spec.*, *.test.*)  [separate stratum]
- Build/config (.gradle, .toml, .yaml, Makefile, Dockerfile)
- Schema/data (.proto, .graphql, .sql, .json schemas, .avro, OpenAPI .yaml)
- Infrastructure (Ansible roles, Terraform .tf, Helm charts)
- Docs (.md, .rst, .adoc)

Every populated bucket must have at least one sample in Step 2.

## Step 2 — Cross-module, cross-role sampling at tier depth
Sample at the depth specified for this tier. For multi-module repos (multiple pom.xml,
build.gradle, package.json, go.mod, or a root settings.gradle/pnpm-workspace.yaml):
sample from at least 2–3 distinct modules/subprojects. Do NOT anchor to the root module alone.

Within each module, pick files representing DIFFERENT ROLES:
- Java: controller/handler, service/use-case, repository/DAO, domain model, utility/helper
- TypeScript: route handler, service class, data model, utility
- Python: view/endpoint, service, model, ORM query layer
- Go: handler, service, repository, model
- Ansible: a role tasks/main.yml, a handler, a defaults/main.yml, a vars file
- Terraform: a resource module, a variable definition, an output definition

Also sample: at least one unit test AND one integration/e2e test (separate stratum);
at least one file of each schema/data type found; one infra file per infra type.

## Step 3 — Observe and record patterns per sampled file
For each file read, note:
- Error handling: exceptions, error returns, Result/Either types, status codes, log-and-swallow
- Dependency wiring: constructor injection, service locator, global singletons, module-level imports
- Structural idiom: MVC, hexagonal/ports-and-adapters, flat-module-per-feature, script-per-task, monolith
- Naming conventions: snake_case vs camelCase, file naming, package/module naming, constant naming
- Security patterns: where auth is enforced, input validation location, secret handling
- Any pattern appearing in <threshold>+ files independently — HIGH confidence convention

Assign a confidence tier to each observed pattern:
- HIGH: appears in <threshold>+ files across multiple modules/authors
- MEDIUM: appears in 2–(<threshold>-1) files, or multiple files in only one module
- LOW: appears in 1 file or only in generated/early code

## Step 3b — Cross-module inconsistency detection
For each concern category (error handling, DI, naming, test patterns, auth enforcement):
identify cases where DIFFERENT modules use DIFFERENT approaches. List each inconsistency
with both variants and which modules exemplify each. Example:
"auth module uses Result<T, Error> error returns; billing module uses unchecked exceptions"
Inconsistencies are HIGH-value charter signals — they represent unresolved design decisions.

## Step 3c — Absence-of-pattern detection
For each of these concern categories, note if NO consistent pattern was found:
error handling, logging framework, testing strategy, API versioning, auth enforcement,
input validation, rate limiting, observability/tracing. Absence is a signal — it may
mean the team uses a non-obvious approach or has an unaddressed gap.

## Step 4 — Git intentionality analysis for HIGH-confidence patterns
For the top 3–5 HIGH-confidence patterns found, run:
  git log --follow --oneline -- <representative file exemplifying the pattern> | head -10
to determine: when was this pattern introduced? By one author or many? How often has it
been touched? A pattern introduced by one author 3 years ago and never modified is
LOWER intentionality than one introduced across 12 commits from 8 authors over 2 years.
Add an "intentionality" note to each HIGH-confidence pattern: "adopted widely across authors"
or "introduced by one author, no subsequent modification."

## Step 5 — Identify sampling gaps
Note file types or modules found but not adequately sampled given the tier.
Example: "Found 40 .proto files but only read 2" or "4 Maven modules — only sampled core and web."
Scale gap list to tier: Small repos may have none; Very Large repos should list all meaningful gaps.

## Output format — return this structure EXACTLY

### Signal Summary

**Scan metadata:**
- Tier: [small/medium/large/very-large]
- Source files counted: [N]
- Files sampled: [N]
- Pattern threshold used: [N files]

**Detected tools:**
- Language: [language + version if determinable]
- Framework: [framework(s)]
- Test runner: [runner + coverage tool]
- Linter/formatter: [tools]
- Build: [build tool]
- CI: [CI platform]

**Repo structure:**
- Top-level folders: [list → inferred layers or components]
- Module count: [N modules/subprojects]
- Dominant structure: [e.g., "Maven multi-module", "flat Python package", "Go workspace"]

**Files sampled:** [list each file path + role it represents]

**Observed patterns — production code (with confidence tier and file evidence):**
Each entry format: `[HIGH/MEDIUM/LOW] [Pattern description] — seen in: [file1], [file2], ... — Intentionality: [note from Step 4 if assessed]`
- Error handling: [entries]
- Dependency wiring: [entries]
- Structural idiom: [entries]
- Naming conventions: [entries]
- Security patterns: [entries]
- Unwritten conventions (≥threshold files): [entries or "none"]

**Cross-module inconsistencies:**
- [inconsistency 1: both variants, which modules]
- [inconsistency 2] ... or "None detected"

**Absent patterns (no consistent approach found):**
- [category]: [absent or note]

**Test setup (separate stratum):**
- Location: [colocated / dedicated tests/ root]
- Kinds observed: [unit / integration / e2e]
- Patterns: [fixtures, mocks, builders, etc.]
- Coverage tooling: [if present]

**Schema/infra sampled:** [list types and one representative finding each]

**Sampling gaps:**
- [gap 1] ... or "None at this tier"
  """,
  model: "haiku"
})
```

**Signal Summary quality gate:** Before proceeding, verify the returned summary meets the minimum bar:
- Every "Observed patterns" entry cites ≥2 specific file paths (except LOWs which may cite 1)
- Confidence tiers are assigned to every pattern claim
- Cross-module inconsistencies section is populated (even if "None detected")
- Absent patterns section is populated

If any HIGH-confidence pattern claim lacks file evidence, dispatch a follow-up haiku agent to verify those specific files. Hold the verified Signal Summary in orchestrator state. Do NOT re-read individual files the agent already read.

### Phase 1.2: External sources

Ask before gap-filling — external sources change which internal gaps matter. Ask by charter-file category so the user knows exactly what kind of document is useful for each. One question per category; skip any the user answers 'none' to.

> "Before I identify what the scan missed, do you have external documents for any of these categories?
>
> **Non-negotiables** — compliance docs, security policies, SLAs, legal requirements, audit frameworks (SOC2, HIPAA, PCI), regulatory constraints. These directly seed NN-C candidates.
>
> **Architecture** — ADRs (architecture decision records), RFCs, system diagrams, prior design docs, tech-debt registers. These confirm or override what the code scan inferred.
>
> **Processes** — team handbooks, runbooks, release procedures, on-call docs, incident post-mortems, change-management policies. These drive `processes.md` content the code can't reveal.
>
> **Coding rules** — existing style guides, code review checklists, linting/formatting configs the team has agreed on but not fully enforced in tooling, security coding standards.
>
> **Flows** — sequence diagrams, API contracts, integration specs, data flow diagrams, swimlane docs.
>
> **Tools** — approved vendor lists, dependency policies, internal tooling docs, approved cloud services lists.
>
> For each category: paste paths (local files) or URLs, or say 'none'."

For each provided source, route by type:
- **Local paths or sibling repos:** dispatch an explore+haiku agent pointing at the provided paths, passing the existing Signal Summary AND the category context (e.g., "this is a compliance doc — extract NN candidates"). Merge returned findings before Phase 1.1.5, tagged by the charter file they inform.
- **External URLs:** attempt `WebFetch`. On success, summarize into signals tagged by category. On failure (auth-walled, offline, rate-limited), record as pending reference: *"Couldn't fetch `<url>`; treating as unverified reference. Summarize what it binds us to during Socratic."*

Track which charter files each external source informs — this is used in Phase 2 to surface the source at the relevant section ("Your compliance doc said X — should this be an NN-C?").

### Phase 1.1.5: Targeted gap-fill

Now that both the internal scan AND external sources are loaded, present the gap list with full context. This is a focused ask — not an open-ended "anything else?"

Scale the number of gaps surfaced to repo size (Small: 0–2; Medium: 2–4; Large: 4–7; Very Large: 7–10).

Present:
> "I've scanned your repo and loaded [N] external sources. Here's what I've covered:
> - **[Language/type]:** [file1 (role)], [file2 (role)], ...
> - **Tests:** [test files sampled]
> - **Schema/infra:** [types sampled + key finding per type]
>
> Gaps — areas I couldn't cover fully given your repo size:
> - [e.g., "3 Maven modules (`api`, `core`, `infra`) — only sampled `core`. Specific files in `api` or `infra` that show your design choices?"]
> - [e.g., "40 `.proto` files — only read 2. Any that define core service contracts?"]
>
> I also found these **cross-module inconsistencies** where I need your guidance before asking questions:
> - [e.g., "`auth` uses Result<T,Error> returns; `billing` uses unchecked exceptions — which should be canonical?"]
>
> Paste specific file paths and any inconsistency decisions, or say 'continue'."

If the user provides files, dispatch a second scan agent to read them and merge findings into the Signal Summary.

### Phase 1.3: Confirm combined signal summary

Present the full Signal Summary to the user for confirmation — this is the last chance to correct misreadings before a long Socratic session begins on their basis:

> "Here's my full picture before we start:
>
> **Tools:** [language/framework/test runner/linter/CI]
> **Repo structure:** [top-level folders → inferred layers; module count]
> **Observed patterns (HIGH confidence — will drive 'I saw X' questions):**
>   - [pattern] — seen in: [file1], [file2] — [intentionality note]
>   ...
> **Inconsistencies to resolve in dialogue:**
>   - [inconsistency — both variants]
> **Absent patterns (no approach found — will ask about during Socratic):**
>   - [category]
> **External references loaded:** [sources]
>
> Does this look right? Anything misread or missing? Corrections here prevent 20+ questions built on a wrong assumption."

Only proceed to Phase 2 after user confirms.

### Signal Summary persistence

After Phase 1.3 confirmation, serialize the Signal Summary to a recoverable format. Offer:
> "I'll save the confirmed Signal Summary so we can resume if this session is interrupted."

Write to `<charter_root>/skills/.charter-signal-summary.yaml` (gitignored, add to `.gitignore` if absent), where `<charter_root>` is resolved in Phase 0. If the session is interrupted and restarted, the user can instruct the skill to load this file instead of re-running the scan.

### Phase 1.9: Deliberation Protocol

**[Deliberation protocol]** *(runs after Signal Summary persistence, before Phase 2 Socratic dialogue)*:

Depth levels and per-skill defaults are defined in `reference/deliberation-depth.md` (full / lite / off profiles, operator override contract). The artifact structure, VOQ-N IDs, marker contract, and STATUS line are defined in `reference/deliberation-artifact.md` — cite both; do not restate.

The decision unit for this skill is the **per-domain rule / principle** (not a file, not a whole-charter cluster). Each cluster in Phase A represents one charter domain (e.g., error-handling conventions, dependency rules, naming standards, auth enforcement) grouping the candidate rules/principles that will govern it; Phase B viability agents assess each domain cluster independently.

0. **Resolve depth:** read `.spec-flow.yaml` `deliberation.depth`; apply any operator override; else use per-skill default (`full` for charter). On `depth=off` → emit `[DELIBERATION-SKIPPED: depth=off]`, run Phase 2 Socratic dialogue from the top, STOP here.

1. **Dispatch Phase A** (`agents/deliberation-coordinator.md`): inject the confirmed Signal Summary (from Phase 1.3), the domain being chartered (all seven charter domains — architecture, tools, coding-rules, processes, flows, non-negotiables, integrations), existing codebase patterns (from the Phase 1.1 scan / research/L-10 fallback), and related industry-standard rules for the project type (web research — the coordinator fires targeted searches for the detected stack and domain).
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-A-blocked]`, fall back to Phase 2 Socratic dialogue.

2. **Consume decision-unit clusters from Phase A:** take the identified per-domain-rule clusters returned in Phase A's investigation seed (the coordinator already derived them from the Signal Summary and industry-standard research). At `lite` depth, collapse them to one whole-charter cluster regardless of what Phase A returned.

3. **Dispatch Phase B in parallel, one `agents/deliberation-viability.md` agent per cluster**: inject Phase A investigation seed + per-cluster domain-rule assignment + charter constraints. Each agent evaluates reuse/codify-existing paths vs. gaps, referencing codebase patterns and industry-standard rules.
   **Barrier:** wait for all Phase B agents to complete.
   On any Phase B `STATUS: BLOCKED` → log the blocked cluster; proceed with remaining cluster outputs (non-fatal partial).

4. **Dispatch Phase C** (`agents/deliberation-synthesis.md`): inject all Phase B per-cluster findings.
   **Skip when ≤1 cluster** — single-cluster output is already integrated. On skip, record single-cluster coherence in the `## Integration Check` section of `deliberation.md`; the Phase B single-cluster viability output becomes the anchor for Phase D and Phase E in place of a Phase C recommendation.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-C-blocked]`, fall back to Phase 2 Socratic dialogue.

5. **Dispatch Phase D in parallel, exactly five lens agents** (`agents/deliberation-lens.md` dispatched 5×): inject Phase C recommendation + one lens label per agent (when Phase C was skipped at ≤1 cluster, inject the Phase B single-cluster viability output as the recommendation anchor — the single-cluster coherence summary — in place of the Phase C recommendation). Full depth lens labels (one agent per label):
   - `architecture-integrity` — structural / layering / dependency-direction review
   - `scope/simplicity` — YAGNI / over-engineering / unnecessary abstraction review
   - `user-intent` — does the recommendation serve the operator's stated goal?
   - `backward-compat` — breaking-change / migration / rollback impact review
   - `risk` — failure modes, hidden assumptions, external-dependency exposure review
   At `lite` depth use the configured subset (default: `scope/simplicity` + `risk`). Depth profile and per-lens label list are defined in `reference/deliberation-depth.md`.
   **Barrier:** wait for all dispatched Phase D agents.
   On any/all Phase D `STATUS: BLOCKED` → log blocked lens(es); proceed to Phase E with available verdicts (non-fatal).

6. **Dispatch Phase E** (`agents/deliberation-convergence.md`): inject Phase C recommendation + all Phase D verdicts (when Phase C was skipped at ≤1 cluster, inject the Phase B single-cluster viability output as the recommendation anchor — the single-cluster coherence summary — in place of the Phase C recommendation). Phase E tags each validated open question with a stable `VOQ-N` ID and records the resolved depth in the `## Investigation Summary` section.
   On `STATUS: OK` and `deliberation.md` present + non-empty: commit `deliberation.md`.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-E-blocked]`, fall back to Phase 2 Socratic dialogue.
   On `deliberation.md` missing or zero-length after dispatch → emit `[DELIBERATION-UNAVAILABLE: deliberation.md-empty-after-dispatch]`, fall back to Phase 2 Socratic dialogue.
   On `git commit` of `deliberation.md` failing (zero files staged or non-zero exit) → remove the uncommitted `deliberation.md` before falling back (e.g. `rm -f <path>` if it was not previously committed, or `git checkout -- <path>` if it was) so downstream consumers cannot pick up the disowned artifact → emit `[DELIBERATION-UNAVAILABLE: deliberation.md-commit-failed]`, fall back to Phase 2 Socratic dialogue.

7. **First Phase 2 message:** present Investigation Summary + Recommendation + "I have N validated questions for you."

8. **Questions:** draw from the `## Validated Open Questions` section in order; each question cites its `VOQ-N` ID (or a named deliberation section for an emergent follow-up — e.g. "Following deliberation's `## Integration Check`: …" for cross-domain composition concerns).

On the `[DELIBERATION-UNAVAILABLE]` or `[DELIBERATION-SKIPPED]` path: run Phase 2 Socratic dialogue as written (today's behavior — one question at a time, sections A–G in order).

<!-- Example: a project with an inconsistent error-handling pattern (Result<T,E> in auth vs. unchecked exceptions in billing) and no documented naming conventions → 2 domain clusters. full depth.
Phase A coordinator reads Signal Summary + codebase patterns + fires web search for Node.js error-handling standards, produces per-domain-rule clusters.
Phase B: 2 viability agents (one per domain cluster) in parallel → barrier.
Phase C synthesis runs (2 clusters ≥2 → not skipped) → integrated recommendation.
Phase D: 5 lens agents in parallel → barrier (4 HOLDS, 1 CONTESTED on backward-compat for existing unchecked exception callers).
Phase E: folds the CONTESTED into VOQ-1, writes deliberation.md, records depth=full.
First Phase 2 message: Investigation Summary + Recommendation + "I have 1 validated question (VOQ-1)."
Single-cluster counter-example: a greenfield project with no prior patterns → 1 cluster, Phase C SKIPPED (≤1 cluster). -->

### Phase 2: Socratic dialogue — section by section

**Present the full section checklist upfront** before asking any questions:

> "We'll work through these sections to build your 7 charter files. Each section builds on the last.
> I'll mark each section complete as we finish it.
>
> [ ] **A. Tools & Runtime** (tools.md)
>    A1. Language & runtime  A2. Frameworks & libraries  A3. Testing stack  A4. Build & CI  A5. Approved/banned
>
> [ ] **B. Architecture** (architecture.md) — interleaved with A where tools drive architecture choices
>    B1. Layer structure  B2. Dependency rules  B3. Component & data ownership
>    B4. Data flow  B5. Error & failure handling  B6. Security boundaries
>
> [ ] **C. Critical Flows** (flows.md)
>    C1. Identify key flows  C2. Request/response  C3. Auth flow  C4. Data-write path
>    C5. External integrations  C6. Error/failure flows
>
> [ ] **D. Coding Rules** (coding-rules.md)
>    D1. Naming conventions  D2. File/module organization  D3. Error handling patterns
>    D4. Testing patterns  D5. Security coding rules  D6. Performance & resource rules  D7. Documentation standards
>
> [ ] **E. Processes** (processes.md)
>    E1. Branching model  E2. Review & approval  E3. CI gates  E4. Release cadence  E5. Incident response
>
> [ ] **F. Non-Negotiables** (non-negotiables.md)
>    F1. Surface captured NN candidates  F2. Classify each (NN-C / NN-P / just CR)  F3. User-introduced NNs  F4. Confirm rationale & QA verification
>
> [ ] **G. Integrations** (integrations.md)
>    G1. What external services/MCPs does this project integrate with?  G2. Per-integration: prerequisites, which skills use it, graceful degradation
>
> Ready to start with Section A? This will take a while — we're building the foundation everything else relies on."

**Session rules — apply throughout Phase 2:**

- **One question at a time.** Multiple-choice preferred. Never ask more than one question per message.
- **Question depth scales with repo tier:**
  | Tier | Questions per section |
  |------|-----------------------|
  | Small | 2–4 per section |
  | Medium | 4–6 per section |
  | Large | 6–8 per section |
  | Very large | 8–10 per section |
- **Scan-answered questions (HIGH confidence):** use evidence-led confirmation format instead of asking from scratch:
  > "I found [pattern description] in `[file1]`, `[file2]`, and `[file3]`:
  > ```
  > [1–3 line code excerpt showing the pattern]
  > ```
  > Is this the intended convention, or was this one person's habit?"
  Wait for explicit confirmation before treating it as settled.
- **Pattern provenance:** every code-derived claim cites specific file paths. Never state "the codebase uses X" without naming at least 2 files.
- **NN capture flag:** any user answer containing "always," "never," "must," "cannot," "required," "forbidden," or "every X must" → silently queue that statement for Section F review. Do not interrupt the current section — collect and surface later.
- **Session checkpoints:** every 15 questions, pause: "We've covered a lot — want a break and continue later, or push through?" If continuing later, remind user the Signal Summary is saved at `<charter_root>/skills/.charter-signal-summary.yaml`.
- **Per-section mini-confirmation:** at the end of EACH section, before moving to the next: "Here's what I've captured for [section name]: [3–5 bullet summary]. Anything to correct before I move on?"
- **Unresolved answers** → `[NEEDS CLARIFICATION]` marker in the draft. QA treats these as must-fix.

**Section A — Tools & Runtime** (`tools.md`)

*Note: treat Sections A and B as interleaved — tool choices (ORM, HTTP framework, event bus) are architectural decisions. If an A question surfaces an architecture implication, address it in A before continuing.*

A1. Language & runtime: version, runtime targets, multi-language support
A2. Frameworks & libraries: primary framework, any secondary frameworks, known banned libraries, approved-only policy vs allowlist
A3. Testing stack: test runner, coverage tool and threshold, assertion library, mock framework, test data approach
A4. Build & CI: build tool, CI platform, what checks gate merge (lint, type-check, test, coverage floor, security scan)
A5. Approved/banned: any libraries known to be banned (security, licensing, deprecated), any explicitly approved-only whitelist

**Section B — Architecture** (`architecture.md`)

B1. Layer structure: what are the top-level layers? Do they map to directories? Can each layer be changed independently? Use HIGH-confidence structural idiom from scan as prior.
B2. Dependency rules: what can import what? Is there a strict direction rule? Any known violations today the charter should flag?
B3. Component & data ownership: who owns what data? Are there shared databases or stores? Any shared-data antipatterns to call out?
B4. Data flow: how does data enter, transform, and exit? What are the key transformation stages? Where does validation happen?
B5. Error & failure handling: how do errors propagate? Surface inconsistencies detected in scan: "I found [variant A] in module X and [variant B] in module Y — which should be canonical?" Pick one convention and codify it.
B6. Security boundaries: where is auth enforced? What data is sensitive and how is it protected at rest/in transit? Where is input validated? Any security patterns seen in scan.

**Section C — Critical Flows** (`flows.md`)

C1. Identify key flows: what are the 3–6 most critical end-to-end flows in this system? (Request/response is one; auth is one; data-write is one; others?)
C2–C6. For each identified flow: entry point, happy path steps, error path, external dependencies, how failures surface.

**Section D — Coding Rules** (`coding-rules.md`)

ALL D questions are evidence-led. For each rule area, present HIGH-confidence scan findings first ("I saw X in these files"), confirm or correct, THEN ask about anything not found in scan.

D1. Naming conventions: file naming, class/function naming, constant naming, package/module naming — present scan findings with file evidence and excerpts.
D2. File/module organization: where do new files go? How are modules structured? Present scan findings.
D3. Error handling patterns: how are errors created, wrapped, propagated, logged? Reinforce the decision made in B5.
D4. Testing patterns: what must be tested, what patterns to use (arrange/act/assert, given/when/then), what test data approaches are required.
D5. Security coding rules: input validation requirements, secret handling, logging of sensitive data, any OWASP-relevant rules for this stack.
D6. Performance & resource rules: any rules about N+1 queries, connection pooling, memory limits, async patterns (if applicable to stack).
D7. Documentation standards: what must be documented? Docstring requirements, README requirements, API documentation approach.

**Section E — Processes** (`processes.md`)

E1. Branching model: trunk-based, git-flow, feature-branch — what's the policy?
E2. Review & approval: how many reviewers required? Who can approve? What requires senior/lead review?
E3. CI gates: which checks must pass before merge? Which are informational only?
E4. Release cadence: how often are releases cut? Who cuts them? What's the release artifact (container, package, binary)?
E5. Incident response: how are production incidents handled? On-call rotation? Runbooks?

**Section F — Non-Negotiables** (`non-negotiables.md`)

F1. **Surface all captured NN candidates:** Present every statement from the session that contained "always/never/must/cannot/required/forbidden" language, PLUS every HIGH-confidence pattern from scan (5+ files, multiple authors) as an NN candidate:
> "During our conversation and from the code scan, I identified these as potential non-negotiables:
> 1. [statement/pattern] — from your answer to B5 / from [file1], [file2], [file3]+
> ...
> For each: Is this (a) a hard non-negotiable [NN-C], (b) a product-specific non-negotiable [NN-P], (c) just a coding rule [CR], or (d) not actually a constraint?"

F2. For each confirmed NN-C or NN-P: confirm the structured schema — Type, Scope, Rationale, and critically "How QA verifies this." The QA verification method must be concrete (e.g., "grep for direct DB access outside repository layer in CI" not just "QA checks it").
F3. Any additional NNs the user wants to add that weren't captured by the session or scan.
F4. Final confirmation: present all NNs with their full schema before closing the section.

**Section G — Integrations** (`integrations.md`)

G1. What external service integrations exist or are planned? (MCP servers, CI systems, external APIs, webhooks) List each.
G2. For each identified integration: What does it enable? What are the prerequisites to use it (tools to install, credentials to configure)? Which skills invoke it? What happens if it's absent (graceful degradation)?
G3. Confirm: does the integration handle its own credentials, or does the plugin need to document credential setup? (Answer should always be "integration handles it" per architecture.md — flag if different.)

**G — Jira sub-flow (run when Jira is identified in G1):**

Ask these questions in sequence — one at a time — to gather everything needed to populate the `.spec-flow.yaml` `integrations.issue_tracker` block and the `integrations.md` charter file:

> **G-J1.** What is your Jira instance URL?
> (e.g. `https://yourorg.atlassian.net` — this becomes `base_url` in `.spec-flow.yaml`)

> **G-J2.** What Jira project key should spec-flow create issues in?
> (e.g. `EIT`, `PROJ` — this becomes `project_key`)

> **G-J3.** What issue type should be created for each **piece** (the per-PRD-piece work item)?
> Common choices: `Epic`, `Story`, `Feature` — default is `Epic`.

> **G-J4.** What issue type should be created for each **phase** inside a piece?
> Common choices: `Task`, `SubTask`, `Story` — default is `Task`.

> **G-J5.** Is there a parent issue type above the piece level (e.g. a Capability, Initiative, or Theme)?
> If yes: what is the type name? This level is managed manually — you'll create it in Jira and record its key as `jira_key:` in `prd.md` front-matter.
> If no: the piece-level issue is the top of the hierarchy.

> **G-J6.** Should spec-flow **automatically create** Jira issues when spec and plan skills run?
> (yes → `auto_create_tasks: true`; no → tasks are created manually)

> **G-J7.** Should spec-flow **automatically transition** Jira issues as phases progress through execute?
> (yes → `auto_transition: true`; no → transitions are done manually in Jira)

> **G-J8.** **Issue naming formats** — spec-flow uses these defaults for issue titles. Confirm or override:
>
> | Issue | Default title format |
> |-------|----------------------|
> | piece issue (one per piece, from G-J3) | `{piece-slug} — {piece description from manifest}` |
> | phase issue (one per phase, from G-J4) | `[phase] {piece-slug}/{phase-number} — {phase-name}` |
>
> Do these match your team's conventions, or do you need a different format?
> (If overriding, provide a template using the same `{tokens}`. Stored as `naming:` on the relevant hierarchy entry; omit if defaults are accepted.)

> **G-J9.** **Status transition rules** — at each pipeline event, spec-flow transitions the relevant issue. Confirm that these status names match your Jira project's workflow, or rename any that don't:
>
> | Event | Issue | Default target status |
> |-------|-------|-----------------------|
> | Issue created | piece or phase issue | `To Do` |
> | Phase execute starts | phase issue | `In Progress` |
> | Phase QA passes | phase issue | `In Review` |
> | Final Review Board passes | phase issue | `Done` |
> | Non-active tasks after creation | phase issue | `Backlog` |
>
> Only agents running execute may move issues to `In Progress` or `In Review`. Only the Final Review Board pass triggers `Done`.
> (Stored under `status_map` — omit any entry that matches the default.)

> **G-J10.** **Effort tracking** — how does your team track effort on Tasks in Jira?
> - **Story points** — abstract point estimate set on the ticket at creation
> - **Time tracking** — original estimate in hours or days (Jira's built-in time tracking fields)
> - **Both** — story points for planning velocity, time tracking for actuals
> - **Neither** — skip effort tracking entirely

**If story points (or both) — field discovery:**

Run before asking the formula question:
```
Use: io-sooperset-mcp-atlassian-jira_search_fields(keyword="story point")
```
Present results to the user:
> "I found these story-point-related fields in your Jira instance:
> - `customfield_XXXXX` — "Story Points" (type: number)
> - `customfield_YYYYY` — "Story point estimate" (type: number)
>
> Which field should spec-flow write when setting story points on Tasks?"

If the tool is unavailable or returns no matches, ask the user to provide the field ID manually (check Jira → Project settings → Fields). Store as `story_points_field`.

> **G-J10a.** **Story point formula** — spec-flow estimates story points as `fib_ceil(phase_days × multiplier)`: multiply the day estimate by the multiplier, then round up to the next Fibonacci number (1, 2, 3, 5, 8, 13, 21 …). 1 story point ~= 1 human work day.
>
> Example: 6 days → 6 × 0.5 = 3.0 → **3 pts**. Example: 7 days → 7 × 0.5 = 3.5 → **5 pts**.
>
> The default multiplier is `0.5`. Does this fit your team's velocity, or should we adjust it?
> (Store as `story_points_multiplier` — default `0.5`)

**If time tracking (or both):**

> **G-J10b.** What unit does your team use for original estimates?
> - **Hours** — stored as `Xh` (e.g. `6h`)
> - **Days** — stored as `Xd` (e.g. `3d`)
>
> spec-flow will set `timetracking.originalEstimate` on each Task at creation, derived from the same day estimate used for story points. Store as `time_tracking_unit: hours|days`.

After all G-J questions are answered, confirm the full Jira block before writing:
> "Here's what I'll write to `.spec-flow.yaml` under `integrations.issue_tracker`:
> ```yaml
> integrations:
>   issue_tracker:
>     enabled: true
>     provider: jira
>     project_key: <answer>
>     base_url: <answer>
>     auto_create_tasks: <answer>
>     auto_transition: <answer>
>     commit_tag_format: "[{issue_key}]"
>     hierarchy:
>       <if G-J5 parent type given>
>       - type: <G-J5 parent type>
>         managed: false
>         artifact: prd
>         key_field: jira_key
>       </if>
>       - type: <G-J3 piece type>
>         managed_by: spec
>         artifact: spec
>         key_field: jira_key
>         naming: "<G-J8 piece override or omit>"
>       - type: <G-J4 phase type>
>         managed_by: plan
>         artifact: plan
>         key_field: jira_key
>         naming: "<G-J8 phase override or omit>"
>     # story points (omit block if neither/time-only)
>     story_points_field: <discovered field ID or null>
>     story_points_multiplier: <answer or 0.5>
>     # time tracking (omit block if neither/points-only)
>     time_tracking: <true|false>
>     time_tracking_unit: <hours|days|null>
>     # status names for this project's Jira workflow
>     status_map:
>       todo: <answer or "To Do">
>       in_progress: <answer or "In Progress">
>       in_review: <answer or "In Review">
>       done: <answer or "Done">
>       backlog: <answer or "Backlog">
> ```
> Does this look right before I write?"

Per-section mini-confirmation before moving on.

### Phase 2.5: Charter preview — confirm before writing

Before writing any files, present a section-by-section summary of what each charter file will contain. Ask after each section: "Does this look right? Correct anything before I write." Only write once all sections are approved.

Format:
> **tools.md:** [language + version, framework, test runner, linter, CI — one line each]
> **architecture.md:** [layers, dependency direction, key component boundaries, error convention — 4–6 bullets]
> **flows.md:** [N flows to document — list their names and entry/exit points]
> **coding-rules.md:** [N CR entries planned — list titles with evidence source: "scan-derived" or "user-introduced"]
> **processes.md:** [branching model, review policy, CI gates — key decisions only]
> **non-negotiables.md:** [N NN-C entries — list titles + QA verification method]
> **integrations.md:** [N integrations — list names, required MCPs, and for Jira: project_key, base_url, issue type mapping, auto flags]

A correction here costs one message; a correction post-write costs a QA iteration.


### Phase 3: Write files

#### Prerequisite: skill-creator must be installed

Charter skills live on disk and are host-invoked by description. A bad description means a charter domain is never consulted. `skill-creator` provides the description optimization loop that makes descriptions reliable — without it, descriptions are guesswork.

Before writing any charter skill file, verify `skill-creator` is available:

```bash
# Check for skill-creator in any installed-plugins tree
ls ~/.copilot/installed-plugins/*/skill-creator/skills/skill-creator/SKILL.md 2>/dev/null \
  || ls ~/.copilot/installed-plugins/*/*/skill-creator/skills/skill-creator/SKILL.md 2>/dev/null
```

**If skill-creator is not found:** Stop and tell the user:

> ⚠️ `skill-creator` plugin is required before writing charter skills. Charter skill descriptions must be optimized for accurate host invocation — generic descriptions result in skills that never trigger.
> Install skill-creator, then return to Phase 3.

Do not proceed past this gate until the check passes.

---

Load templates from `${CLAUDE_PLUGIN_ROOT}/templates/charter/`. Populate placeholders from Socratic answers.

**Write directly to `<charter_root>/skills/charter-<domain>/SKILL.md`** (create the directory if absent), where `<charter_root>` is the location resolved in Phase 0 (`.github` or `.claude`). These ARE the authoritative charter files — there is no `docs/charter/` directory.

Each skill file uses standard skill frontmatter — NO `last_updated:` field (use `git log` for history):

```yaml
---
name: charter-<domain>
description: "<optimized — see description step below>"
---
```

**Description step — invoke skill-creator:**
Generic domain-template descriptions are not acceptable. Charter skills cover different domains and serve different audiences; each needs a description that reliably triggers when a contributor is about to do work governed by that domain.

For each domain:
1. Draft a project-specific description from the Socratic answers: what rules does this domain contain, and what work would a contributor be doing when those rules matter?
2. Invoke `/skill-creator` and ask it to run the description optimization flow on the draft.
3. Use the optimized description as the `description:` field. **Always wrap the value in double quotes** — descriptions contain colons which break unquoted YAML scalars.

The 7 domains: `architecture`, `tools`, `flows`, `coding-rules`, `processes`, `non-negotiables`, `integrations`.

Charter skills live on `main` (not a worktree — charter is project-global, not piece-scoped).

### Phase 4: QA loop

Iteration policy: see plugins/spec-flow/reference/qa-iteration-loop.md (iter-until-clean; 3-iter circuit breaker).

Read the agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-charter.md`.

**Iteration 1 (full review):** Compose prompt with `Input Mode: Full` — interpolate all seven charter files, detection signal summary, user-supplied source list. Dispatch:

```
Agent({
  description: "Charter QA (iter 1, full)",
  prompt: <composed>,
  model: "opus"
})
```

**Iterations 2+ (focused re-review):** If iteration M-1 returned must-fix findings:

1. Read the fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-doc.md` (existing agent — no `fix-charter` exists).
2. Dispatch fix-doc with prior findings + charter files + context. The fix agent does NOT commit; it ends its report with `## Diff of changes` containing its `git diff` of the charter files.
3. Extract that diff string. Hold it in orchestrator state as `charter_iter_M_fix_diff`.
4. Re-dispatch `qa-charter` with `Input Mode: Focused re-review`, prior iteration's must-fix findings, and `charter_iter_M_fix_diff`. Do NOT re-send the full charter.
5. **Circuit breaker:** after 3 QA iterations, escalate to human.
6. If fix-doc returns `Diff of changes: (none)` (all blocked), escalate.

**Clean iteration → Phase 5.**

### Phase 5: Human sign-off

Present the seven charter files to the user for review. User approves → continue. User requests changes → make them (back to Phase 2 or 3 scoped to the requested change) → back to Phase 4 QA.

### Phase 6: Commit per file

One commit per file so `git blame` is useful:

```bash
# <charter_root> is .github or .claude, resolved in Phase 0
git add <charter_root>/skills/charter-architecture/SKILL.md && git commit -m "charter: add architecture"
git add <charter_root>/skills/charter-tools/SKILL.md && git commit -m "charter: add tools"
git add <charter_root>/skills/charter-flows/SKILL.md && git commit -m "charter: add flows"
git add <charter_root>/skills/charter-coding-rules/SKILL.md && git commit -m "charter: add coding-rules"
git add <charter_root>/skills/charter-processes/SKILL.md && git commit -m "charter: add processes"
git add <charter_root>/skills/charter-non-negotiables/SKILL.md && git commit -m "charter: add non-negotiables"
git add <charter_root>/skills/charter-integrations/SKILL.md && git commit -m "charter: add integrations"
```

### Phase 6.5: Initialize project infrastructure

After committing charter files, ensure the project infrastructure is ready for the pipeline.

1. **Create docs directory structure:**
   ```bash
   mkdir -p <docs_root>/prds
   ```
   Where `<docs_root>` resolves from `.spec-flow.yaml` (default `docs`). This is the root the `prd` skill uses to store PRDs and manifests.

2. **Create or update `.spec-flow.yaml`:**

   - If `.spec-flow.yaml` does not exist: create it from `${CLAUDE_PLUGIN_ROOT}/templates/pipeline-config.yaml`, then apply the values below.
   - If `.spec-flow.yaml` exists: update in place — preserve all other keys.

   Required values to set:
   ```yaml
   layout_version: 4
   docs_root: <docs_root>      # set if not already present
   charter_root: <charter_root>  # .github or .claude — resolved in Phase 0
   charter:
     required: true
     doctrine_load: [non-negotiables, architecture]
   ```

   ```bash
   git add .spec-flow.yaml && git commit -m "config: set layout_version 4 and enable charter stage"
   ```

   If `.spec-flow.yaml` already has `layout_version: 4` and `charter.required: true`, skip the commit (no change).

### Phase 7: Doctrine wiring reminder

The SessionStart hook auto-loads charter files listed in `.spec-flow.yaml`'s `charter.doctrine_load` (default `[non-negotiables, architecture]`). Users need to run `/reload-plugins` (or start a new session) to pick up newly-authored charter into agent doctrine context.

Inform the user after Phase 6:
> "Charter files committed. Run `/reload-plugins` (or start a new session) so downstream skills and agents pick up the charter via SessionStart doctrine load. Future runs of `prd`, `spec`, `plan`, `execute`, and `status` will read from these files automatically."

## Update Mode Workflow

Triggered when `charter-*/SKILL.md` files exist under the resolved charter root (Phase 0). Purpose: edit one or more charter files with the same Socratic+QA rigor as bootstrap, but scoped to only the touched files.

### Phase U1 — Ask which file(s) to edit

Present the seven files with their current `last committed` dates (`<charter_root>` is `.github` or `.claude`, resolved in Phase 0):

```
<charter_root>/skills/
  charter-architecture/SKILL.md      last committed: 2026-02-15
  charter-non-negotiables/SKILL.md   last committed: 2026-03-20
  charter-tools/SKILL.md             last committed: 2026-02-15
  charter-processes/SKILL.md         last committed: 2026-02-15
  charter-flows/SKILL.md             last committed: 2026-02-15
  charter-coding-rules/SKILL.md      last committed: 2026-04-01
  charter-integrations/SKILL.md      last committed: 2026-04-10
```

Read `last committed` from `git log -1 --format=%ci <charter_root>/skills/charter-<domain>/SKILL.md`.

Ask: "Which file(s) do you want to change? (comma-separated, or 'all')."

### Phase U2 — Scoped Socratic per selected file

For each selected file, run a Socratic flow scoped to that file's subject area (reuse the bootstrap Phase 2 question set for just that file). The skill proposes edits based on user answers — adds, modifications, or retirements.

**Retirement handling:** If the user wants to remove an `NN-C-xxx` or `CR-xxx` entry, ask:

> "Retire this entry (keep as tombstone in file for historical traceability — recommended) or delete entirely (removes all trace)? Retire is safer — pieces that previously cited this ID will have their citations flagged by QA, giving you a chance to upgrade them. Delete breaks that trail."

Default is **retire**. Retired entries get the tombstone format (strikethrough title + `RETIRED YYYY-MM-DD` marker + reason + list of pieces that cited them).

**Add handling:** New NN-C or CR entries get the next sequential unused ID (continuing past retired IDs — never reuse).

**Modify handling:** Keep the same ID and replace the body. Git history is the update record — do not add or maintain a `last_updated` field.

### Phase U3 — Write touched skills

Write each touched file to `<charter_root>/skills/charter-<domain>/SKILL.md`. No `last_updated` field — git history is the record.

### Phase U4 — QA on touched files only

Dispatch `qa-charter` with `Input Mode: Full`, but pass only the touched files in the prompt (not all seven). The agent's cross-file consistency checks still run — it will refer to non-touched files if the orchestrator attaches them as read-only context, but only findings on touched files are must-fix (non-touched-file drift is a different update run).

Iteration loop is the same as bootstrap mode's Phase 4 (fix-doc diff, focused re-review, 3-iter circuit breaker).

### Phase U5 — Sign-off and per-file commit

Human reviews diffs. On approval, commit each touched file separately:

```bash
git add <charter_root>/skills/charter-<domain>/SKILL.md && git commit -m "charter: update <domain> — <brief summary>"
```

### Phase U6 — Divergence awareness

After commit, check the manifest for pieces at `specced`, `planned`, or `implementing` status. For any piece whose `charter_snapshot` on any touched file is older than the newest touched charter skill commit date, inform the user:

> "The following pieces are now diverged: [list]. Run `/spec-flow:status --resolve <piece-name>` to walk through divergence resolution options."

Do NOT automatically re-spec or re-plan — human decides per piece.

## No QA Gate Between Charter Skill and User

User is directly involved throughout Socratic. The `qa-charter` agent is the only automated review.
