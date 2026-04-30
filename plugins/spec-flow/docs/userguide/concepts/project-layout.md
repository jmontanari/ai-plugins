# Project layout and artifacts

*What spec-flow generates, where it lives, and what's actually in each file*

This page answers the concrete question: **after running the full pipeline, what does my repository look like?**

---

## The full directory tree

After running `charter → prd → spec → plan → execute` on one PRD (`my-api`) with two pieces (`user-auth` shipped, `api-gateway` in progress):

```
your-project/
├── .spec-flow.yaml                         pipeline config (layout, TDD mode, etc.)
│
├── docs/
│   ├── charter/                            project-wide constraints — one set per repo
│   │   ├── architecture.md                 layer boundaries, dependency direction
│   │   ├── non-negotiables.md              NN-C-xxx entries — hard project rules
│   │   ├── coding-rules.md                 CR-xxx entries — code conventions
│   │   ├── tools.md                        approved languages, frameworks, test runners
│   │   ├── processes.md                    branching, commit, release, review policy
│   │   └── flows.md                        standard end-to-end workflows
│   │
│   ├── prds/                               one directory per PRD (multi-PRD supported)
│   │   └── my-api/                         PRD slug = "my-api"
│   │       ├── prd.md                      goals, requirements, NN-P-xxx entries
│   │       ├── manifest.yaml               piece list with statuses + pointers
│   │       ├── backlog.md                  deferred work scoped to this PRD
│   │       └── specs/
│   │           ├── user-auth/              piece slug = "user-auth" (merged)
│   │           │   ├── spec.md             acceptance criteria, functional requirements
│   │           │   ├── plan.md             phase-by-phase implementation plan
│   │           │   └── learnings.md        written by execute after the piece merges
│   │           └── api-gateway/            piece slug = "api-gateway" (in-progress)
│   │               ├── spec.md
│   │               └── plan.md             (no learnings yet — still executing)
│   │
│   └── improvement-backlog.md              cross-PRD learnings, process retros
│
└── worktrees/
    └── spec-my-api-api-gateway/            active worktree for the in-progress piece
        └── ...                             (removed from this list after merge)
```

**More than one PRD?** Add another directory under `docs/prds/`. The charter stays singular — it governs every PRD in the project.

```
docs/prds/
├── my-api/          first PRD
├── data-platform/   second PRD (separate manifest, own pieces)
└── admin-panel/     third PRD
```

---

## `.spec-flow.yaml` — pipeline config

Created automatically on first use. Edit to match your project.

```yaml
docs_root: docs
worktrees_root: worktrees
layout_version: 3          # multi-PRD layout (v3.0.0+)

refactor: auto             # skip Refactor when Build is clean on first attempt
merge_strategy: squash_local  # or: pr (for protected-branch repos)
tdd: auto                  # ask at plan time; or: true / false

charter:
  required: false          # set true after you've run /spec-flow:charter
  doctrine_load: [non-negotiables, architecture]
```

---

## Charter files

Authored once via `/spec-flow:charter`. Rarely changed after that. Every downstream spec, plan, and reviewer cites entries from these files by ID.

### `docs/charter/architecture.md`

Defines the layers of your project, what can call what, and which components own which concerns.

```markdown
# Architecture

## Top-level layers

- **API layer** — Express routes in `src/api/`. Handles HTTP concerns only.
- **Service layer** — Business logic in `src/services/`. No direct DB access.
- **Repository layer** — Data access in `src/repositories/`. Returns domain objects.

## Dependency direction

- API layer imports Service layer; Service layer imports Repository layer.
- No layer may import from a layer above it.
- **Forbidden:** API routes calling repositories directly, bypassing services.

## Component ownership

| Component | Owner | Boundary |
|---|---|---|
| `src/api/` | API team | HTTP in/out only |
| `src/services/` | Core team | Business rules |
| `src/repositories/` | Data team | DB queries |
```

### `docs/charter/non-negotiables.md`

Project-wide hard rules with stable IDs. Each entry has: statement, scope, rationale, and a concrete QA verification command. IDs are never reused — retired entries become tombstones.

```markdown
# Non-Negotiables (Project)

`NN-C-xxx` — project-wide binding rules. Write-once IDs; retired entries become tombstones.

### NN-C-001: No direct database access outside the repository layer
- **Type:** Rule
- **Statement:** All database queries must go through a class in `src/repositories/`.
  No `db.query()` calls in `src/api/` or `src/services/`.
- **Scope:** All files under `src/`
- **Rationale:** Prevents scattered query logic, makes data access testable in isolation.
- **How QA verifies:** `grep -r "db\.query\|knex\." src/api src/services` must return nothing.

### NN-C-002: All public API endpoints require authentication
- **Type:** Rule
- **Statement:** Every route registered under `/api/` must pass through the
  `requireAuth` middleware. Health-check routes at `/health` are exempt.
- **Scope:** `src/api/routes/`
- **Rationale:** No accidental unauthenticated exposure.
- **How QA verifies:** Review-board architecture reviewer confirms every route file
  imports and applies `requireAuth`, or has an explicit `// @public` exemption comment
  documented in this file.
