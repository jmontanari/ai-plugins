# pi-020-dc-harden Validation Record

## Phase 1: Anti-cheat blob anchor + journal migration

**Run date:** 2026-06-05
**Branch:** master (worktree piece-pi-020-dc-harden)
**Harness:** `docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh`

### Command

```
bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh ANCHOR-1 ANCHOR-2 MIG-1 PROD-1 SF3-1
```

### Results

```
PASS ANCHOR-1
PASS ANCHOR-2
PASS MIG-1
PASS PROD-1
PASS SF3-1
```

### Case Descriptions

| Case | AC | Description | Result |
|------|-----|-------------|--------|
| ANCHOR-1 | AC-1 | Orchestrator runs `git hash-object -w` at red-done; returned blob SHA matches `git hash-object` (without -w) and `git cat-file -t` prints `blob` (blob written to object store). | PASS |
| ANCHOR-2 | AC-2 | After red-done, mutate the test file; `git hash-object` on the working tree now differs from the stored blob SHA — the barrier would detect the tamper. | PASS |
| MIG-1 | AC-5 | Old-format journal (no `anchor` field, sha256sum values) is honored on resume via sha256sum path; exit 0 with no re-anchor. | PASS |
| PROD-1 | AC-3 | A production-file change does NOT trip the barrier integrity check; the G9b barrier iterates only keys in `red_manifest_hashes` (the Red test file), so the production file is invisible to the gate. | PASS |
| SF3-1 | AC-4 | After a G9 formatter autofix (SF3 sweep), the re-anchor guard writes a new blob SHA; the G9b barrier passes using the post-sweep blob SHA, and the pre/post SHAs differ confirming the re-anchor was necessary. | PASS |

### Grep Oracles (Phase 1)

**T-1/T-2 (G4 record + G9b verify):**
```
plugins/spec-flow/skills/execute/SKILL.md:1191: git hash-object -w (G4 record)
plugins/spec-flow/skills/execute/SKILL.md:1281: git hash-object -w (SF3 re-anchor)
plugins/spec-flow/skills/execute/SKILL.md:1287: git hash-object (G9b verify loop)
plugins/spec-flow/skills/execute/SKILL.md:1803: git hash-object (resume re-verify)
```
G9b deferred-block: sha256sum removed from bash loop; fallback note at L1293 is prose only.
Flat-phase sha256sum lines at ~L421 and ~L522 remain untouched.

**T-3 (SF3):** SF3 blockquote at L1281 names `git hash-object -w`.

**T-4 (resume FR-4):** `anchor: blob` appears at L1191 (G4 set), L1293 (barrier fallback note), L1803 (resume branch).

**T-5 (journal):**
- `anchor` schema row added (L26), `"anchor": "blob"` in JSON example (L44).
- `red_manifest_hashes` schema row: "path → git blob SHA (the output of `git hash-object -w`)".
- `grep -c "SHA-256 hex digest"` on `red_manifest_hashes` row: 0.

**T-6/T-7 (twin consistency):**
- `tdd-red.md` Rule 9 byte-identical to `tdd-red.agent.md` Rule 9: CONFIRMED.
- `implementer.md` "What 'Red test modification' means" byte-identical to `implementer.agent.md`: CONFIRMED.
- Deferred-group branch absent in `implementer.agent.md`: CONFIRMED.

---

## Phase 2: Concurrent git-free dispatch + Race-2 oracle

**Run date:** 2026-06-05
**Branch:** master (worktree piece-pi-020-dc-harden)
**Harness:** `docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh`

### Command

```
bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh INV-1 INV-2 INV-3 INV-5
```

### Results

```
PASS INV-1
PASS INV-2
PASS INV-3
PASS INV-5
```

### Case Descriptions

