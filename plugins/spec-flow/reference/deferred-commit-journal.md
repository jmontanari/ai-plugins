# Deferred-commit journal

This document defines the deferred-commit Phase Group journal: the durable, git-free checkpoint that lets `plugins/spec-flow/skills/execute/SKILL.md` run a group of parallel TDD sub-phases without each sub-phase racing to write the shared git index, and lets execute resume mid-group without re-running work that already passed. All skills and agents that read, write, or resume a Phase Group journal defer to this reference for the schema, lifecycle, resume algorithm, recovery recipe, and barrier-commit discipline.

## Purpose

A deferred Phase Group runs several TDD sub-phases (Red → Build) against a single working tree **without committing between them**. Deferring the commits removes the shared-index race that otherwise corrupts parallel sub-phases that each call `git add`. But deferring the commits also removes the natural durable checkpoint that a commit provides: if execute is interrupted mid-group, there is no SHA per sub-phase to resume from.

The journal restores that durability without restoring the commits. It is a single human-readable JSON file (NN-P-001) that records, for the active Phase Group only:

- the SHA the group started from (`group_start_sha`), so any sub-phase can be file-scoped-reset to a known-clean baseline;
- which sub-phases have reached which status, so a resume knows what to trust, what to recover, and what was never started;
- the Red manifest hashes per sub-phase, so a `green` sub-phase can be trusted after a working-tree-hash re-verification rather than re-run.

The journal **exists only during a deferred Phase Group**. It is written when the group starts (Step G1), updated as sub-phases transition, and removed after the barrier work-commit lands. Outside a deferred group there is no journal. It is never committed (see Lifecycle).

## Journal schema (Tier 1)

The journal is a single JSON object. Tier 1 is the only tier implemented today (see Tier 2 for the forward-reference design). Fields:

| Field | Type | Meaning |
|-------|------|---------|
| `group_start_sha` | string | The commit SHA the Phase Group started from. The file-scoped recovery baseline for every sub-phase in the group. Written once at Step G1, never mutated. |
| `group_letter` | string | The Phase Group's letter (e.g. `A`). Identifies which group this journal belongs to so a resume binds it to the active group. |
| `sub_phases` | map | Keyed by sub-phase id `<letter>.<n>` (e.g. `A.1`, `A.2`). Empty `{}` at group start; one entry added/updated per sub-phase as it progresses. Absence of a key means that sub-phase was never started. |
| `anchor` | string | `blob` for journals written at/after 5.2.0 (red_manifest_hashes are git blob SHAs); ABSENT for ≤5.1.0 journals (red_manifest_hashes are `sha256sum` digests — honored as-is on resume). |

Each value in `sub_phases` is an object:

| Field | Type | Meaning |
|-------|------|---------|
| `scope` | string[] | The literal file paths this sub-phase owns (Red manifest paths ∪ Build production paths). Used verbatim as the pathspec for file-scoped recovery and for the barrier commit's union. Literal paths only — never globs. |
| `status` | string | One of `pending` \| `red-done` \| `green` \| `failed`. `pending` = dispatched, no Red yet; `red-done` = Red's failing tests staged; `green` = Build's oracle passed; `failed` = Build's oracle did not pass (or QA rejected). |
| `red_manifest_hashes` | map | Map of path → git blob SHA (the output of `git hash-object -w`, written by the orchestrator at `red-done`), one entry per Red test file in this sub-phase's scope. On resume, a `green` sub-phase's working-tree files are re-hashed against this map and trusted on an exact match. |

The `status` field is documented as: `status` — one of `pending` | `red-done` | `green` | `failed`.

Concrete example object (a group `A` mid-flight: `A.1` green, `A.2` green, `A.3` failed):

```json
{
  "group_start_sha": "af57b38c1d2e4f5a6b7c8d9e0f1a2b3c4d5e6f70",
  "group_letter": "A",
  "anchor": "blob",
  "sub_phases": {
    "A.1": {
      "scope": ["src/parser/tokens.py", "tests/parser/test_tokens.py"],
      "status": "green",
      "red_manifest_hashes": {
        "tests/parser/test_tokens.py": "9f2c1a7b3e4d5c6f8a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f"
      }
    },
    "A.2": {
      "scope": ["src/parser/ast.py", "tests/parser/test_ast.py"],
      "status": "green",
      "red_manifest_hashes": {
        "tests/parser/test_ast.py": "3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f"
      }
    },
    "A.3": {
      "scope": ["src/parser/eval.py", "tests/parser/test_eval.py"],
      "status": "failed",
      "red_manifest_hashes": {
        "tests/parser/test_eval.py": "7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b"
      }
    }
  }
}
```
<!-- Note: hash values in red_manifest_hashes are git blob SHAs (output of `git hash-object -w`), not SHA-256 hex digests, when `"anchor": "blob"` is present. -->

