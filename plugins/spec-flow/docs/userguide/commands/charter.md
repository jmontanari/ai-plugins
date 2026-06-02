# /spec-flow:charter

Bootstrap or update the project charter — seven binding constraint domains that every downstream spec-flow artifact inherits from.

## What it does

Authors or evolves the charter as **seven skill files** under a single host-native skills root — either `.github/skills/` (GitHub / Copilot CLI) or `.claude/skills/` (Claude Code). A project uses exactly one root, written below as `<charter_root>`; how it is resolved/chosen is defined in [reference/charter-location.md](../../../reference/charter-location.md):

```
<charter_root>/skills/                   # <charter_root> = .github or .claude
├── charter-architecture/SKILL.md       layer boundaries, dependency direction, module ownership
├── charter-non-negotiables/SKILL.md    NN-C-xxx entries — project-wide hard rules
├── charter-coding-rules/SKILL.md       CR-xxx entries — code conventions
├── charter-tools/SKILL.md              tool inventory + version pins
├── charter-processes/SKILL.md          branching, commit, release, review workflow
├── charter-flows/SKILL.md              standard end-to-end workflows
└── charter-integrations/SKILL.md       external services / MCPs (Jira, CI, webhooks)
```

These skill files **are** the authoritative charter — there is no separate docs-based charter directory. They use a two-tier loading model: `non-negotiables` and `architecture` are always-on doctrine (injected by the SessionStart hook via `charter.doctrine_load` in `.spec-flow.yaml`); the rest are host-invoked on demand by their descriptions. The charter is the *binding context* for every PRD, spec, plan, and implementation that follows. Every reviewer cites charter entries by ID. See [charter-system.md](../concepts/charter-system.md) for the full mental model.

## When to run it

- **First time on a new project:** before `/spec-flow:prd`. The charter is a prerequisite for PRD authoring once `charter.required: true`.
- **A binding decision changed:** run in *update* mode to evolve specific entries. Divergence detection flags conflicts with already-shipped pieces.

## The two modes

The charter skill detects which mode applies based on project state:

### Bootstrap (greenfield — no charter skill files exist)

1. **Repo scan** — an `explore` agent samples the codebase at a depth scaled to repo size and returns a Signal Summary (detected tools, structure, observed patterns with confidence tiers, cross-module inconsistencies, absent patterns).
2. **External sources** — you can supply compliance docs, ADRs, runbooks, style guides per charter category; the skill folds them into the signals.
3. **Confirm signals** — you approve the combined Signal Summary before the long Socratic session begins. It's saved under the resolved charter root (`<charter_root>/skills/.charter-signal-summary.yaml`) for resume.
4. **Resolve the charter location** — the skill detects which host directory exists and recommends a root: only `.github/` → recommend `.github/skills/`; only `.claude/` → recommend `.claude/skills/`; **both** → ask you to pick (no auto-pick); **neither** → ask (no default). After you confirm, it persists `charter_root: .github` (or `.claude`) to `.spec-flow.yaml`. Full rules: [reference/charter-location.md](../../../reference/charter-location.md).
5. **Socratic dialogue, section by section** — one question at a time across seven sections (A Tools, B Architecture, C Flows, D Coding Rules, E Processes, F Non-Negotiables, G Integrations). Scan-confirmed findings use evidence-led confirmation ("I saw X in these files — is this the intended convention?").
6. The skill writes each of the seven charter skill files to `<charter_root>/skills/charter-*/`, runs QA, and you sign off.

### Update (charter exists, specific change needed)

- You name the domain file(s) you want to change.
- The skill runs a scoped Socratic per file and proposes adds, modifications, or retirements.
- **Retirement** tombstones an entry (strikethrough + `RETIRED YYYY-MM-DD` + reason) rather than deleting it, so pieces that cited the old ID get flagged. New entries get the next sequential unused ID — IDs are never reused.
- **Divergence awareness:** after commit, pieces at `specced` / `planned` / `in-progress` whose `charter_snapshot` predates the touched file are flagged. You run `/spec-flow:status --resolve <piece>` to walk resolution. Nothing is auto-re-specced.

## The flow (bootstrap case)

