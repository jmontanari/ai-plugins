# /spec-flow:charter

Bootstrap, update, or retrofit the project charter — six binding constraint files that every downstream spec-flow artifact inherits from.

## What it does

Authors or evolves `docs/charter/`:

```
docs/charter/
├── architecture.md        layer boundaries, dependency direction, module ownership
├── non-negotiables.md     NN-C-xxx entries — project-wide hard rules
├── coding-rules.md        CR-xxx entries — code conventions
├── tools.md               tool inventory + version pins
├── processes.md           branching, commit, release, review workflow
└── flows.md               standard end-to-end workflows
```

The charter is the *binding context* for every PRD, spec, plan, and implementation that follows. Every reviewer cites charter entries by ID. See [charter-system.md](../concepts/charter-system.md) for the full mental model.

## When to run it

- **First time on a new project:** before `/spec-flow:prd`. The charter is a v2.0.0+ prerequisite for PRD authoring.
- **Project has legacy `docs/architecture/` but no charter:** run in *retrofit* mode to migrate existing docs into charter form.
- **A binding decision changed:** run in *update* mode to evolve specific entries. Divergence detection flags conflicts with already-shipped pieces.

## The three modes

The charter skill detects which mode applies based on project state:

### Bootstrap (greenfield — no charter, no legacy arch docs)

Socratic brainstorm from scratch:

1. **Project premise** — what kind of thing is this? (CLI, service, library, plugin marketplace, ...)
2. **Architectural layers** — what are the top-level boundaries?
3. **Dependency direction** — what imports what, one-way or bidirectional?
4. **Non-negotiables** — what must never change? Each becomes an NN-C-xxx entry.
5. **Coding rules** — what conventions apply across all code? Each becomes a CR-xxx entry.
6. **Tools** — languages, test frameworks, linters, formatters with version pins.
7. **Processes** — branching model, commit style, review gates, release rhythm.
8. **Flows** — end-to-end workflows that show how multi-stage work moves through the project.

Each section runs one question at a time. When a section is done, the skill writes that file and moves on.

### Retrofit (legacy `docs/architecture/` exists, no charter)

- Scans `docs/architecture/`, `docs/adr/`, and any `NN-xxx` entries in existing PRDs.
- For each legacy doc, proposes which charter file it maps to.
- Proposes NN-C-xxx / CR-xxx IDs for unprefixed NN-xxx entries.
- You sign off on each mapping before the charter is written.
- Produces a migration trace showing where each charter entry came from.

### Update (charter exists, specific change needed)

- You name the entries you want to change.
- The skill loads the current charter, the affected entries, and any shipped pieces that cite those entries.
- **Divergence detection:** if an update would invalidate a shipped piece's citation, the skill flags it. You decide whether to amend the piece or retire-and-supersede the charter entry.
- New entries get new IDs; retired entries get tombstoned (never deleted).
- Only touches the files you said to change.

## The flow (bootstrap case)

1. Socratic brainstorm produces each of the six files, one section at a time.
2. **qa-charter agent** adversarially reviews the six files as a set:
   - Non-overlapping concerns (architecture doesn't redefine coding rules).
   - ID uniqueness across namespaces (NN-C-xxx vs CR-xxx vs NN-P-xxx in PRDs).
   - Every stated rule is *verifiable* — vague rules are must-fix.
3. If findings emerge, the fix-doc agent makes targeted fixes. Re-review the delta only.
4. Loop up to 3 iterations.
5. You sign off.
6. Charter is committed to `master` with message `charter: bootstrap project charter`.

## Loops

- **QA loop** — qa-charter review → fix-doc → re-review, up to 3 iterations.
- **Brainstorm loop** — not a retry loop, but one question at a time per section. You can go back and amend earlier answers before the section is written.

## What you get

Six files in `docs/charter/`, all committed to master as a single charter commit. The content is bound from this point forward — every PRD, spec, plan, and implementation inherits it.

The charter is rarely large on day one. A greenfield project's charter might total 400–800 lines across six files. It grows over time as decisions accumulate.

## Handoff

Next command: `/spec-flow:prd` to author or import the PRD.

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

After the brainstorm and one round of QA findings, the skill commits:

```
docs/charter/architecture.md       (180 lines)
docs/charter/non-negotiables.md    (9 NN-C entries, 140 lines)
docs/charter/coding-rules.md       (12 CR entries, 95 lines)
docs/charter/tools.md              (45 lines)
docs/charter/processes.md          (60 lines)
docs/charter/flows.md              (85 lines)
```

Total: ~600 lines. Every future piece honors these files by ID.

## Where to go next

- [Charter system concepts](../concepts/charter-system.md) — the full mental model.
- [/spec-flow:prd](./prd.md) — the next command.