| Case | AC | Description | Result |
|------|-----|-------------|--------|
| INV-1 | AC-6 | Two sub-phases write distinct files concurrently (no git add/commit); barrier explicit-pathspec commit = exact union of 4 files; journal file absent from commit. | PASS |
| INV-5 | AC-6 | Same as INV-1 but `.phase-group-journal.json` present in working tree; barrier commit still contains only the 4 sub-phase files — journal excluded by pathspec discipline. | PASS |
| INV-2 | AC-7 | Scoped oracle for sub-phase A (path-scoped) exits 0 while sub-phase B's test is still red on the shared working tree — Race-2 prevention confirmed. | PASS |
| INV-3 | AC-7 | Unscoped oracle (running B's still-red test) exits non-zero in the same state — proves scoping is necessary; an unscoped oracle would produce a false failure for A. | PASS |

### Grep Oracles (Phase 2)

**T-1 (knob def "concurrent"):**
```
plugins/spec-flow/skills/execute/SKILL.md:1177: concurrent git-free (G4 header)
plugins/spec-flow/skills/execute/SKILL.md:1179: concurrent git-free section (branch-intro prose)
```

**T-2 (G4 "concurrently"):**
```
plugins/spec-flow/skills/execute/SKILL.md:1183: [P] sub-phases **concurrently** on the git-free foundation
```

**T-3 (cross-ref fixed — "line 499" removed):**
```
grep -c "line 499" → 0
```

**T-4 (whole-non-integration-suite in G9b):**
```
plugins/spec-flow/skills/execute/SKILL.md:1192: whole-non-integration-suite green invariant at barrier
plugins/spec-flow/skills/execute/SKILL.md:1297: Run the whole-non-integration-suite oracle (new G9b step 2)
```

**T-5 (flag rule extended):**
```
plugins/spec-flow/skills/execute/SKILL.md:1187: every (re-)dispatch + concurrency/isolation extension
```

**T-6 (journal serial-note → concurrent):**
```
plugins/spec-flow/reference/deferred-commit-journal.md:77: dispatch is **concurrent** (git-free)
```

---

## Phase 3: INV-9 runtime isolation + serial-replay backstop

**Run date:** 2026-06-05
**Branch:** master (worktree piece-pi-020-dc-harden)
**Harness:** `docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh`

### Command

```
bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh INV-9
```

### Results

```
PASS INV-9
```

### Case Descriptions

| Case | AC | Description | Result |
|------|-----|-------------|--------|
| INV-9 | AC-8 | Assertion 1: isolated TMPDIRs prevent shared-tmp collision; Assertion 2: concurrent failure + serial pass → collision resolved (not silently-green); Assertion 3: concurrent failure + serial failure → real failure surfaced loudly. | PASS |

### Grep Oracles (Phase 3)

**T-1 (isolation envelope + TMPDIR in G4):**
```
plugins/spec-flow/skills/execute/SKILL.md:1185: isolation envelope … unique TMPDIR
```

**T-2 (serial-replay row in G6):**
```
plugins/spec-flow/skills/execute/SKILL.md:1385: Runtime collision … Serial-replay backstop … slower-never-wrong
```

---

## Phase 4: Base-ref parameterization

**Run date:** 2026-06-05
**Branch:** master (worktree piece-pi-020-dc-harden)
**Harness:** `docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh`

### Command

```
bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh BASE-1 BASE-2 BASE-3
```

### Results

```
PASS BASE-1
PASS BASE-2
PASS BASE-3
```

### Case Descriptions

| Case | AC | Description | Result |
|------|-----|-------------|--------|
| BASE-1 | AC-10 | Resolver tier 1 (`git symbolic-ref`) returns `master` when a local clone's `origin/HEAD` points to `master`. | PASS |
| BASE-2 | AC-11 | All three resolver tiers (symbolic-ref, remote show, .spec-flow.yaml) return empty when no remote exists and no config file is present — the resolver would emit a loud error and exit non-zero (no silent `main` fallback). | PASS |
| BASE-3 | AC-12 | Config fallback (tier 3) returns `trunk` when `.spec-flow.yaml` contains `default_branch: trunk` and tiers 1–2 are empty (no remote). | PASS |

### Grep Oracles (Phase 4)

**T-1 (resolver recipe in SKILL.md):**
```
plugins/spec-flow/skills/execute/SKILL.md:1470: symbolic-ref --short refs/remotes/origin/HEAD
```

**T-2 (zero main..HEAD literals):**
```
grep -rn "main\.\.HEAD" execute/SKILL.md verify.md verify.agent.md → 0 matches
```

**T-3 (verify twins byte-identical):**
```
diff -q verify.md verify.agent.md → (no output)
```

**T-4 (default_branch in config template):**
```
plugins/spec-flow/templates/pipeline-config.yaml:55: # default_branch: the base branch for `git diff <base>..HEAD`
plugins/spec-flow/templates/pipeline-config.yaml:58: # default_branch:
```