```

### `docs/charter/coding-rules.md`

Conventions with teeth — the "style guide" that reviewers check. Uses `CR-xxx` IDs.

```markdown
# Coding Rules

### CR-001: All functions must have JSDoc type annotations
- **Type:** Rule
- **Statement:** Every exported function includes `@param` and `@returns` JSDoc.
  Internal helpers ≥ 10 lines also require annotations.
- **Scope:** `src/**/*.ts`

### CR-002: Error handling — never swallow errors silently
- **Type:** Rule
- **Statement:** `catch` blocks must either rethrow, log with context, or return
  a typed error object. Empty `catch` blocks are forbidden.
- **Scope:** All TypeScript files

### CR-003: Conventional commits with scope
- **Type:** Reference
- **Source:** https://www.conventionalcommits.org/en/v1.0.0/
- **Scope:** All commit messages
- **Statement:** `<type>(<scope>): <summary>` — scope = module name. Types: `feat`,
  `fix`, `docs`, `chore`, `refactor`, `release`.
```

### `docs/charter/tools.md`

The approved toolchain. Agents must not introduce alternatives without updating this file.

```markdown
# Tools

## Language and runtime

- **Primary:** TypeScript 5.x, Node.js 20 LTS

## Test runner

- **Runner:** Vitest 1.x
- **Coverage:** Istanbul via `@vitest/coverage-istanbul`
- **Target:** 80% line coverage on `src/services/` and `src/repositories/`

## Linter and formatter

- **Linter:** ESLint 9.x with `typescript-eslint`
- **Formatter:** Prettier 3.x

## Package manager

- **pnpm** 9.x. No `npm install` or `yarn` — the lockfile is `pnpm-lock.yaml`.

## Banned libraries

- `moment.js` — use `date-fns` instead (bundle size)
- `lodash` — use native ES2022+ methods
```

### `docs/charter/processes.md`

Branching model, review policy, release cadence, rollback procedure.

```markdown
# Processes

## Branching model

- **Main branch:** `main`
- **Feature branches:** `spec/<prd-slug>-<piece-slug>` for spec-flow pieces.
- **Hotfix branches:** `hotfix/<short-description>` directly off `main`.
- **Worktrees location:** `worktrees/` (per `.spec-flow.yaml`)

## Review policy

- **Required reviewers:** 1 for external PRs; maintainers may self-merge hotfixes.
- **Review-board:** fires automatically during `/execute` before every merge.

## Release cadence

- **Frequency:** On-demand. No fixed schedule.
- **Protocol:** bump `package.json`, tag `vX.Y.Z`, prepend CHANGELOG section.

## Commit style

- Conventional Commits (CR-003). Scope = module name.
- Squash-merge spec-flow pieces onto main.
```

### `docs/charter/flows.md`

End-to-end system workflows that agents designing new features must respect.

```markdown
# Flows

## Request lifecycle

```
client → API route → requireAuth middleware → service layer → repository → DB
                                ↓ (on error)
                           error handler → structured JSON error response
```

## User signup flow

```
POST /api/users/signup
  → validate body (Zod schema)
  → UserService.create(dto)
    → UserRepository.findByEmail(email) — must return null
    → bcrypt.hash(password)
    → UserRepository.create(hashed)
  → issue JWT
  → return 201 { userId, token }
```
```

---

## PRD: `docs/prds/<prd-slug>/prd.md`

Authored by `/spec-flow:prd`. Captures product intent — what the product is for, what it must do, what it must never do.

```markdown
---
name: My API
slug: my-api
status: active
version: 1
---

# Product Requirements — My API

**Project:** my-api
**Charter:** docs/charter/

## Goals

- **G-1:** Provide a REST API for managing user accounts and API keys.
- **G-2:** Authentication via JWT; all endpoints require valid tokens.
- **G-3:** Rate limiting enforced per-user to prevent abuse.

## Non-Goals

- Not a GraphQL API — REST only for v1.
- Not a billing system — payment processing is out of scope.

## Functional Requirements

