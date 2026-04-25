---
charter_snapshot:
  architecture: 2026-04-21
  non-negotiables: 2026-04-21
  tools: 2026-04-21
  processes: 2026-04-21
  flows: 2026-04-21
  coding-rules: 2026-04-21
---

# Plan: pi-009-hardening

**Spec:** docs/prds/shared/specs/pi-009-hardening/spec.md
**Charter:** docs/charter/ (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Implementation strategy for the v3.1.0 hardening bundle: 11 items grouped into 1 parallel Phase Group + 8 sequential flat phases. The flat phases are titled with `Group B.X` / `Group C.X` / `Phase D` suffixes for the AC-17 grep contract, while structurally remaining sequential because each group of phases edits the same SKILL.md file (which would race under parallel dispatch).

**Track choice — all phases use Implement track.** Per `docs/charter/tools.md`, spec-flow has no test runner; verification is adversarial review + manual smoke tests. TDD ceremony for markdown / config / skill-prose edits would add no payoff. Each phase's `[Verify]` step is an LLM-agent-step assertion against the produced artifact (per FR-13's framing this piece itself introduces).

**Phase Group A — capability work, parallel.** All four sub-phases edit disjoint files and have no symbol dependencies. Group dispatches concurrently per the Phase Group scheduler.

**Phase Group B — orchestrator hardening, sequential.** All four phases edit `plugins/spec-flow/skills/execute/SKILL.md` (Step 6 Phase QA, Phase Scheduler, Phase Group Loop). Sequential because concurrent edits to the same file race. Numbered as Phases 2–5 with `Group B.1` … `Group B.4` titles for AC-17 grep matching.

**Phase Group C — plan-skill rules, sequential.** All three phases edit `plugins/spec-flow/skills/plan/SKILL.md` Phase 2 (Generate Plan) section. Sequential for the same single-file reason. Numbered as Phases 6–8 with `Group C.1` … `Group C.3` titles.

**Phase D — release ceremony.** Single flat phase that materializes the v3.1.0 release artifacts (3-place version bump + CHANGELOG entry). The squash-merge commit (a maintainer action outside the plan) is what AC-15/AC-16/AC-17 ultimately check; Phase D ensures the working-tree state at the feature-branch tip carries the right artifacts so the squash-merge commit inherits them.

**Mid-piece Opus QA pass (FR-9 dog-food).** This piece has 9 phases. ⌈9/2⌉ = 5, so a mid-piece Opus QA pass dispatches between Phase 5 (Group B.4) and Phase 6 (Group C.1) if the first 5 phases all auto-skipped Opus. In practice some early phases (Group A.2 status `--include-drift` parsing, Group B.1 skip-predicate sharpening, Group B.3 deferred-finding orchestrator hook) ship real control-flow logic that the sharpened skip predicate (FR-8, this same piece) routes to Opus. Whether the mid-piece pass actually fires therefore depends on actual predicate outcomes — captured as a process-retro observation in `learnings.md`, not a planned dispatch.

## Phases

Each phase uses exactly ONE of two tracks:

- **TDD track** — phase contains `[TDD-Red]`. Use for behavior-bearing code that benefits from test-driven design.
- **Implement track** — phase contains `[Implement]` (and NO `[TDD-Red]`). Use for config, infrastructure, scaffolding, glue/wiring code, docs-as-code, fixtures, and migrations.

This piece uses **Implement track exclusively** — no test runner exists in this repo (`docs/charter/tools.md`), and all deliverables are markdown / YAML / skill-prose edits.

---

## Phase Group A: Capability work (parallel)

**Exit Gate:** all sub-phases pass their `[Verify]` checks + group-level `[QA]` Opus deep review returns must-fix=None (iter-until-clean per FR-14).
**ACs Covered:** AC-1, AC-2, AC-3, AC-4 (partial — A.3 covers v3-path-conventions.md + spec/prd SKILL.md; A.2 covers status; A.4 covers migrate; full AC-4 closure also requires Phase 2 / B.1 coverage of execute/SKILL.md and Phase 6 / C.1 coverage of plan/SKILL.md), AC-5, AC-6
**Charter constraints honored at group level:** none beyond per-sub-phase allocations below; group dispatch itself follows existing `## Phase Group Loop` rules in `plugins/spec-flow/skills/execute/SKILL.md`.

#### Sub-Phase A.1 [P]: PI-008 spec amendment (CAP-1 / FR-1)
**Scope:** docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/spec.md
**ACs:** AC-1
**Charter constraints honored in this sub-phase:**
- NN-P-001 (artifacts human-readable): the PI-008 spec amendment is plain-markdown additions inside `docs/`. No binary content, no obfuscated formatting.

- [x] **[Implement]** Amend PI-008 spec FR-005 + add three new ACs.
  - Order:
    1. Locate FR-005 in `docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/spec.md` (the section currently prescribing three branches per piece).
    2. Replace the FR-005 body with the single-branch contract: "A piece uses a single shared `spec/<prd-slug>-<piece-slug>` branch from spec authoring through plan and execute. The same branch carries spec, plan, and execute commits; squash-merge collapses them into one merge commit on master at release time. Slug validity for both `<prd-slug>` and `<piece-slug>` is enforced by `plugins/spec-flow/reference/slug-validator.md`."
    3. Append three new ACs (AC-21, AC-22, AC-23) to PI-008's spec.md after the existing AC-20:
       - **AC-21** Given a new piece begins spec authoring, When the spec skill creates the worktree branch, Then the branch is `spec/<prd-slug>-<piece-slug>` and is the only branch created. Independent test: `git branch | grep -E "^\s*\* spec/" | wc -l` returns 1 on the worktree.
       - **AC-22** Given a piece's plan skill runs after spec sign-off, When the plan skill commits plan.md, Then the commit lands on the same `spec/<prd-slug>-<piece-slug>` branch (no new `plan/...` branch is created). Independent test: `git log --all --oneline | grep "plan: add"` shows the commit on the existing `spec/...` branch.
       - **AC-23** Given a piece's execute skill runs phases, When per-phase commits land, Then they all land on the same `spec/<prd-slug>-<piece-slug>` branch (no new `execute/...` branch is created). Independent test: `git log --all --oneline --graph` on the worktree shows a single linear branch from the spec commit through all execute phase commits, with no branch divergence/re-converge.
    4. Add a one-line note at the bottom of PI-008's spec.md `## Open Questions` section linking to this v3.1.0 amendment: `Resolved 2026-04-25 by pi-009-hardening (CAP-1 / FR-1) — single-branch model adopted; rationale in pi-009-hardening/spec.md CAP-1 paragraph.`
    5. Update PI-008's spec.md `charter_snapshot:` front-matter `non-negotiables:` to today's date if it's the only one stale; otherwise leave snapshot dates unchanged (the amendment doesn't change which charter entries are honored).
  - Files: `docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/spec.md`
  - Pattern pointers: existing AC format in PI-008 spec.md lines covering AC-1 through AC-20 (Given/When/Then + Independent test).
  - Architecture constraints: NN-P-001 — markdown only, no binary content.

- [x] **[Verify]** Confirm AC-1 holds.
  - Run check 1: `grep -c "single shared" docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/spec.md` → returns ≥ 1.
  - Run check 2: `grep -c "AC-2[123]" docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/spec.md` → returns 3.
  - Run check 3: LLM-agent reads the amended FR-005 paragraph and confirms it (a) names the single-branch model, (b) cites slug-validator.md, (c) does not contradict any other PI-008 FR.
  - Expected: all three checks pass.

- [x] **[QA-lite]** Sonnet narrow review.
  - Scope: this sub-phase only.
  - Review: AC-1 binding, no inadvertent edits to other PI-008 ACs, charter snapshot integrity.

#### Sub-Phase A.2 [P]: status-skill `--include-drift` mode (CAP-2 / FR-2, FR-3)
**Scope:** plugins/spec-flow/skills/status/SKILL.md
**ACs:** AC-2, AC-3, AC-4 (partial — covers status/SKILL.md)
**Charter constraints honored in this sub-phase:**
- NN-C-005 (hooks silently no-op on missing optionals): the `--include-drift` parsing logic returns "No citation drift detected across N specs" (with N=0 valid) when no specs exist, when `<docs_root>/specs/` is empty, or when individual specs lack the `### Non-Negotiables Honored` / `### Coding Rules Honored` sections. No error, no stderr noise. Exit 0.
- CR-009 (heading hierarchy): the new `## Step N: Charter-drift deep scan (`--include-drift`)` section sits at H2 alongside the existing status-skill Step headings; sub-bullets at H3 only.