## Lifecycle

The journal's lifetime is bounded by the Phase Group:

1. **Written at Step G1 (group start).** When execute begins a deferred Phase Group, it writes the journal with `group_start_sha` set to the current HEAD, `group_letter` set, and `sub_phases` an empty `{}`.
2. **Updated at each sub-phase status transition.** As each sub-phase advances, the orchestrator updates that sub-phase's entry in `sub_phases`: adds the entry at `pending`, records `red_manifest_hashes` and flips to `red-done` when Red writes its tests, flips to `green` when Build's oracle passes, or `failed` on an oracle/QA failure. Under `deferred_commit: auto` dispatch is **concurrent** (git-free; staging deferred to the barrier removes the shared-index race — see SKILL.md Step G4). The journal's value is crash-resume durability AND it records per-sub-phase status for the barrier whole-suite gate; writes are incremental and concurrency-safe (one sub-phase entry at a time).
3. **Removed after the barrier work-commit.** Once the barrier commit (see Barrier commit recipe) lands the whole group's union, the journal file is deleted. After deletion there is no journal until the next deferred group starts.

The journal is **never committed**. The real, portable guarantee is the **pathspec-only commit discipline**: every commit in a deferred group uses an explicit pathspec listing only sub-phase scope files, and the journal's path is never in any commit pathspec — so no commit can pick it up regardless of `.gitignore`.