- **FR-001:** `POST /api/users/signup` creates a new user; returns JWT.
- **FR-002:** `POST /api/auth/login` authenticates; returns JWT.
- **FR-003:** `GET /api/keys` lists the caller's API keys.
- **FR-004:** `POST /api/keys` creates a new API key with an expiry.

## Non-Functional Requirements

- **NFR-001:** P95 response time ≤ 200ms for all endpoints under 500 req/s.
- **NFR-002:** Zero plaintext credentials in logs or error responses.

## Non-Negotiables (Product)

### NN-P-001: Passwords are never stored in plaintext
- **Type:** Rule
- **Statement:** All passwords are hashed with bcrypt (cost factor ≥ 12) before
  storage. Plain passwords must never appear in logs, error messages, or DB columns.
- **How QA verifies:** Review-board checks for any `password` field written to DB
  without a `bcrypt.hash()` call upstream.

## Success Metrics

- **SC-001:** 100% of signup and login paths covered by integration tests before v1 ships.
- **SC-002:** No open `NFR-002` violation in any review-board run.
```

---

## Manifest: `docs/prds/<prd-slug>/manifest.yaml`

Tracks every piece — its status, which PRD sections it addresses, and (once spec/plan exist) where those files are. The status field drives the pipeline: `open → specced → planned → in-progress → merged`.

```yaml
schema_version: 1
generated: 2026-04-01
last_updated: 2026-04-28
prd_source: docs/prds/my-api/prd.md

pieces:
  - name: user-auth
    slug: user-auth
    description: Signup, login, JWT issuance, and bcrypt hashing.
    prd_sections: [G-2, FR-001, FR-002, NN-P-001]
    dependencies: []
    status: merged
    spec: docs/prds/my-api/specs/user-auth/spec.md
    plan: docs/prds/my-api/specs/user-auth/plan.md
    spec_approved: 2026-04-05
    plan_approved: 2026-04-07
    notes: Merged 2026-04-15. See learnings.md for JWT expiry edge-case findings.

  - name: api-gateway
    slug: api-gateway
    description: API key CRUD, rate limiting, per-user quota enforcement.
    prd_sections: [G-3, FR-003, FR-004, NFR-001]
    dependencies: [user-auth]     # rate limiting keys off user identity
    status: in-progress
    spec: docs/prds/my-api/specs/api-gateway/spec.md
    plan: docs/prds/my-api/specs/api-gateway/plan.md
    spec_approved: 2026-04-18
    plan_approved: 2026-04-20

  - name: admin-dashboard
    slug: admin-dashboard
    description: Internal dashboard for viewing user counts, key stats, and rate-limit hits.
    prd_sections: [G-1]
    dependencies: [user-auth, api-gateway]
    status: open
```

**Piece statuses:**

| Status | Meaning |
|---|---|
| `open` | Listed in manifest; no spec started yet |
| `specced` | Spec written and signed off; ready for `/spec-flow:plan` |
| `planned` | Plan written and signed off; ready for `/spec-flow:execute` |
| `in-progress` | Execute is actively running |
| `merged` | Branch merged to main |
| `done` | Backward-compat alias for `merged` (pre-v3 manifests) |
| `superseded` | Abandoned and replaced by another piece |
| `blocked` | External dependency or unresolved decision |

---

## Spec: `docs/prds/<prd-slug>/specs/<piece>/spec.md`

Authored by `/spec-flow:spec`. Defines *what* done looks like — from the user's perspective — for one piece. The acceptance criteria are the oracle.

```markdown
---
charter_snapshot:
  architecture: 2026-04-01
  non-negotiables: 2026-04-01
  coding-rules: 2026-04-01
  tools: 2026-04-01
  processes: 2026-04-01
  flows: 2026-04-01
slug: user-auth
prd: my-api
status: approved
created: 2026-04-04
approved: 2026-04-05
branch: spec/my-api-user-auth
---

# Spec: user-auth — User Authentication

**PRD Sections:** G-2, FR-001, FR-002, NN-P-001
**Status:** approved

## Goal

Ship the signup and login endpoints with bcrypt password hashing and JWT issuance.
No user should be able to log in without a valid bcrypt-hashed credential, and no JWT
should be issued without verifying the hash.

## In Scope

- `POST /api/users/signup` — create account, hash password, return JWT
- `POST /api/auth/login` — verify credentials, return JWT
- `UserService` + `UserRepository` in service/repository layers
- Vitest integration tests for the full signup → login round-trip

## Out of Scope

- Password reset flow (separate piece)
- Social auth (OAuth, Google) — separate piece or separate PRD

## Acceptance Criteria

- **AC-1:** `POST /api/users/signup` with valid body returns `201 { userId, token }`.
  Token decodes to `{ sub: userId, iat, exp }` with `exp` 24h from issuance.