- [x] **[Implement]** Extend `/spec-flow:status` with `--include-drift` mode + token sweep on this file.
  - Order:
    1. At the top of `plugins/spec-flow/skills/status/SKILL.md`, in the `## Workflow` introduction, add: `Invoked as /spec-flow:status [--include-drift]. The --include-drift flag enables the citation-drift deep scan defined below.`
    2. Add a new section `## Citation drift deep scan (--include-drift, FR-2 / FR-3)` after the existing `## Divergence Resolution` section. Body:
       - Skip the section unless invoked with `--include-drift`. (The default `/spec-flow:status` invocation never executes this section.)
       - Walk every `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/spec.md` (per `plugins/spec-flow/reference/v3-path-conventions.md`). For each spec:
         - Extract IDs from the `### Non-Negotiables Honored` block. Match `NN-C-[0-9]+` and `NN-P-[0-9]+` patterns.
         - Extract IDs from the `### Coding Rules Honored` block. Match `CR-[0-9]+` patterns.
         - For each `NN-C-` ID: confirm the heading `### NN-C-N:` exists in `<docs_root>/charter/non-negotiables.md`. If not present (or under a `RETIRED` tombstone marker), record drift.
         - For each `NN-P-` ID: confirm the heading `### NN-P-N:` exists in `<docs_root>/prds/<prd-slug>/prd.md`. Drift if absent or retired.
         - For each `CR-` ID: confirm the heading `### CR-N:` exists in `<docs_root>/charter/coding-rules.md`. Drift if absent or retired.
       - Output format:
         - On drift found: print `Citation drift in <spec-path>: cited <ID> not present in <expected-charter-file>` for each drift; one line per offence. Exit code non-zero (specifically: 2).
         - On no drift: print `No citation drift detected across <N> specs.` where N is the count of specs scanned (including N=0). Exit 0.
       - Document the missing-section behavior: when a spec lacks both the `### Non-Negotiables Honored` and `### Coding Rules Honored` sections, treat as "no citations to verify" — count the spec, do not flag drift.
       - Document the missing-charter-file behavior: when `docs/charter/non-negotiables.md`, `docs/charter/coding-rules.md`, or the PRD file is absent, return "No citation drift detected across N specs." with a stderr note `note: charter file <path> absent; <K> NN-C/NN-P/CR citations not verified.` Exit 0 (per NN-C-005).
    3. Token sweep: replace literal `worktrees/` references in the existing status SKILL.md with `{{worktree_root}}` where they appear in `## Step 4: Check worktrees` documentation prose and any Agent({...}) dispatch templates. Preserve the `## Step 0: Load Config` preamble line documenting the `worktrees_root` config-key resolution rule (per FR-5 exemption).
  - Files: `plugins/spec-flow/skills/status/SKILL.md`
  - Pattern pointers: `## Workflow` numbered-step structure already used by the file; existing `## Divergence Resolution` section is the closest sibling to the new section in tone and depth.
  - Architecture constraints: CR-008 — this is orchestrator-side logic (the skill itself), not an agent. No new agent file is created.

- [x] **[Verify]** Confirm AC-2 + AC-3.
  - Setup: the LLM agent creates a synthetic spec at `/tmp/drift-test-spec.md` with `### Non-Negotiables Honored\n- **NN-C-099 (does-not-exist):** ...` and runs the drift scan logic mentally against the current `docs/charter/non-negotiables.md`.
  - Verify check 1 (AC-2): the synthetic spec triggers `Citation drift in /tmp/drift-test-spec.md: cited NN-C-099 not present in docs/charter/non-negotiables.md` — one drift line, exit code 2.
  - Verify check 2 (AC-3): a separate synthetic input with only valid NN-C-002, NN-C-003 citations triggers `No citation drift detected across 1 specs.` exit 0.
  - Verify check 3 (worktree-token sweep): `grep -E 'worktrees/(prd|<prd|prd-)' plugins/spec-flow/skills/status/SKILL.md` returns matches only on lines documenting the `worktrees_root` config-key resolution rule (Step 0 preamble) or referencing v3-path-conventions.md — no Agent dispatch template carries a literal `worktrees/...` path.
  - Expected: all three checks pass; the LLM agent reports any drift line that doesn't match the expected format inline.

- [x] **[QA-lite]** Sonnet narrow review.
  - Scope: this sub-phase only.
  - Review: AC-2/AC-3 binding, FR-2/FR-3 contract coverage, NN-C-005 no-op compliance for missing-input branches.

#### Sub-Phase A.3 [P]: worktree-token resolver doc + sweep on spec/prd SKILL.md (CAP-3 / FR-4, FR-5 partial)
**Scope:** plugins/spec-flow/reference/v3-path-conventions.md, plugins/spec-flow/skills/spec/SKILL.md, plugins/spec-flow/skills/prd/SKILL.md
**ACs:** AC-4 (partial — A.3 covers the spec/prd files; B.1 covers execute/SKILL.md; A.2 covers status/SKILL.md; A.4 covers migrate/SKILL.md; C.1 covers plan/SKILL.md)
**Charter constraints honored in this sub-phase:**
- CR-005 (repo-root-relative paths in docs): the new token's documented resolution `worktrees/prd-<prd-slug>/piece-<piece-slug>` is repo-root-relative; all examples in the v3-path-conventions.md addition use repo-root-relative path notation.

- [x] **[Implement]** Define `{{worktree_root}}` token + apply sweep to spec + prd SKILLs.
  - Order:
    1. In `plugins/spec-flow/reference/v3-path-conventions.md`, append a new section `## Worktree-root template token (`{{worktree_root}}`)` after the existing `## Cross-references to slug validator` section. Body:
       - `{{worktree_root}}` is a template token that resolves to `worktrees/prd-<prd-slug>/piece-<piece-slug>` at orchestrator dispatch time. The orchestrator derives the slug pair from the active piece in `<docs_root>/prds/<prd-slug>/manifest.yaml`.
       - Skill SKILL.md files use `{{worktree_root}}` in Agent({...}) dispatch templates and worktree-path documentation references in place of literal `worktrees/...` paths.
       - Exemption: `## Step 0: Load Config` preamble lines documenting the `worktrees_root` config-key resolution rule retain literal `worktrees/` text — they document the config key, not a dispatch path.
       - Resolution failure mode: when the token is rendered outside an active piece worktree (e.g., on master with no piece slug discoverable), the orchestrator emits a stderr warning `note: {{worktree_root}} unresolved — no active piece` and substitutes the empty string. The dispatched agent receives the unresolved string verbatim, which surfaces as a path error downstream. (Per NN-C-005, the resolver itself does not abort.)
    2. Sweep `plugins/spec-flow/skills/spec/SKILL.md`: replace literal `worktrees/...` paths in Agent({...}) dispatch templates and worktree-path documentation references with `{{worktree_root}}`. Preserve the `## Step 0: Load Config` preamble line documenting `worktrees_root`.
    3. Sweep `plugins/spec-flow/skills/prd/SKILL.md`: same as step 2.
  - Files: `plugins/spec-flow/reference/v3-path-conventions.md`, `plugins/spec-flow/skills/spec/SKILL.md`, `plugins/spec-flow/skills/prd/SKILL.md`
  - Pattern pointers: existing v3-path-conventions.md sections (`## Layout`, `## Path resolution`, `## Layout version detection`, `## Cross-references to slug validator`) — append at the same H2 level.
  - Architecture constraints: CR-005 — repo-root-relative paths in all examples.

- [x] **[Verify]** Confirm token spec + sweep correctness.
  - Run check 1: `grep -A 10 "Worktree-root template token" plugins/spec-flow/reference/v3-path-conventions.md | grep -E "{{worktree_root}}|worktrees/prd-<prd-slug>"` returns ≥ 2 matches (token + resolution form).
  - Run check 2 (sweep on spec/SKILL.md): `grep -E 'worktrees/(prd|<prd|prd-)' plugins/spec-flow/skills/spec/SKILL.md` returns matches only on `## Step 0: Load Config` preamble or v3-path-conventions.md reference lines.
  - Run check 3 (sweep on prd/SKILL.md): same grep on prd/SKILL.md returns matches only on the same allowed patterns.
  - Run check 4: `grep -c "{{worktree_root}}" plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/prd/SKILL.md` returns ≥ 2 (at least one token use per swept SKILL.md).
  - Expected: all four checks pass; LLM-agent reports any preserved literal `worktrees/...` outside the allowed contexts inline.

- [x] **[QA-lite]** Sonnet narrow review.
  - Scope: this sub-phase only.
  - Review: FR-4 token resolution contract, FR-5 sweep correctness, CR-005 repo-root-relative path discipline.

#### Sub-Phase A.4 [P]: migrate-skill environment precondition + NFR-004 amendment (CAP-4 / FR-6, FR-7)
**Scope:** plugins/spec-flow/skills/migrate/SKILL.md, docs/prds/shared/prd.md
**ACs:** AC-5, AC-6, AC-4 (partial — covers migrate/SKILL.md)
**Charter constraints honored in this sub-phase:**
- NN-C-002 (no runtime deps): the new `## Environment preconditions` section frames `git`, POSIX shell, and LLM-agent runtime as host expectations on the migrating LLM operator's environment, NOT as project-level runtime dependencies under `plugins/`. The section explicitly states "These capabilities live in the LLM agent's runtime, not in the user's installed plugin." No new files appear under `plugins/spec-flow/` that require runtime tooling.

