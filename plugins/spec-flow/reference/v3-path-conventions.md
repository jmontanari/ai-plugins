# v3 path conventions

This document specifies the v3.0.0 multi-PRD layout for spec-flow projects. It is the canonical reference for path resolution: every skill that reads or writes a PRD, manifest, spec, plan, backlog, charter, or worktree resolves paths against the rules below. v3 is opt-in via `.spec-flow.yaml`'s `layout_version: 3`; absence or a lower value triggers a SessionStart warning per FR-016.

## Layout

```
docs/
├── charter/                 # unchanged — singular across all PRDs
│   └── …
├── prds/
│   └── <prd-slug>/
│       ├── prd.md           # front-matter: slug, status, version
│       ├── manifest.yaml    # pieces with optional slug + qualified depends_on
│       ├── backlog.md       # PRD-local deferred work
│       ├── README.md        # optional: PRD elevator pitch
│       └── specs/
│           └── <piece-slug>/
│               ├── spec.md
│               ├── plan.md
│               ├── research/
│               ├── learnings.md
│               └── ac-matrix.md
└── improvement-backlog.md   # global — cross-PRD + process retros
```

A PRD is archived in place by setting `status: archived` in its `prd.md` front-matter. There is no `docs/archive/` directory in the v3 layout — `/spec-flow:status` filters archived PRDs out of the default view.

## Path resolution

| Artifact | Path |
|----------|------|
| PRD | `docs/prds/<prd-slug>/prd.md` |
| Manifest | `docs/prds/<prd-slug>/manifest.yaml` |
| Spec | `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md` |
| Plan | `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md` |
| PRD-local backlog | `docs/prds/<prd-slug>/backlog.md` |
| Global backlog | `docs/improvement-backlog.md` |
| Charter | `docs/charter/` (unchanged) |
| Worktree | `worktrees/prd-<prd-slug>/piece-<piece-slug>/` |
| Branch | `<verb>/<prd-slug>-<piece-slug>` (verb ∈ `{spec, plan, execute, migrate}`) |

Notes:

- The PRD folder name is the PRD slug verbatim. The piece folder name is the piece slug verbatim.
- The worktree path encodes both slugs with the `prd-` and `piece-` prefixes for human legibility (so `ls worktrees/` shows the PRD grouping at the top level).
- The branch name uses the joined slug pair without prefixes, separated by `-`. See `slug-validator.md` for the 50-char branch length budget and the path-separator rule.

## Layout version detection

`.spec-flow.yaml` at the repo root carries `layout_version: <int>`:

- **`layout_version: 3`** — v3 paths are active. All skills resolve against the table above.
- **`layout_version: <3`** or key absent — pre-v3 layout; the SessionStart hook (`plugins/spec-flow/hooks/session-start`) emits a non-blocking yellow warning per FR-016: `Layout is pre-v3. Run /spec-flow:migrate to adopt multi-PRD.`
- **`.spec-flow.yaml` absent altogether** — the hook is silent (per NN-C-005). The user has not opted into spec-flow yet; no warning is appropriate.

In every branch (warning emitted, silent, or error), the hook exits 0 with valid JSON on stdout — it never blocks the session.

## Cross-references to slug validator

Every path that contains `<prd-slug>` or `<piece-slug>` is subject to the rules in [plugins/spec-flow/reference/slug-validator.md](slug-validator.md): max 10 characters per slug, charset `[a-z0-9-]`, no leading or trailing `-`, ≤ 50-char branch length total. Path resolution does not silently sanitize a slug — the slug must already be valid by the time it reaches a path-formation call. Skills validate at branch/worktree creation time and refuse with an explicit error on violation.

## See also

- [plugins/spec-flow/reference/slug-validator.md](slug-validator.md) — slug rules, branch length budget, refusal contract.
- [plugins/spec-flow/reference/charter-drift-check.md](charter-drift-check.md) — Phase-1 charter-drift procedure run by every skill that touches a piece.