- **AC-2:** `POST /api/users/signup` with a duplicate email returns `409 Conflict`
  with body `{ error: "email_already_registered" }`.
- **AC-3:** `POST /api/auth/login` with correct credentials returns `200 { token }`.
- **AC-4:** `POST /api/auth/login` with wrong password returns `401 Unauthorized`
  with body `{ error: "invalid_credentials" }`. Same response for unknown email
  (no user-enumeration leak).
- **AC-5:** Password stored in DB is a bcrypt hash (starts with `$2b$`). Plaintext
  password is never written to DB or logs.

## Non-Negotiables Honored

- **NN-C-001** (repo-level): n/a (marketplace rule; does not apply to this project).
- **NN-P-001** (bcrypt requirement): AC-5 directly implements this. The integration test
  asserts the DB column starts with `$2b$` and that the signup request body's `password`
  field does not appear in the stored row.

## Coding Rules Honored

- **CR-001** (JSDoc): `UserService.create()` and `UserRepository.findByEmail()` will have
  full `@param`/`@returns` annotations authored in the plan's Phase 1.
- **CR-002** (no silent catches): login's credential-check path must rethrow or return
  a typed error — never swallow.
- **CR-003** (conventional commits): each phase lands a `feat(user-auth): ...` commit.
```

---

## Plan: `docs/prds/<prd-slug>/specs/<piece>/plan.md`

Authored by `/spec-flow:plan`. Defines *how* the code will be shaped — file paths, class signatures, test patterns — phase by phase.

```markdown
---
charter_snapshot:
  architecture: 2026-04-01
  non-negotiables: 2026-04-01
  coding-rules: 2026-04-01
  tools: 2026-04-01
  processes: 2026-04-01
  flows: 2026-04-01
slug: user-auth
prd: my-api
spec: docs/prds/my-api/specs/user-auth/spec.md
tdd: true
created: 2026-04-06
approved: 2026-04-07
branch: spec/my-api-user-auth
---

# Plan: user-auth — User Authentication

**Status:** approved
**Track:** TDD (behavior-bearing code)

## Overview

Three phases, bottom-up: repository layer first (data access), service layer second
(business logic), API routes last (HTTP). Each phase is independently testable —
Phase 2 tests stub the repository; Phase 3 tests hit the service via supertest.

## Phases

### Phase 1: UserRepository
**Track:** TDD
**ACs Covered:** AC-5 (bcrypt storage assertion)
**Files:**
- `src/repositories/UserRepository.ts` — `findByEmail(email)`, `create(dto)`
- `src/repositories/__tests__/UserRepository.test.ts`
**Exit Gate (TDD):** `pnpm test src/repositories` green.
**Charter constraints honored:**
- **NN-C-001** (repo layer boundary): repository is the only place that calls `db.query`.
- **CR-001** (JSDoc): `findByEmail` and `create` annotated.

[TDD-Red] Write tests for:
- `findByEmail` returns null on miss, returns user object on hit
- `create` inserts a row and returns `{ id, email, passwordHash }`
- `create` throws `DuplicateEmailError` on unique-constraint violation

[Implement] Implement `UserRepository` to pass the Red tests.

[Verify]
```
pnpm test src/repositories/__tests__/UserRepository.test.ts
```

---

### Phase 2: UserService
**Track:** TDD
**ACs Covered:** AC-1, AC-2, AC-3, AC-4, AC-5 (service-layer assertions)
**Files:**
- `src/services/UserService.ts` — `create(dto)`, `authenticate(email, password)`
- `src/services/__tests__/UserService.test.ts`
**Exit Gate (TDD):** `pnpm test src/services` green.

[TDD-Red] Write tests for:
- `create` hashes password with bcrypt before storing (AC-5)
- `create` rejects duplicate email with `DuplicateEmailError` (AC-2)
- `authenticate` returns user on correct credentials (AC-3)
- `authenticate` throws `InvalidCredentialsError` on wrong password or unknown email (AC-4)

[Implement] Implement `UserService`.

[Verify]
```
pnpm test src/services/__tests__/UserService.test.ts
```
```

---

## Learnings: `docs/prds/<prd-slug>/specs/<piece>/learnings.md`

Written by `/spec-flow:execute` after a piece merges. Captures what worked, what QA caught, and concrete recommendations for future specs. Two reflection agents contribute: `reflection-process-retro` (orchestration lessons) and `reflection-future-opportunities` (new feature ideas and backlog candidates).

```markdown
# Learnings: my-api/user-auth

## Patterns that worked well