- [x] **[Implement]** Add environment-preconditions section + amend NFR-004 + sweep on migrate/SKILL.md.
  - Order:
    1. In `plugins/spec-flow/skills/migrate/SKILL.md`, add a new section `## Environment preconditions` immediately after the `## Prerequisites` section (or after `## Step 0: Load Config` if there is no `## Prerequisites` section). Body:
       - Three host-side capabilities are required to run this skill:
         - **LLM-driven execution context with file-reading and inline YAML/JSON parsing.** The migrate skill is authored as natural-language instructions the LLM agent follows; every read-and-rewrite step uses the agent's native parsing capability. No specific language runtime is mandated.
         - **`git` ≥ 2.5** — required for `git mv` (history-preserving rename) and `git status --short` parsing.
         - **POSIX shell** — required for `cd`, `mkdir -p`, and `git` invocation.
       - Explicitly: no `python3`, `yq`, `jq`, `ruby`, `node`, or any other external parser/runtime is required. These tools may be present on the host, but the migrate skill does not invoke them.
       - Closing line: "These capabilities live in the LLM agent's runtime, not in the user's installed plugin. NN-C-002 binds plugin-internal runtime dependencies; this skill ships only markdown text."
    2. In `docs/prds/shared/prd.md`, locate `**NFR-004:**` and append at the end of its body: " — including documenting environment preconditions for skills that operate on user repos. The `plugins/spec-flow/skills/migrate/SKILL.md` skill's `## Environment preconditions` section is the canonical example: skills that prescribe host-side actions document the host-side capabilities they assume."
    3. Token sweep on `plugins/spec-flow/skills/migrate/SKILL.md`: replace literal `worktrees/...` paths in Agent({...}) dispatch templates and worktree-path documentation references with `{{worktree_root}}`. Preserve the `## Step 0: Load Config` preamble line.
  - Files: `plugins/spec-flow/skills/migrate/SKILL.md`, `docs/prds/shared/prd.md`
  - Pattern pointers: existing `## Step 0: Load Config` and `## Prerequisites` sections in migrate/SKILL.md provide the H2 / H3 hierarchy template; existing NFR-001/NFR-002/NFR-003 entries in the PRD provide the NFR amendment style.
  - Architecture constraints: NN-C-002 — no new runtime-dependency artifacts under `plugins/`.

- [x] **[Verify]** Confirm AC-5 + AC-6.
  - Run check 1 (AC-5): `grep -A 10 "Environment preconditions" plugins/spec-flow/skills/migrate/SKILL.md | grep -E "git|POSIX|LLM"` returns matches for all three anchors (one per capability).
  - Run check 2 (AC-5 agnostic framing): `grep -A 15 "Environment preconditions" plugins/spec-flow/skills/migrate/SKILL.md | grep -E "no specific language runtime|no external"` returns ≥ 1 match.
  - Run check 3 (AC-6): `grep -A 3 "NFR-004" docs/prds/shared/prd.md | grep "skills/migrate/SKILL.md"` returns ≥ 1 match.
  - Run check 4 (sweep): `grep -E 'worktrees/(prd|<prd|prd-)' plugins/spec-flow/skills/migrate/SKILL.md` returns matches only on Step 0 preamble or v3-path-conventions.md reference lines.
  - Expected: all four checks pass.

- [x] **[QA-lite]** Sonnet narrow review.
  - Scope: this sub-phase only.
  - Review: NN-C-002 honoring (LLM-agent-runtime vs plugin-runtime distinction is concrete), AC-5/AC-6 binding, NFR-004 amendment doesn't break existing NFR cross-references.

#### Group-level tasks
- [x] **[Refactor]** (optional — auto-skipped when all sub-phase Builds clean per `refactor: auto` in `.spec-flow.yaml`).
  - Scope: union of A.1–A.4 file paths.
  - Check for: cross-sub-phase duplication (none expected — sub-phases are scoped to disjoint files).
  - Constraint: only modify files created/changed in this group.

- [x] **[QA]** Opus deep review (iter-until-clean per FR-14 — applies even though this piece introduces FR-14 to the orchestrator; the spec/plan QA gates already follow the iter-until-clean pattern via the spec/plan skill QA loops, and the plan-skill citations of `qa-iteration-loop.md` happen in Phase 5 / Group B.4).
  - Review against: AC-1, AC-2, AC-3, AC-4 (partial), AC-5, AC-6.
  - Diff baseline: `git diff <group_a_start_sha>..HEAD`.
  - Surface map composed by orchestrator: files changed (from the four sub-phase scope blocks), public symbols (`{{worktree_root}}` token contract, `--include-drift` flag), integration callers (skills that reference v3-path-conventions.md).

- [x] **[Progress]** Single squash-style commit for the group with message `phase(pi-009-hardening): group A — capability work (CAP-1 + CAP-2 + CAP-3 partial + CAP-4)`.

---

### Phase 2 (Group B.1): ORC-1 sharpen Opus QA skip-predicate (FR-8)
**Exit Gate:** the new skip-predicate text in `plugins/spec-flow/skills/execute/SKILL.md` ran through `[Verify]`'s three synthetic-diff checks and produced the [skip, do-not-skip, do-not-skip] outcomes per AC-7.
**ACs Covered:** AC-7, AC-4 (partial — covers execute/SKILL.md)
**Charter constraints honored in this phase:**
- CR-008 (skills orchestrate, agents execute): the sharpened skip predicate lives entirely inside `skills/execute/SKILL.md` (orchestrator-side) — no agent file gains skip-decision logic. The predicate's classification of a phase-diff is computed before any QA agent dispatch and inlined into the dispatch decision.