1. Repo scan → external sources → confirm Signal Summary → resolve charter location (detect/recommend/prompt, persist `charter_root`).
2. Section-by-section Socratic produces the content for each of the seven domains, with a per-section mini-confirmation and a full charter preview before any file is written.
3. **Phase 3 write:** templates from `${CLAUDE_PLUGIN_ROOT}/templates/charter/` are populated and written to `<charter_root>/skills/charter-<domain>/SKILL.md` (`<charter_root>` = the resolved `.github` or `.claude`). Each domain's `description:` is run through `skill-creator`'s optimization loop so the host invokes it reliably (skill-creator is a hard prerequisite — the write gate refuses without it).
4. **qa-charter agent** (Opus) adversarially reviews the seven files as a set:
   - Non-overlapping concerns (architecture doesn't redefine coding rules).
   - ID uniqueness across namespaces (NN-C-xxx vs CR-xxx vs NN-P-xxx in PRDs).
   - Every stated rule is *verifiable* — vague rules are must-fix.
5. If findings emerge, fix-doc makes targeted fixes; qa-charter re-reviews the delta only. Loop up to 3 iterations.
6. You sign off.
7. **Per-domain commits** — one commit per file so `git blame` stays useful.
8. **Phase 6.5 project init** — `mkdir -p docs/prds`, then create/update `.spec-flow.yaml` with `layout_version: 4`, `charter.required: true`, `charter.doctrine_load: [non-negotiables, architecture]`, and `charter_root` (the root chosen in step 4), committed as a config change.

## The Integrations sub-flow (Section G)

Section G captures external service integrations (MCP servers, CI, external APIs, webhooks). When **Jira** is identified, a dedicated sub-flow asks (one question at a time) for the instance URL, project key, piece/phase issue types, auto-create/auto-transition flags, naming and status-transition overrides, and effort-tracking model (story points / time tracking). It writes an `integrations.issue_tracker` block to `.spec-flow.yaml` and the human-readable rules to the `charter-integrations` domain. Downstream skills read this block to create and transition issues automatically.

## Loops

- **QA loop** — qa-charter review → fix-doc → re-review, up to 3 iterations (circuit breaker on 3).
- **Socratic loop** — not a retry loop, but one question at a time per section. You can correct earlier answers at each per-section mini-confirmation before the file is written.

## What you get

Seven charter skill files at `<charter_root>/skills/charter-<domain>/SKILL.md` (`<charter_root>` = `.github` or `.claude`, resolved per [reference/charter-location.md](../../../reference/charter-location.md)), each committed separately, plus a `.spec-flow.yaml` carrying `layout_version: 4`, `charter.required: true`, and `charter_root`. The content is bound from this point forward — every PRD, spec, plan, and implementation inherits it.

The charter is rarely large on day one. A greenfield project's charter might total 400–800 lines across the seven domains. It grows over time as decisions accumulate.

## Handoff

Run `/reload-plugins` (or start a new session) so the SessionStart hook picks up the always-on doctrine domains. Then run `/spec-flow:prd` to author or import a PRD. The project can have more than one — run `/spec-flow:prd` again for each additional PRD you need.

## Worked example (bootstrap)

Fresh marketplace repo, no prior docs. You run `/spec-flow:charter`:

```
Q: What kind of project is this?
A: A marketplace hosting multiple Claude Code / Copilot CLI plugins.

Q: What are the top-level architectural layers?
A: Marketplace (root) → Plugins (subdirs) → plugin-internal (skills, agents, ...)

Q: Non-negotiables — what must never change?
A:
  - Plugin versions in marketplace.json must match each plugin's plugin.json
  - No plugin imports another plugin's internals
  - POSIX-only tooling (no rsync)

Q: Coding rules?
A:
  - Agent Markdown files must declare name + description frontmatter
  - CHANGELOG follows Keep a Changelog format
  - Paths in docs are repo-root-relative
  ...
```

The skill detected a `.github/` directory and recommended `.github/skills/` (had you chosen Claude Code, the same files would land under `.claude/skills/` instead). After the Socratic and one round of QA findings, it commits per domain:

```
.github/skills/charter-architecture/SKILL.md       (180 lines)
.github/skills/charter-non-negotiables/SKILL.md    (9 NN-C entries, 140 lines)
.github/skills/charter-coding-rules/SKILL.md       (12 CR entries, 95 lines)
.github/skills/charter-tools/SKILL.md              (45 lines)
.github/skills/charter-processes/SKILL.md          (60 lines)
.github/skills/charter-flows/SKILL.md              (85 lines)
.github/skills/charter-integrations/SKILL.md       (30 lines)
```

Then `.spec-flow.yaml` is committed with `layout_version: 4`, `charter.required: true`, and `charter_root: .github`. Every future piece honors these domains by ID.

## Where to go next

- [Charter system concepts](../concepts/charter-system.md) — the full mental model.
- [/spec-flow:prd](./prd.md) — the next command.