A `.gitignore` entry for the journal filename is a **best-effort, this-repo** secondary defense (it lives in THIS marketplace repo, added in Phase 2, so a stray `git add -A` here can't pick it up). It is NOT present in consumer projects where spec-flow runs, so it cannot be relied on as the guarantee there — in consumer projects the out-of-commit property rests **entirely** on the pathspec-only discipline. Where both are present (this repo), they are defense in depth; where only the pathspec discipline is present (consumer projects), that discipline alone is sufficient.

## Resume algorithm

When execute (re)starts, it runs this ordered algorithm before doing any sub-phase work:

1. **Look for the journal** for the active Phase Group (matching `group_letter`).
2. **No journal → fresh group start.** This is not an error — it is the normal case for a group that has not begun. Proceed to Step G1 (write a fresh journal) and run the group from scratch.
2a. **Stale `group_letter` → treat as no-journal (fresh start).** A journal whose on-disk `group_letter` does NOT equal the active group's letter is STALE — an orphan from a crash between the G9b barrier commit and the journal `rm` (Lifecycle Step 3), or an aborted prior group. Do NOT resume from it: treat it exactly as the no-journal case (Step 2 above), log the orphan (NN-C-006 passive surface), and overwrite it at Step G1. This is what makes the single-fixed-filename safe across groups: the resume binds the journal to the active group by `group_letter`, and a non-matching letter is never trusted.
3. **Read `group_start_sha`.** This is the file-scoped recovery baseline used in Steps 5–6.
4. **`green` sub-phases → re-verify by hash, then trust.** For each sub-phase with `status: green`, re-hash **only the Red test files** (the keys of `red_manifest_hashes`) against their stored hashes. If the journal carries `"anchor": "blob"` (written by v5.2.0+), verify with `git hash-object`; if the field is absent (written by ≤5.1.0, FR-4 migration path), verify with `sha256sum` instead. The production files listed in `scope` are **trusted by association** and are **NOT independently re-hashed** — a matching Red test hash is taken as proof the whole sub-phase is intact. On an exact match for every Red test file, trust the sub-phase as done and **do not re-run it** and **do not touch its files**. (A mismatch on any Red test file means the working tree drifted since the green checkpoint — treat that sub-phase as incomplete and fall through to Step 5.)
5. **Incomplete sub-phases (`pending` / `red-done` / `failed`) → recover, then re-run.** Apply the file-scoped recovery recipe (next section) to the sub-phase's `scope`, resetting just those paths to `group_start_sha`, then re-run the sub-phase from Red. The reset is logged (NN-C-006 passive surface).
6. **Sub-phases absent from the journal → not started.** A `<letter>.<n>` key that does not appear in `sub_phases` was never dispatched. Run it fresh; no recovery needed (its files were never written).

### Worked example (resume trace: 2 green + 1 failed)

Resuming the example journal above (group `A`: `A.1` green, `A.2` green, `A.3` failed):

- **`A.1` (green):** re-hash **only the Red test file** `tests/parser/test_tokens.py` (the sole key of `red_manifest_hashes`) via `git hash-object` → matches `9f2c…1e2f`. Trusted. The production file `src/parser/tokens.py` is **not independently re-hashed** — it rides on the matching test hash. Not re-run; its files are left **byte-identical** — untouched.
- **`A.2` (green):** re-hash **only the Red test file** `tests/parser/test_ast.py` via `git hash-object` → matches `3e4f…3e4f`. Trusted; `src/parser/ast.py` rides on that match (not independently re-hashed). Not re-run; files left byte-identical.
- **`A.3` (failed):** file-scoped recovery on `["src/parser/eval.py", "tests/parser/test_eval.py"]` against `group_start_sha`, then re-run from Red.

Net effect: **only the failed sub-phase re-runs**; the two green sub-phases are verified by re-hashing **their Red test files** alone via `git hash-object` (the only files we re-hash — production files are trusted by association, NOT independently verified), and because we leave trusted sub-phases untouched their files remain byte-identical to before the interruption. They consume zero agent turns. Note "byte-identical" here describes the files we leave untouched, not a verification claim over all of them — only the Red test files we re-hashed are actually checked; production-file drift is not detected (a known Tier-1 limitation). This is the durability the journal buys without committing between sub-phases.

## File-scoped recovery recipe

Recovering an incomplete sub-phase must reset **only that sub-phase's `scope`**, never the whole tree — its siblings' green files must stay byte-identical. The recipe is path-scoped and turns on a created-vs-modified asymmetry, because `git restore --source` restores tracked content but does **not** remove files that did not exist at the source SHA.

**Scope-path sanitization (defense for the interpolated-path recipes below).** Before interpolating any journal `scope` entry into an `rm` or `git restore` pathspec, reject any entry that is empty, `.`, `/`, absolute (leading `/`), or contains a `..` segment. A malformed or hostile scope entry could otherwise widen the pathspec beyond the sub-phase.

For each path in the sub-phase's `scope`:

- **Modified files** (existed at `group_start_sha`): restore the tracked content from the baseline. The restore pathspec is the **modified subset only** — `git restore --source` ABORTS the entire operation (restores nothing) if the pathspec includes a path that did not exist at the source SHA, so created files must never appear here.

  ```bash
  git restore --source=$group_start_sha --worktree -- <modified paths>
  ```

- **Created files** (did NOT exist at `group_start_sha` — new in this sub-phase): `git restore --source` leaves them in place, so remove them explicitly. Use the idempotent flags so recovery is re-entrant (a crash-and-resume between the `rm` and the re-run must not hard-error):

  ```bash
  rm -f -- <created paths>
  git rm --cached --ignore-unmatch -- <created paths>   # only if the created file was staged
  ```

`git reset` to a SHA is **never** used for sub-phase recovery — it is index/HEAD-wide and would clobber sibling sub-phases' work. A SHA-targeted `git reset` is reserved exclusively for a whole-group human-abort (tearing down the entire group), never for an in-group sub-phase reset.

### Worked example (recovery of a failed sub-phase)

Recovering `A.3`, whose `scope` is `["src/parser/eval.py", "tests/parser/test_eval.py"]`, where at `group_start_sha` (`af57b38…`) `src/parser/eval.py` already existed but `tests/parser/test_eval.py` is new (Red created it this group):

```bash
# Modified file existed at the baseline — restore its content:
git restore --source=af57b38c1d2e4f5a6b7c8d9e0f1a2b3c4d5e6f70 --worktree -- src/parser/eval.py

# Created file did not exist at the baseline — git restore won't remove it, so (idempotent flags):
rm -f -- tests/parser/test_eval.py
git rm --cached --ignore-unmatch -- tests/parser/test_eval.py   # it was staged by Red
```

After this, `A.3`'s scope is exactly as it was at group start; `A.1` and `A.2` files are untouched. The sub-phase re-runs from Red.

## Barrier commit recipe

At the group barrier (all sub-phases green), the deferred commits collapse into a single work-commit covering the **union** of every sub-phase's scope. Union = ⋃ sub-phases of (Red manifest paths ∪ Build production paths).

A bare `git commit -- <paths>` fails on the union with `did not match any file(s) known to git`, because the git-free sub-phase files were never staged — they are untracked. So the recipe stages explicitly first, then commits with the same pathspec:

```bash
git add -- <union>
git commit -m "<msg>" -- <union>
```

The explicit `git add -- <union>` is required (it is what tracks the previously-untracked files); the pathspec on `git commit` keeps the commit scoped to exactly the union (and keeps the journal — never in `<union>` — out of the commit, per Lifecycle). The plan.md progress commit is a **separate** commit, made after the work-commit; it is not folded into the barrier commit.

<!-- Example: union of A.1, A.2, A.3 from the schema example:
     git add -- src/parser/tokens.py tests/parser/test_tokens.py \
                src/parser/ast.py tests/parser/test_ast.py \
                src/parser/eval.py tests/parser/test_eval.py
     git commit -m "feat(parser): group A — tokens, ast, eval" -- \
                src/parser/tokens.py tests/parser/test_tokens.py \
                src/parser/ast.py tests/parser/test_ast.py \
                src/parser/eval.py tests/parser/test_eval.py
-->

After the work-commit lands, the journal is removed (Lifecycle Step 3).

## Working-tree enumeration over an untracked union (deferred_commit: auto)

Several `execute` steps need to enumerate "what changed" over a Phase Group's sub-phase scope **before** the barrier work-commit lands (Step G9b). This is the canonical recipe for that enumeration; the steps that need it (G7 post-Refactor validation, G8 Group Deep QA `## Files changed`, G9 hook sweep, Pass-2 focused re-review) point here rather than re-deriving it.

**WHY a special recipe is needed.** Under `deferred_commit: auto` the sub-phase files are **untracked** until the Step G9b barrier work-commit. Two consequences:

- `git diff $group_start_sha..HEAD` (and `git diff --numstat $group_start_sha..HEAD`) is **empty pre-barrier** — there is no per-sub-phase commit in the range, so the committed-range diff reports nothing.
- A bare `git diff -- <path>` (and `git diff --numstat -- <path>`) shows **NOTHING for untracked files** — it diffs the index against the working tree, and an untracked path is in neither, so it is silently omitted.

So the enumeration must be computed against the **working tree**, scoped to the journal `sub_phases` scope union (or, for the Pass-2 case, a single sub-phase's scope).

**File list — use `git status --porcelain`.** It reports `?? <path>` for untracked files and ` M <path>` for modified files, so it enumerates both the created and the modified members of the union. Filter its output to the journal `sub_phases` scope union (the union of every sub-phase's `scope`, each of which is Red manifest paths ∪ Build production paths):

```bash
git status --porcelain   # then keep only paths inside the journal sub_phases scope union
```

**Per-file line counts / unified diff — use `git diff --no-index` against `/dev/null`.** For each file in the filtered list, diff it against the empty file. Exit status 1 means "the files differ" and is **normal** here (not an error):

```bash
git diff --numstat --no-index /dev/null <path>   # line counts; exit 1 = "files differ" is normal
git diff --no-index /dev/null <path>             # unified diff form
```

**Equivalent alternative — intent-to-add then diff.** `git add -N -- <union>` (intent-to-add) makes the untracked paths visible to a bare `git diff`, after which the ordinary forms work over the whole union at once:

```bash
git add -N -- <union>            # intent-to-add the untracked paths
git diff --numstat -- <union>    # line counts
git diff -- <union>              # unified diff
```

**CAVEAT (empirical, load-bearing).** Do **NOT** lead with a bare `git diff [--numstat] -- <path>` for an untracked union — it silently omits the untracked files, which are exactly the created files that dominate a git-free sub-phase, so it under-reports with no error signal. The bare `git diff` form is acceptable **only** on the already-modified subset, or **after** an `git add -N` intent-to-add.

## Tier 2 (future — not implemented)

Tier 1 (above) survives a process interruption: the journal plus the working tree are enough to resume. Tier 1 does **not** survive a working-tree wipe (e.g. an accidental `git clean -fdx` or a lost worktree), because the in-flight sub-phase content lives only in the uncommitted working tree.

Tier 2 is a forward-reference design — **not implemented today** — that would add durable, wipe-surviving checkpoints without polluting the branch history:

- At each sub-phase `green`, write a **dangling commit** with `commit-tree` against a **private `GIT_INDEX_FILE`** (so the real index and the branch ref are untouched). The journal would record the resulting dangling SHA per sub-phase.
- Because the dangling commit is a real object in the object database, the sub-phase content survives a working-tree wipe and is recoverable via:

  ```bash
  git checkout <sha> -- .
  ```

- Tier 2 would be gated by a future `journal_tier` knob (Tier 1 default; Tier 2 opt-in), so the cheaper Tier-1 path stays the default and the extra object-writing cost is only paid when a project asks for wipe-survival.

This section is documented for forward reference only; nothing in the current pipeline writes Tier-2 checkpoints.

## See also

- `plugins/spec-flow/reference/spec-flow-doctrine.md` — commit-cadence section documenting the deferred-commit model and the working-tree-hash anti-cheat.
- `plugins/spec-flow/skills/execute/SKILL.md` — the orchestrator that writes, updates, resumes from, and removes this journal.
- `plugins/spec-flow/templates/pipeline-config.yaml` — declares the `deferred_commit` knob that turns the deferred-commit model on or off.