- [x] **[Implement]** Sharpen the Opus QA skip predicate in execute SKILL.md.
  - Order:
    1. Locate the existing skip-rationale prose in `plugins/spec-flow/skills/execute/SKILL.md` Step 6 (the Phase QA dispatch logic in the existing ### Step 6: Phase QA section — the section that today reads .spec-flow.yaml's qa_iter2 key and conditionally skips the iter-2 re-dispatch of the QA agent — semantic anchor: the multi-paragraph block that begins with the words "Conditional skip of re-dispatch"). The existing prose treats "small or structural / mechanical / N-LOC change" as a skip trigger.
    2. Replace the existing skip rationale with a structured predicate:
       - **Skip Opus QA only when** all three conditions hold for the phase diff:
         - (a) **Diff content** is composed exclusively of: added markdown sections / paragraphs / lists, added or modified YAML keys with literal scalar values, or added comments and whitespace.
         - (b) **No file** in the diff is under `plugins/*/skills/*/SKILL.md` AND newly created (a new skill body always routes to Opus regardless of LOC).
         - (c) **No file** in the diff contains a script in any procedural language with branching control-flow constructs (conditionals, loops, short-circuit operators). The detection pattern set targets shell-style constructs (since spec-flow's hooks are shell scripts today) — extensible if spec-flow ever adopts hooks in another language.
       - **Otherwise route to Opus.** "Small LOC" is no longer sufficient justification for skipping; control-flow density is the actual risk signal.
    3. Add a worked-example block immediately after the predicate text:
       - Example A (skip): a phase that adds three new H3 sections to a SKILL.md file with no code blocks. → all three conditions hold → skip Opus.
       - Example B (do not skip): a phase that adds a 14-line bash hook with one `if` block to `plugins/spec-flow/hooks/`. → condition (c) fails → route to Opus.
       - Example C (do not skip): a phase that creates a new `plugins/spec-flow/skills/<name>/SKILL.md` file. → condition (b) fails → route to Opus.
    4. Token sweep on execute/SKILL.md: replace literal `worktrees/...` paths in Agent({...}) dispatch templates and worktree-path documentation references with `{{worktree_root}}`. Preserve `## Step 0: Load Config` preamble.
  - Files: `plugins/spec-flow/skills/execute/SKILL.md`
  - Pattern pointers: the existing Step 6 inline skip-rationale prose is the structural anchor — replace inline. The worked-example pattern matches Step G6's auto-triage decision matrix style (table with conditions + example outcomes).
  - Architecture constraints: CR-008 — predicate stays inside the skill body, no agent dispatch involved in the predicate evaluation itself.

- [x] **[Verify]** AC-7 plus the implicit token-sweep check.
  - Run check 1 (AC-7 example A): the LLM agent constructs a synthetic phase diff containing only `+## New section\n+content paragraph` additions to a markdown file, reads the new skip-predicate text from execute/SKILL.md, and confirms the predicate would return "skip" (all three conditions hold).
  - Run check 2 (AC-7 example B): the LLM agent constructs a synthetic phase diff containing `+if [ -z "$X" ]; then\n+  echo "fallback"\n+fi` added to a `hooks/` file, reads the predicate, and confirms it would return "do not skip" (condition (c) fails on the `if`/control-flow construct).
  - Run check 3 (AC-7 example C): the LLM agent constructs a synthetic diff that creates a new file `plugins/spec-flow/skills/example/SKILL.md` with frontmatter only, reads the predicate, and confirms it would return "do not skip" (condition (b) fails on new SKILL.md).
  - Run check 4 (token sweep): `grep -E 'worktrees/(prd|<prd|prd-)' plugins/spec-flow/skills/execute/SKILL.md` returns matches only on Step 0 preamble or v3-path-conventions.md reference lines.
  - Expected: all four checks pass; the predicate text is unambiguous enough that the LLM agent's reading produces the same outcome a programmatic implementation would.

- [ ] **[QA]** Phase review (iter-until-clean).
  - Review against: AC-7.
  - Diff baseline: `git diff <phase_2_start_sha>..HEAD`.

---

### Phase 3 (Group B.2): ORC-2 mid-piece Opus QA pass for ≥6-phase pieces (FR-9)
**Exit Gate:** the new mid-piece dispatch logic in `plugins/spec-flow/skills/execute/SKILL.md` ran through `[Verify]`'s synthetic 6-phase scenario and produced a dispatch record at the correct insertion point per AC-8.
**ACs Covered:** AC-8
**Charter constraints honored in this phase:**
- NN-C-008 (agent prompts self-contained): the mid-piece QA pass dispatches the existing `qa-phase` Opus agent with a fresh, self-contained prompt — the prompt carries (a) the cumulative diff `git diff <piece_start_sha>..HEAD`, (b) the full spec.md text, (c) the AC matrix, (d) explicit instructions for mid-piece-pass review focus. The dispatched agent does NOT see prior per-phase QA reports or session conversation history.
- NN-P-002 (no auto-merge without human sign-off): the mid-piece pass is added BEFORE the existing per-phase QA + Final Review gates — additive, not a replacement. Human sign-off gates remain unchanged.

- [ ] **[Implement]** Add mid-piece Opus QA pass dispatch logic.
  - Order:
    1. In `plugins/spec-flow/skills/execute/SKILL.md`, in the existing `## Per-Phase Loop` section (the H2 heading that introduces the for-each-phase iteration; semantic anchor: the line "For each phase in plan.md (skip phases where all checkboxes are [x])"), add a new step `### Step 0a: Mid-piece Opus QA pass (FR-9)` BEFORE Step 1 (Capture Phase Start SHA). Body:
       - At the start of each phase iteration, evaluate the mid-piece trigger:
         - Let `N` = total number of phases declared in `plan.md` (count of `### Phase <num>` and `## Phase Group <letter>` headings, where each Phase Group counts as one phase from the scheduler's view).
         - Let `K` = ⌈N / 2⌉.
         - If `N ≥ 6` AND the current phase is phase number `K + 1` (i.e., the first phase past the half-way point) AND every phase from 1 through K returned `skip` from the Step 6 skip-predicate, dispatch a mid-piece Opus QA pass before continuing.
       - Mid-piece pass dispatch:
         - Compose prompt from `plugins/spec-flow/agents/qa-phase.md` template, with `Input Mode: Mid-piece full review` (a new mode label distinct from per-phase iter-1):
           - Cumulative diff: `git diff <piece_start_sha>..HEAD` output.
           - Full `spec.md` text.
           - AC matrix produced so far (collected from each phase's `[Verify]` step output).
           - Charter files cited in the spec's `### Non-Negotiables Honored` and `### Coding Rules Honored` sections, attached as raw text.
         - Dispatch:
           ```
           Agent({
             description: "Mid-piece QA for <piece-name> (phase K+1)",
             prompt: <composed>,
             model: "opus"
           })
           ```
         - Run iter-until-clean per FR-14: if the mid-piece pass returns must-fix findings, dispatch fix-code with the findings, re-dispatch qa-phase in `Input Mode: Focused re-review`, repeat until must-fix=None. Apply the 3-iter circuit breaker.
       - On clean: log `mid_piece_opus_pass: dispatched` with iteration count for the session summary; continue to Step 1.
       - On circuit-breaker escalation: surface to human; do not auto-resume.
    2. Update the `## Per-Phase Loop` introduction prose to mention Step 0a as the new first sub-step.
    3. Update the session-summary metrics text in the existing `### Step 7: Mark Progress` (or wherever metrics emit) to include `mid_piece_opus_pass: <dispatched|not-triggered|escalated>`.
  - Files: `plugins/spec-flow/skills/execute/SKILL.md`
  - Pattern pointers: existing `### Step 6: Phase QA` section's Agent({...}) dispatch block (semantic anchor: the line that reads description: "Phase QA for <piece-name>" or analogous) for `Agent({...})` invocation style; existing iter-2 fix-code → qa-phase re-dispatch pattern for the iter-until-clean integration.
  - Architecture constraints: NN-C-008 — composed prompt is fully self-contained; NN-P-002 — mid-piece pass is additive to existing gates; CR-008 — orchestrator-side decision logic, agent dispatch is the existing qa-phase template.

- [ ] **[Verify]** AC-8 (synthetic 6-phase trigger).
  - Run check 1: the LLM agent constructs a synthetic plan.md with 6 phases, reads execute/SKILL.md's new Step 0a, and confirms the trigger fires before phase 4 (since K = ⌈6/2⌉ = 3, the trigger fires on phase K+1 = 4) when phases 1–3 all returned skip.
  - Run check 2: the LLM agent confirms the dispatched prompt would contain (a) `git diff <piece_start_sha>..HEAD` cumulative output, (b) full spec.md text, (c) AC matrix produced so far, (d) referenced charter files.
  - Run check 3: synthetic scenario where N = 5 → trigger does NOT fire (N < 6). LLM agent confirms.
  - Run check 4: synthetic scenario where N = 6 but phase 2 returned do-not-skip → trigger does NOT fire (not all phases 1..K returned skip). LLM agent confirms.
  - Expected: all four scenarios produce correct trigger outcomes when the LLM agent reads Step 0a's text.

- [ ] **[QA]** Phase review (iter-until-clean).
  - Review against: AC-8.
  - Diff baseline: `git diff <phase_3_start_sha>..HEAD`.

---

### Phase 4 (Group B.3): ORC-3 deferred-finding tracking (FR-10)
**Exit Gate:** the orchestrator-side hook for `Deferred to reflection:` markers ran through `[Verify]`'s synthetic agent-report scenario and produced the expected backlog-stub diff + commit per AC-9.
**ACs Covered:** AC-9
**Charter constraints honored in this phase:**
- (none beyond the universal ones — orchestrator-side parser; the backlog stub is plain markdown per NN-P-001 already allocated to A.1.)

- [ ] **[Implement]** Add deferred-finding parser + backlog-stub writer to execute SKILL.md.
  - Order:
    1. In `plugins/spec-flow/skills/execute/SKILL.md`, in the existing `### Step 6: Phase QA` section, immediately after the iter-until-clean loop dispatch logic and before the proceed-to-Step-7 line (semantic anchor: the prose "When QA returns must-fix=None ... proceed to Step 7"), add:
       - **Step 6a: Deferred-finding tracking (FR-10)**
         - When the QA agent's report (any iteration) contains the literal string `Deferred to reflection:` (case-insensitive), the orchestrator parses each occurrence and appends a stub to the PRD-local backlog.
         - For each match:
           - Extract the deferring reviewer's agent name (from the dispatch context — `qa-phase`, `qa-phase-lite`, or `qa-spec`/`qa-plan`/`qa-charter` for spec/plan/charter QA).
           - Extract the verbatim finding text (the prose immediately following `Deferred to reflection:` up to the next blank line or list-item boundary).
           - Capture the current HEAD commit SHA (`git rev-parse HEAD` — at deferral time, before any subsequent fix-code or progress commits).
           - Append a structured stub to `<docs_root>/prds/<prd-slug>/backlog.md`:
             ```markdown
             ## [Deferred QA finding] <date> — <piece-slug>

             - **Deferring reviewer:** <agent-name>
             - **Captured at commit:** <sha>
             - **Finding (verbatim):** <prose>
             - **Status:** unresolved — reflection step (4.5) classifies as incorporated / deferred / obsolete.
             ```
           - Commit the backlog edit on the piece branch:
             ```
             git add <docs_root>/prds/<prd-slug>/backlog.md
             git commit -m "chore(<piece-slug>): record deferred QA finding"
             ```
         - The orchestrator does NOT block phase progression on deferred findings — the iter-until-clean loop terminates when must-fix=None, and `Deferred to reflection:` items are not counted as must-fix.
         - Step 4.5 (end-of-piece reflection) reads the backlog file and prompts the user to classify each `[Deferred QA finding]` entry: incorporated (resolved within this piece), deferred (move to active backlog as a future piece candidate), or obsolete (no longer applies).
    2. Add a one-line note to the `qa-phase` and `qa-phase-lite` agent templates (under `plugins/spec-flow/agents/`) — actually, NO: per CR-008 + NN-C-008, the agent templates remain self-contained and unchanged. The marker `Deferred to reflection:` is a recommended convention the agent uses voluntarily; the orchestrator parses it from the report but does not require the agent to emit it. (This sub-step is intentionally not done.)
    3. Update session-summary metrics (in Step 7 or wherever) to include `deferred_findings_recorded: <N>` per piece.
  - Files: `plugins/spec-flow/skills/execute/SKILL.md`
  - Pattern pointers: existing `### Step 6` iter-until-clean fix-code dispatch logic provides the model for "after QA returns, do orchestrator-side bookkeeping before proceeding"; existing PRD-local `backlog.md` markdown structure (sample template at `plugins/spec-flow/templates/backlog.md`) provides the stub format pattern.
  - Architecture constraints: CR-008 — orchestrator does the parsing + writing; the agent only emits a marker if it chooses. NN-C-008 — agent prompt is unchanged (no instruction to emit the marker is added to agent templates; the convention is documented in the orchestrator-side prose).

- [ ] **[Verify]** AC-9.
  - Run check 1: the LLM agent constructs a synthetic qa-phase report at `/tmp/synthetic-qa-report.md` containing `### must-fix\nNone\n\n### acceptable\n...\n\n### Deferred to reflection: spec FR-005 single-branch ambiguity unresolved`.
  - Run check 2: the LLM agent reads execute/SKILL.md Step 6a, traces what the orchestrator would do on this synthetic report, and confirms the produced backlog stub:
    - Heading: `## [Deferred QA finding] 2026-04-25 — pi-009-hardening`
    - Bullets: deferring reviewer = `qa-phase`, captured at commit = current HEAD SHA, finding verbatim = `spec FR-005 single-branch ambiguity unresolved`, status = `unresolved`.
  - Run check 3: confirm the commit message is `chore(pi-009-hardening): record deferred QA finding`.
  - Expected: the trace produces a stub file diff and a commit that match the spec.

- [ ] **[QA]** Phase review (iter-until-clean).
  - Review against: AC-9.
  - Diff baseline: `git diff <phase_4_start_sha>..HEAD`.

---

### Phase 5 (Group B.4): ORC-7 iter-until-clean reference doc + skill citations (FR-14, FR-15)
**Exit Gate:** the new `plugins/spec-flow/reference/qa-iteration-loop.md` reference doc exists with the four required anchors per AC-13, and all four QA-running skills cite it per AC-14.
**ACs Covered:** AC-13, AC-14
**Charter constraints honored in this phase:**
- NN-C-003 (backwards-compat within major): the `qa_iter2` config key is RETAINED in `plugins/spec-flow/templates/pipeline-config.yaml` with a `# DEPRECATED in 3.1.0 — see plugins/spec-flow/reference/qa-iteration-loop.md` inline comment block. Users with `qa_iter2: auto` or `qa_iter2: always` in their `.spec-flow.yaml` continue to load without error or warning. Only the orchestrator-side read-and-act-on logic is removed.
- CR-002 (skill frontmatter schema): all four QA-running SKILL.md files (`spec`, `plan`, `charter`, `execute`) preserve their existing `name:` / `description:` frontmatter; only body content gains the citation line.
- CR-007 (config keys documented inline): the deprecation comment block in `pipeline-config.yaml` cites `qa-iteration-loop.md` and explains why the key's effect is neutralized — fulfilling CR-007's "purpose, valid values, default, rationale" rule for the deprecated state.

- [ ] **[Implement]** Create reference doc + sweep citations + retire orchestrator-side qa_iter2 reads.
  - Order:
    1. Create `plugins/spec-flow/reference/qa-iteration-loop.md` (new file, ~80 LOC). Body structure (H2 sections):
       - `# QA iteration loop (iter-until-clean)`
       - `## Purpose` — one paragraph: every QA gate iterates until must-fix=None; the 3-iter circuit breaker is the escalation guard, not an auto-stop.
       - `## Iteration numbering` — explicit numbering rules:
         - **iter-N** = the Nth dispatch of the QA reviewer agent for a single QA gate.
         - Between iter-N and iter-(N+1), the orchestrator dispatches `fix-doc` (for spec/plan/charter QA) or `fix-code` (for execute per-phase QA + group QA + mid-piece QA + Final Review fix-up) once.
         - The 3-iter circuit breaker fires when iter-3 returns ≥ 1 must-fix finding — at that point the orchestrator escalates to the human and does NOT dispatch iter-4.
       - `## Input modes`:
         - **iter-1: Full** — the dispatched agent receives the complete artifact (spec.md / plan.md / charter file / phase diff). Apply all review criteria.
         - **iter-2+: Focused re-review** — the dispatched agent receives the prior iter's must-fix findings + the fix-doc/fix-code unified diff. Do NOT re-examine unchanged sections.
       - `## Iteration termination` — must-fix=None terminates the loop and proceeds. Circuit-breaker termination escalates to human with the iter-3 must-fix list intact.
       - `## Where this pattern is invoked`:
         - `/spec-flow:spec` Phase 4 QA Loop
         - `/spec-flow:plan` Phase 3 QA Loop
         - `/spec-flow:charter` QA-charter loop
         - `/spec-flow:execute` Step 6 Phase QA + Step G8 Group Deep QA + Step 0a Mid-piece QA + Final Review fix-up
       - `## Migration from `qa_iter2: auto` (v3.0.x → v3.1.0)` — paragraph explaining the deprecation: the previous `auto` mode skipped iter-2 when the fix-diff was small + self-verified + oracle green. v3.1.0 retires this skip; iter-2 is now the default. The config key remains for backwards-compatibility and is silently ignored on read.
    2. In `plugins/spec-flow/skills/spec/SKILL.md`, in the `### Phase 4: QA Loop` section, add a citation line at the top: `Iteration policy: see plugins/spec-flow/reference/qa-iteration-loop.md (iter-until-clean; 3-iter circuit breaker).` Remove or rewrite any inline iter-2-skip prose to align with the reference doc.
    3. In `plugins/spec-flow/skills/plan/SKILL.md`, in the `### Phase 3: QA Loop` section, add the same citation line. Remove any inline iter-2-skip prose.
    4. In `plugins/spec-flow/skills/charter/SKILL.md`, in the QA-charter loop section, add the same citation line. Remove any inline iter-2-skip prose.
    5. In `plugins/spec-flow/skills/execute/SKILL.md`:
       - In the `### Step 6: Phase QA` section, replace the entire skip-predicate block (the bullet block whose heading starts with "Conditional skip of re-dispatch" — this block was modified by Phase 2 / Group B.1 to introduce the (a)/(b)/(c) structured predicate; Phase 5 now replaces the entire block, header included) with: `Iter-until-clean per plugins/spec-flow/reference/qa-iteration-loop.md (no skip; 3-iter circuit breaker).` Remove the read of `.spec-flow.yaml`'s `qa_iter2` key from the Step 6 logic.
       - Apply the same change to `### Step G8: Group Deep QA` (the existing ### Step G8: Group Deep QA section's iter-2 fallback paragraph — semantic anchor: the prose "If Group Deep QA returns must-fix: run the same iter-2 loop as the flat-phase QA does (Step 6's qa_iter2 skip predicate applies") — replace its `qa_iter2` skip reference.
       - Add the citation line at the top of `### Step 6: Phase QA`.
    6. In `plugins/spec-flow/templates/pipeline-config.yaml`, the existing qa_iter2 config-key block (semantic anchor: the inline comment block beginning "# qa_iter2: controls QA iteration-2 re-review after a fix-code commit" followed by the "qa_iter2: auto" key-value line) is updated. The current comment block:
       ```
       # qa_iter2: controls QA iteration-2 re-review after a fix-code commit
       #   auto    — skip iter-2 re-dispatch when fix diff < 50 LOC AND fix-code reported all findings resolved AND oracle green (default)
       #   always  — always re-dispatch iter-2
       qa_iter2: auto
       ```
       becomes:
       ```
       # qa_iter2: DEPRECATED in 3.1.0 — see plugins/spec-flow/reference/qa-iteration-loop.md
       # The orchestrator no longer reads this key. Iter-until-clean is now the default
       # for all QA gates; the 3-iter circuit breaker handles escalation. The key is
       # retained to keep existing user .spec-flow.yaml files parseable.
       qa_iter2: auto
       ```
  - Files: `plugins/spec-flow/reference/qa-iteration-loop.md` (NEW), `plugins/spec-flow/skills/spec/SKILL.md`, `plugins/spec-flow/skills/plan/SKILL.md`, `plugins/spec-flow/skills/charter/SKILL.md`, `plugins/spec-flow/skills/execute/SKILL.md`, `plugins/spec-flow/templates/pipeline-config.yaml`
  - Pattern pointers: existing reference docs at `plugins/spec-flow/reference/` (charter-drift-check.md, slug-validator.md, v3-path-conventions.md) provide the structure; existing skill QA-loop sections provide the citation insertion-point pattern.
  - Architecture constraints: CR-002 frontmatter unchanged; NN-C-003 backwards-compat preserved by retaining the config key; CR-007 inline comment provides deprecation rationale.

- [ ] **[Verify]** AC-13 + AC-14 + the deprecation comment.
  - Run check 1 (AC-13): `grep -E "iter-1|iter-2|circuit breaker|focused re-review|iter-N|fix-doc dispatch|iter-3|iteration numbering" plugins/spec-flow/reference/qa-iteration-loop.md` returns matches for all anchors.
  - Run check 2 (AC-14): `grep -l "qa-iteration-loop.md" plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/plan/SKILL.md plugins/spec-flow/skills/charter/SKILL.md plugins/spec-flow/skills/execute/SKILL.md` returns all four file paths.
  - Run check 3 (AC-14): `grep -r "qa_iter2: auto" plugins/spec-flow/skills/` returns zero matches.
  - Run check 4 (deprecation comment): `grep -A 3 "qa_iter2: DEPRECATED" plugins/spec-flow/templates/pipeline-config.yaml` returns the multi-line comment block citing `qa-iteration-loop.md`.
  - Run check 5 (key still parseable): the LLM agent confirms `qa_iter2: auto` and `qa_iter2: always` both remain valid YAML in the template (key syntax is preserved).
  - Expected: all five checks pass.

- [ ] **[QA]** Phase review (iter-until-clean).
  - Review against: AC-13, AC-14.
  - Diff baseline: `git diff <phase_5_start_sha>..HEAD`.

---

### Phase 6 (Group C.1): ORC-4 plan-skill phase-sizing rule (FR-11)
**Exit Gate:** the new phase-sizing rule in `plugins/spec-flow/skills/plan/SKILL.md` Phase 2 (Generate Plan) ran through `[Verify]`'s synthetic 250-LOC scenario and produced the expected warning per AC-10.
**ACs Covered:** AC-10, AC-4 (partial — covers plan/SKILL.md)
**Charter constraints honored in this phase:**
- (none beyond the universal ones — plan-skill text edit; no new agent, no public-surface change beyond the warning text itself which is additive.)

- [ ] **[Implement]** Add phase-sizing rule + token sweep on plan/SKILL.md.
  - Order:
    1. In `plugins/spec-flow/skills/plan/SKILL.md`, in the `### Phase 2: Generate Plan` section, immediately after the existing step `2.` (the choose-track step), insert a new step:
       - **Phase-sizing check (FR-11):** for each phase or sub-phase the plan defines, count the non-blank, non-comment lines inside its `[Implement]` (or `[Build]`) block prose — the actionable bullets and order-list items that prescribe what the implementer agent does. If the count exceeds 150 for any single phase / sub-phase, the plan skill emits a warning:
         ```
         WARNING: Phase <num> (<title>): <N> lines of behavioral prose exceeds 150-line threshold; recommend split into a Phase Group with 2-3 sub-phases.
         ```
       - The plan author may override the warning by adding `phase_size_override: <reason>` as a single-line preamble to the offending phase's body (between the phase heading and the `**Exit Gate:**` line). The warning is suppressed when an override is present, but logged for posterity.
       - The check counts lines from the start of `[Implement]` (or `[Build]`) inclusive to the next checkbox marker (`- [ ] **[`) exclusive, excluding `[ ] **[`-prefixed lines themselves and excluding markdown blank lines.
    2. Token sweep on plan/SKILL.md: replace literal `worktrees/...` paths in Agent({...}) dispatch templates with `{{worktree_root}}`. Preserve `## Step 0: Load Config` preamble.
  - Files: `plugins/spec-flow/skills/plan/SKILL.md`
  - Pattern pointers: existing Phase 2 numbered-step structure in plan/SKILL.md is the structural anchor.
  - Architecture constraints: CR-008 — rule lives in the orchestrator (skill body), not in an agent.

- [ ] **[Verify]** AC-10 + token sweep.
  - Run check 1 (AC-10): the LLM agent constructs a synthetic plan.md draft at `/tmp/synthetic-plan-oversized.md` with a Phase 4 `[Implement]` block containing 250 non-blank, non-comment behavioral-prose lines. The agent reads the new phase-sizing rule from plan/SKILL.md and confirms the warning text would read `WARNING: Phase 4 (...): 250 lines of behavioral prose exceeds 150-line threshold; recommend split into a Phase Group with 2-3 sub-phases.`
  - Run check 2 (override): same synthetic plan with `phase_size_override: 250-line block is a verbatim CHANGELOG transcription — not behavioral prose` added between the heading and exit gate. LLM agent confirms the warning is suppressed.
  - Run check 3 (boundary): synthetic plan with 150-line `[Implement]` exactly. LLM agent confirms NO warning (threshold is "exceeds 150").
  - Run check 4 (token sweep): `grep -E 'worktrees/(prd|<prd|prd-)' plugins/spec-flow/skills/plan/SKILL.md` returns matches only on Step 0 preamble or v3-path-conventions.md reference lines.
  - Expected: all four checks pass.

- [ ] **[QA]** Phase review (iter-until-clean).
  - Review against: AC-10.
  - Diff baseline: `git diff <phase_6_start_sha>..HEAD`.

---

### Phase 7 (Group C.2): ORC-5 plan-skill exit-gate semantics rule (FR-12)
**Exit Gate:** the new exit-gate validator in `plugins/spec-flow/skills/plan/SKILL.md` ran through `[Verify]`'s synthetic downgrade-pattern scenario and produced the expected rejection per AC-11.
**ACs Covered:** AC-11
**Charter constraints honored in this phase:**
- (none beyond the universal ones — plan-skill text edit; the validator rejects malformed exit gates rather than introducing new public surface.)

- [ ] **[Implement]** Add exit-gate semantics validator to plan/SKILL.md.
  - Order:
    1. In `plugins/spec-flow/skills/plan/SKILL.md`, in the `### Phase 2: Generate Plan` section, immediately after the new phase-sizing check (Phase 6 / Group C.1's addition), insert a new step:
       - **Exit-gate semantics check (FR-12):** for each phase's `**Exit Gate:**` line and each `[Verify]` step's expected-output prose, scan for the patterns (case-insensitive):
         - `is documented to run`
         - `documented to run later`
         - `deferred to release`
         - `deferred to release time`
         - `documented for release`
       - If any pattern matches, plan validation FAILS with an error:
         ```
         ERROR: Phase <num> (<title>): exit-gate downgrade not allowed — string "<matched>" implies "X is documented" rather than "X ran." Per FR-12, this is rejected. If pre-merge execution truly is not possible, split the piece into PI-N (the artifact ships) and PI-Nb (the artifact is run on a real project).
         ```
       - Plan authoring cannot proceed until the offending phase is rewritten or the piece is split.
       - This check runs BEFORE the QA-loop dispatch in Phase 3 — i.e., the plan skill validates the plan structurally before paying for adversarial Opus review.
  - Files: `plugins/spec-flow/skills/plan/SKILL.md`
  - Pattern pointers: existing Phase 2 numbered-step structure (now containing the C.1 phase-sizing check as predecessor) is the structural anchor.
  - Architecture constraints: CR-008 — validator stays in the skill body.

- [ ] **[Verify]** AC-11.
  - Run check 1: the LLM agent constructs a synthetic plan.md with a Phase 7 `[Verify]` block reading "AC-15 is documented to run at release time." Reads the new exit-gate validator and confirms validation would FAIL with an error message containing `exit-gate downgrade not allowed`.
  - Run check 2 (negative): synthetic plan with all `[Verify]` blocks reading "X ran successfully" — validator returns no errors.
  - Run check 3 (boundary — case sensitivity): synthetic plan with "Is Documented To Run Later" (mixed case). LLM agent confirms the validator catches it (case-insensitive).
  - Run check 4 (boundary — partial match): synthetic plan with "this section documents the run" (the word "documents" is fine — should NOT trigger). LLM agent confirms no false positive.
  - Expected: all four checks produce correct outcomes.

- [ ] **[QA]** Phase review (iter-until-clean).
  - Review against: AC-11.
  - Diff baseline: `git diff <phase_7_start_sha>..HEAD`.

---

### Phase 8 (Group C.3): ORC-6 LLM-native [Verify] default in plan template (FR-13)
**Exit Gate:** `plugins/spec-flow/templates/plan.md` has zero external-parser shell-outs (`yq`, `jq`, language-specific `-c` invocations) inside `[Verify]` blocks; every YAML/JSON validation example uses LLM-agent-step framing per AC-12.
**ACs Covered:** AC-12
**Charter constraints honored in this phase:**
- (none beyond the universal ones — plan-template text edit; CR-008's separation-of-concerns rule is honored by Phase 2's allocation.)

- [ ] **[Implement]** Replace external-parser examples in plan template + plan SKILL.md.
  - Order:
    1. In `plugins/spec-flow/templates/plan.md`, locate every `[Verify]` example block. Replace any `yq` / `jq` shell-out with LLM-agent-step framing. Examples:
       - Old: `Run: yq '.pieces[] | select(.name == "<name>") | .status' docs/manifest.yaml`
       - New: `Read the file at docs/manifest.yaml and confirm the entry with name=<name> has status=<expected>. Report the actual status if it differs.`
       - Old: `Run: jq -r '.version' plugin.json`
       - New: `Read the file at plugin.json and confirm the "version" field equals "<expected>". Report the actual version if it differs.`
    2. In the `### Phase 2 (Implement track example)` block of the template, update the `[Verify]` example bullet's `Run:` placeholder text to include this guidance: `For YAML/JSON validation: use LLM-agent-step framing (e.g., "Read the file at <path> and confirm it parses as valid YAML/JSON; report any error inline") rather than yq/jq/language-specific runtime shell-outs. For other validations (lint, type check, build, smoke run): standard shell commands are fine.`
    3. In `plugins/spec-flow/skills/plan/SKILL.md` Phase 2 (Generate Plan), add to the existing `[Verify]` step description: `For YAML/JSON validation in [Verify] blocks, default to LLM-agent-step framing per the plan template. External parsers (yq, jq, language interpreters) are not preconditions of this pipeline.`
  - Files: `plugins/spec-flow/templates/plan.md`, `plugins/spec-flow/skills/plan/SKILL.md`
  - Pattern pointers: existing `[Verify]` example blocks in `templates/plan.md` are the structural anchors.
  - Architecture constraints: CR-008 + NN-C-002 — no external runtime dependency mandated.

- [ ] **[Verify]** AC-12.
  - Run check 1 (AC-12): `grep -E "(yq|jq)( |$)" plugins/spec-flow/templates/plan.md` returns zero matches inside `[Verify]` blocks. (The grep may match these tokens in non-`[Verify]` prose if any — confirm by reading context that all matches are commentary about the deprecation, not active examples.)
  - Run check 2 (AC-12 framing): `grep -E "Read the file at|parses as valid (YAML|JSON)" plugins/spec-flow/templates/plan.md` returns ≥ 1 match per `[Verify]` example block.
  - Run check 3: the LLM agent reads the updated plan template and confirms the LLM-agent-step framing is in every YAML/JSON validation example and that no example invokes a language-specific runtime.
  - Expected: all three checks pass.

- [ ] **[QA]** Phase review (iter-until-clean).
  - Review against: AC-12.
  - Diff baseline: `git diff <phase_8_start_sha>..HEAD`.

---

### Phase 9 (Phase D): Release ceremony (FR-16, FR-17)
**Exit Gate:** working-tree at the feature-branch tip carries plugin.json @ 3.1.0, marketplace.json's spec-flow entry @ 3.1.0, and CHANGELOG.md with a `## [3.1.0] — YYYY-MM-DD` section at the top covering all 11 items + Migration notes. The squash-merge commit (a maintainer action outside the plan) inherits these and satisfies AC-15 / AC-16 / AC-17.
**ACs Covered:** AC-15, AC-16, AC-17
**Charter constraints honored in this phase:**
- NN-C-007 (CHANGELOG in Keep a Changelog format): the new `## [3.1.0]` section uses Keep-a-Changelog 1.1.0 groupings (Added, Changed, Removed) plus the Migration notes for upgraders subsection.
- NN-C-009 (always bump version + 3 places): plugin.json + marketplace.json + CHANGELOG.md all bump in this phase's single commit.
- NN-P-003 (dog-food before recommend): the CHANGELOG's Migration notes subsection cites `docs/prds/shared/specs/pi-009-hardening/learnings.md` as the dog-food evidence artifact, fulfilling the AC-17 contract that the squash-merge commit's message reference learnings.md.
- CR-006 (CHANGELOG format — Keep a Changelog): same as NN-C-007 — CR-006 binds the format choice; the section uses it.

- [ ] **[Implement]** Bump plugin version + marketplace + CHANGELOG.
  - Order:
    1. **Bump plugin.json:** edit `plugins/spec-flow/.claude-plugin/plugin.json`. Change `"version": "3.0.0"` → `"version": "3.1.0"`.
    2. **Bump marketplace.json:** edit `.claude-plugin/marketplace.json`. Locate the spec-flow plugin entry. Change its `"version": "3.0.0"` → `"version": "3.1.0"`.
    3. **Prepend CHANGELOG section:** edit `plugins/spec-flow/CHANGELOG.md`. Prepend (after the `# Changelog` H1 title and any preamble) a new section:
       ```markdown
       ## [3.1.0] — YYYY-MM-DD

       ### Added

       - Charter-drift deep scan via `/spec-flow:status --include-drift` — surfaces semantic drift in spec NN/CR citations against current charter content (CAP-2 / FR-2, FR-3).
       - `{{worktree_root}}` template token resolved by orchestrator from active piece slug pair; replaces literal `worktrees/...` paths in Agent dispatch templates across spec/plan/execute/status/prd/migrate SKILL.md files (CAP-3 / FR-4, FR-5).
       - `## Environment preconditions` section in `plugins/spec-flow/skills/migrate/SKILL.md` — documents host-side capabilities (LLM-agent runtime + git + POSIX shell) without mandating any specific language runtime (CAP-4 / FR-6).
       - Mid-piece Opus QA pass for ≥6-phase pieces — orchestrator inserts one Opus QA dispatch at the half-way commit when prior phases auto-skipped (ORC-2 / FR-9).
       - Deferred-finding tracking — orchestrator parses `Deferred to reflection:` markers in QA reports and writes structured stubs to PRD-local backlog at deferral time (ORC-3 / FR-10).
       - `plugins/spec-flow/reference/qa-iteration-loop.md` — canonical reference doc for the iter-until-clean QA loop pattern; spec/plan/charter/execute SKILL.md cite it (ORC-7 / FR-14, FR-15).
       - Plan-skill phase-sizing warning when a single phase exceeds 150 LOC of behavioral prose (ORC-4 / FR-11).
       - Plan-skill exit-gate semantics validator rejecting "X is documented to run later" downgrades (ORC-5 / FR-12).

       ### Changed

       - PI-008 spec FR-005 amended to single-branch model (`spec/<prd-slug>-<piece-slug>` from spec authoring through plan and execute) — matches shipped code; replaces the v3.0.0 spec text that prescribed three branches per piece (CAP-1 / FR-1).
       - NFR-004 in `docs/prds/shared/prd.md` clarified that "Documentation is the source of truth" includes documenting environment preconditions for skills that operate on user repos (CAP-4 / FR-7).
       - Sharpened Opus QA skip-predicate — skips only for additive markdown / YAML / pure config; routes to Opus when phase touches scripts with control-flow constructs or new skill bodies regardless of LOC (ORC-1 / FR-8).
       - Plan template `[Verify]` examples for YAML/JSON validation use LLM-agent-step framing instead of `yq`/`jq` shell-outs (ORC-6 / FR-13).
       - All QA gates (spec, plan, charter, execute per-phase, mid-piece Opus, Final Review fix-up) iterate until reviewer reports zero must-fix findings; iter-1 = full review, iter-2+ = focused re-review on the fix diff; 3-iter circuit breaker stays as escalation guard (ORC-7 / FR-14).

       ### Removed

       - (none — no public-surface item removed; `qa_iter2` config key is retained as deprecated, see Migration notes below.)

       ### Migration notes for upgraders

       - **`qa_iter2` config key is deprecated.** The orchestrator no longer reads this key. Users with `qa_iter2: auto` or `qa_iter2: always` in their `.spec-flow.yaml` continue to load without error or warning — the key syntax is preserved for backwards compatibility per NN-C-003. The behavior change: iter-2 QA re-dispatch is now the default for all gates (no more conditional skip on small fix diffs). Users who relied on the auto-skip for throughput should expect more iterations on phases where fix-code surfaces residual must-fix items.
       - **`/spec-flow:status --include-drift` is opt-in.** Default `/spec-flow:status` invocation is unchanged. Run with `--include-drift` to surface citation drift across all specs.
       - **Mid-piece Opus QA pass triggers on long pieces.** Pieces declaring ≥6 phases where the first ⌈N/2⌉ all auto-skip Opus will see one additional Opus dispatch at the half-way commit. No user action required; the dispatch is observable in the session summary as `mid_piece_opus_pass: dispatched`.
       - **Dog-food evidence:** v3.1.0 was end-to-end dog-fooded on this repo as the `pi-009-hardening` piece. End-of-piece reflection is captured in `docs/prds/shared/specs/pi-009-hardening/learnings.md` — covering all 12 sub-phases (Group A.1–A.4, Group B.1–B.4, Group C.1–C.3, Phase D), with what-worked / what-didn't entries per sub-phase.
       ```
       (Replace `YYYY-MM-DD` with the actual release date.)
    4. **Verify the version-sync invariant pre-merge** (NN-C-001): the LLM agent reads both `plugins/spec-flow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`'s spec-flow entry, confirms both report `3.1.0`, and reports any mismatch inline.
  - Files: `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`
  - Pattern pointers: existing `## [3.0.0]` section in `plugins/spec-flow/CHANGELOG.md` (committed in `b9b20ec` per the v3.0.0 release) is the structural template; existing PI-008 release commit (the one before HEAD on master) is the commit-message style reference.
  - Architecture constraints: NN-C-001 (sync invariant), NN-C-007 (Keep-a-Changelog format), NN-C-009 (3-place bump), CR-006 (CHANGELOG format).

- [ ] **[Verify]** AC-15 + AC-16 + the version-sync invariant.
  - Run check 1 (AC-15 plugin.json): `grep -E '"version":\s*"3\.1\.0"' plugins/spec-flow/.claude-plugin/plugin.json` returns 1 match.
  - Run check 2 (AC-15 marketplace.json): the LLM agent reads `.claude-plugin/marketplace.json`, finds the entry with `"name": "spec-flow"`, and confirms its `"version"` field reads `"3.1.0"`.
  - Run check 3 (AC-15 CHANGELOG): `grep -c "^## \[3\.1\.0\]" plugins/spec-flow/CHANGELOG.md` returns ≥ 1, AND the entry is at the top (immediately after `# Changelog` and any one-line preamble).
  - Run check 4 (AC-16 Migration notes): `grep -A 30 "^## \[3.1.0\]" plugins/spec-flow/CHANGELOG.md | grep -E "Migration|qa_iter2|include-drift"` returns matches for all three anchors.
  - Run check 5 (NN-C-001 sync): the version strings in plugin.json and marketplace.json's spec-flow entry are byte-identical (both `"3.1.0"`).
  - Expected: all five checks pass.
  - **Note on AC-17 verification — all four tests are post-merge maintainer responsibility:**
    - **Why post-merge:** the actual execute-skill ordering is Final Review (5-agent board, runs first) → Step 4.5 Reflection → Step 5 Capture Learnings (writes `docs/prds/shared/specs/pi-009-hardening/learnings.md`) → Step 6 Merge. No in-pipeline verifier runs between Step 5 and Step 6, so AC-17's structural tests (2, 3, 4) cannot be carried by Final Review (which runs before learnings.md exists). Tests 2/3/4 become checkable only AFTER Step 5 produces the file, by which point only the maintainer's pre-squash-merge review remains.
    - **Pre-squash-merge maintainer checks (AC-17 tests 2, 3, 4):** before authoring the squash-merge commit message, the maintainer runs:
      - `grep -cE "^#+ .*(Group [ABC]\.[0-9]+|Phase D)" docs/prds/shared/specs/pi-009-hardening/learnings.md` → expect ≥ 12.
      - `grep -cE "what (worked|didn'?t)" docs/prds/shared/specs/pi-009-hardening/learnings.md` → expect ≥ 12.
      - `wc -c docs/prds/shared/specs/pi-009-hardening/learnings.md` → expect > 1024 bytes.
      If any check fails, the maintainer either (a) regenerates learnings.md by re-running Step 4.5 + Step 5 (the orchestrator supports re-running reflection on a completed piece), or (b) hand-edits learnings.md to satisfy the structural contract before merge. Option (b) requires recording the manual edit in the squash-merge commit message.
    - **Squash-merge commit-message check (AC-17 test 1):** the maintainer crafts the squash-merge commit message to include the literal substring `pi-009-hardening/learnings.md`. The CHANGELOG migration note above (which Phase 9 produces in `plugins/spec-flow/CHANGELOG.md`) is the in-tree anchor pointing at learnings.md; the maintainer is expected to mirror that reference in the merge commit message.

- [ ] **[QA]** Phase review (iter-until-clean).
  - Review against: AC-15, AC-16. AC-17's four tests are entirely post-Step-5-Capture-Learnings, post-Phase-9 maintainer responsibilities at squash-merge time — see "Note on AC-17 verification" above for the exact maintainer commands and timing.
  - Diff baseline: `git diff <phase_9_start_sha>..HEAD`.

---

## Parallel Execution Notes

- **Phase Group A**: 4 sub-phases (A.1, A.2, A.3, A.4) dispatch concurrently per `phase_groups: auto` in `.spec-flow.yaml`. Sub-phase scopes are disjoint:
  - A.1: `docs/prds/shared/specs/PI-008-multi-prd-v3.0.0/spec.md`
  - A.2: `plugins/spec-flow/skills/status/SKILL.md`
  - A.3: `plugins/spec-flow/reference/v3-path-conventions.md`, `plugins/spec-flow/skills/spec/SKILL.md`, `plugins/spec-flow/skills/prd/SKILL.md`
  - A.4: `plugins/spec-flow/skills/migrate/SKILL.md`, `docs/prds/shared/prd.md`
  No file path appears in two sub-phase scopes. The orchestrator's disjointness validator (per `## Step G2: Validate sub-phase disjointness` in execute/SKILL.md) passes.

- **Phases 2–5 (Group B.1–B.4)**: sequential. All four phases edit `plugins/spec-flow/skills/execute/SKILL.md` at overlapping or contiguous sections (Step 6 Phase QA + Per-Phase Loop + Phase Group Loop + Step G8 Group Deep QA). Concurrent dispatch would race on the file. Phase-Group structure not used.

- **Phases 6–8 (Group C.1–C.3)**: sequential. All three edit `plugins/spec-flow/skills/plan/SKILL.md` Phase 2 (Generate Plan) section. Same reason as Group B.

- **Phase 9 (Phase D)**: sequential, runs last. Touches `plugin.json`, `marketplace.json`, `CHANGELOG.md` — no overlap with prior phases, but ordering matters because the version bump must reflect the complete v3.1.0 surface.

- **No Phase 0 Scaffold needed.** No coordination file is appended to by ≥2 sibling sub-phases inside any group. Group A's sub-phases are scope-disjoint; Groups B and C are sequential. Skipping Scaffold per the skill's "If only one phase touches the coordination files, skip Scaffold" rule.

## Mid-piece Opus QA pass dispatch (FR-9 dog-food trigger)

Total phase count for this piece (from the scheduler's view): **9 phases** (Phase Group A counts as one phase from the outer scheduler's perspective; Phases 2–9 are eight flat phases). N = 9. K = ⌈9/2⌉ = 5. The mid-piece Opus QA pass triggers between Phase 5 (Group B.4) and Phase 6 (Group C.1) IF the first 5 phases (Phase Group A + Phases 2–5) all returned `skip` from the sharpened Opus skip-predicate.

In practice, the first 5 phases include real control-flow logic (status `--include-drift` parsing in A.2; orchestrator hook logic in B.1, B.2, B.3; reference doc + multi-file citations in B.4). Per FR-8, the sharpened predicate routes phases touching scripts with control-flow constructs or new skill bodies to Opus regardless of LOC. So the trigger likely DOES NOT fire — most early phases route to Opus per-phase, leaving the mid-piece pass as a no-op.

This is the intended dog-food behavior: FR-9's trigger condition is "all first ⌈N/2⌉ phases skipped Opus." If the sharpened predicate (FR-8) does its job, large-impact phases route to Opus per-phase, and the mid-piece pass becomes redundant. If the predicate misclassifies and skips a behaviorally-rich phase, the mid-piece pass catches it.

The actual outcome (triggered or not, with iteration count) is captured as a process-retro observation in `docs/prds/shared/specs/pi-009-hardening/learnings.md` Step 4.5 reflection.

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, plan `[Implement]` task list, spec ACs covered by the phase, plan's `[Verify]` command, architecture constraints (NN-C/NN-P/CR cited per phase), pattern pointers to existing similar files. | Spec rationale, brainstorming history, prior phase QA reports, prior phase fix-code commits' context. |
| Verify | The `[Verify]` step's prescribed commands and expected outputs, the spec's relevant ACs, the diff between phase-start SHA and HEAD. | Implementation reasoning, prior agent conversations. |
| QA-lite (sub-phase, Sonnet) | `Mode: Implement` flag, sub-phase diff (only the sub-phase's scoped files), sub-phase ACs, AC matrix as produced by the sub-phase Build, sub-phase scope block from the plan. | Full piece spec, full PRD sections, sibling sub-phases' diffs, prior groups' diffs. |
| QA (group-level or phase-level, Opus) | Phase / group cumulative diff, full spec.md, plan.md, mapped PRD sections, charter files cited in the spec's honored sections (raw text). | Any agent conversation history, brainstorming notes, prior QA iteration reports (except the previous iter's must-fix list when the loop is on iter-2+). |
| Mid-piece QA (Opus, FR-9) | Cumulative diff `git diff <piece_start_sha>..HEAD`, full spec.md, AC matrix produced through phase K, charter files cited in the spec. New input mode label: `Mid-piece full review`. | Per-phase QA reports, individual phase diffs (the cumulative diff replaces them), session conversation history. |
| Refactor (group-level, optional) | Union of group sub-phase files, the group's verify command, quality principles. | Prior agent conversations, sub-phase fix-code commits. |
| Reflection (Step 4.5, end-of-piece) | Cumulative diff for the entire piece, session metrics summary, improvement-backlog state, manifest entry. | Brainstorming history, individual phase QA chats. |

## Charter constraint allocation summary

Each NN-C / NN-P / CR entry cited in the spec is allocated to exactly one phase below. No drops. No duplicates.

| Charter ID | Phase | How honored |
|---|---|---|
| NN-C-002 | A.4 | Migrate-skill `## Environment preconditions` section frames host capabilities as LLM-agent-runtime expectations, not plugin-internal runtime deps. |
| NN-C-003 | Phase 5 (Group B.4) | `qa_iter2` key retained in pipeline-config.yaml with deprecation comment; user `.spec-flow.yaml` files load without error. |
| NN-C-005 | A.2 | `--include-drift` mode no-ops cleanly when no specs / no citation blocks / no charter files exist; exits 0. |
| NN-C-007 | Phase 9 (Phase D) | CHANGELOG.md `## [3.1.0]` section follows Keep-a-Changelog 1.1.0 groupings + Migration notes subsection. |
| NN-C-008 | Phase 3 (Group B.2) | Mid-piece QA pass dispatches qa-phase agent with fresh self-contained prompt — cumulative diff + spec + AC matrix + cited charter raw text. |
| NN-C-009 | Phase 9 (Phase D) | 3-place bump in single commit: plugin.json + marketplace.json + CHANGELOG.md. |
| NN-P-001 | A.1 | PI-008 spec amendment is plain-markdown additions under `docs/`. |
| NN-P-002 | Phase 3 (Group B.2) | Mid-piece pass added BEFORE existing per-phase QA + Final Review gates; human sign-off gates unchanged. |
| NN-P-003 | Phase 9 (Phase D) | CHANGELOG Migration notes cite pi-009-hardening/learnings.md as dog-food evidence. |
| CR-002 | Phase 5 (Group B.4) | Touched SKILL.md files preserve `name:` / `description:` frontmatter intact. |
| CR-005 | A.3 | New v3-path-conventions.md section uses repo-root-relative path notation throughout. |
| CR-006 | Phase 9 (Phase D) | CHANGELOG Keep-a-Changelog format choice. |
| CR-007 | Phase 5 (Group B.4) | `qa_iter2` deprecation comment block in pipeline-config.yaml cites `qa-iteration-loop.md` and explains rationale. |
| CR-008 | Phase 2 (Group B.1) | Sharpened skip predicate lives in execute/SKILL.md (orchestrator), not in any agent file. |
| CR-009 | A.2 | `## Citation drift deep scan` section sits at H2 alongside existing status-skill steps; sub-bullets at H3 only. |