**Bottom-up phase ordering paid off.** The repository → service → API ordering meant
Phase 3 could stub at the service boundary and hit real behavior without a DB. AC-4
(no user-enumeration leak) was verifiable entirely in service tests, catching the
info-leak before it reached the HTTP layer.

**Single-responsibility phase grouping.** Each phase owned one layer. No file was
touched by two phases. Refactor skipped on all three — a signal that the phase
boundaries were well-drawn.

## Issues QA caught

**Missing error type export.** `DuplicateEmailError` was defined in `UserService.ts`
but not exported. `qa-phase` caught this in Phase 2 — the Phase 3 route handler
would have imported it by path-hack without the flag.

**JWT `exp` clock skew.** The integration test for AC-1 used `Date.now()` directly
instead of the token's `iat` to compute expected expiry. Edge-case reviewer flagged
that a <1s test run could produce a flaky assertion. Fixed before merge.

## Recommendations for future specs

1. **Declare error types in a shared `src/errors.ts` module before Phase 1.**
   Defining domain errors in service files and exporting them upward creates
   import-direction violations. Next piece: define all error types first.

2. **AC for the "unknown email returns same response as wrong password" invariant.**
   AC-4 stated it in prose but no test asserted the exact response body match between
   the two error paths. Add: `assert response.body.error === "invalid_credentials"` for
   both paths in the same test or parameterized test.
```

---

## Worktrees: `worktrees/<branch-slug>/`

Each piece gets its own working directory so you can context-switch without stashing.
The branch and worktree are named by combining the PRD slug and piece slug:

```
branch name:    spec/my-api-api-gateway
worktree path:  worktrees/spec-my-api-api-gateway/
```

The worktree is created by `/spec-flow:spec` when the piece branch is first set up.
It's removed after the piece merges to main.

**Multiple pieces in flight at once:**

```
worktrees/
├── spec-my-api-api-gateway/     piece 1 (in-progress on this PRD)
└── spec-data-platform-ingest/   piece from a different PRD, also in-progress
```

Each worktree is a full checkout of the repo on its branch. `git status` inside
`worktrees/spec-my-api-api-gateway/` sees only that branch's uncommitted changes.

---

## `docs/improvement-backlog.md` — cross-PRD learnings

Process retros and future feature ideas that don't belong to any one PRD. Written by
`reflection-process-retro` during execute. New backlog items surface here when they're
too large or cross-cutting to fit in a single PRD's `backlog.md`.

```markdown
# Improvement Backlog

## Lightweight task flow — lightweight spec→plan→execute for small work

**Status:** concept — awaiting dedicated PRD brainstorm
**Captured:** 2026-04-24

Not all work fits a full PRD. Bug fixes, small maintenance items, quick improvements
shouldn't require a manifest entry, a full multi-phase plan, or charter-level scoping.

Proposed layout (sibling to `docs/prds/`):
  docs/tasks/<task-slug>/spec.md
  docs/tasks/<task-slug>/plan.md

This item stays here until it graduates to a formal PRD piece.
```

**Routing rule:** items that apply to one PRD go in `docs/prds/<slug>/backlog.md`;
items that span multiple PRDs or relate to spec-flow's own process go here.

---

## How the files connect

```
docs/charter/                     ← authored once, rarely changed
    └── NN-C-xxx, CR-xxx IDs

docs/prds/<prd-slug>/prd.md       ← cites charter; defines NN-P-xxx
    │
    └── manifest.yaml             ← lists pieces + statuses
          │
          ├── specs/<piece>/spec.md  ← cites NN-C, NN-P, CR IDs by name
          │                             charter_snapshot: records charter dates
          │
          └── specs/<piece>/plan.md  ← cites same IDs; allocates to phases
                │
                └── execute produces:
                      ├── learnings.md  (in same specs/<piece>/ dir)
                      └── entries in docs/improvement-backlog.md
```

Every artifact carries a `charter_snapshot:` front-matter block with the `last_updated`
dates of the charter files it was authored against. If the charter changes after a spec is
written, the pipeline flags the drift and prompts resolution before the plan runs.

---

## Where to go next

- [Pipeline](./pipeline.md) — why the five stages exist and what ambiguity each resolves.
- [Charter system](./charter-system.md) — deep dive on NN-C / NN-P / CR namespaces and citation integrity.
- [commands/charter.md](../commands/charter.md) — running `/spec-flow:charter` step by step.
- [commands/prd.md](../commands/prd.md) — running `/spec-flow:prd`, including multi-PRD projects.
- [commands/spec.md](../commands/spec.md) — running `/spec-flow:spec`.
- [commands/plan.md](../commands/plan.md) — running `/spec-flow:plan`.
