# spec-flow e2e smoke test

## What this is

A peer to the coherence linter (`plugins/spec-flow/hooks/tests/test-lint-skill-coherence.sh`), covering the full pipeline execution path. Implements FR-013: an on-demand, operator-runnable harness that verifies the end-to-end spec-flow pipeline contract without invoking a model.

Three assertion layers:

- **L1 static** — commit-subject grammar, dispatch-sequence rules, contract artifact presence; runs in < 5 s against committed fixtures.
- **L2 fixture-replay + audit** — replays fixture commits against the full L1+L2 contract; `--audit` mode re-runs against a specific piece directory.
- **L3 live-verification substrate** — post-run checks on a real `/spec-flow:execute` session; operator-driven (see `## Live procedure` below).

No external runtime required. All checks are plain Bash.

## Invocation

### Default (L1 + L2 against committed fixtures)

```bash
bash plugins/spec-flow/tests/e2e/run-e2e.sh
```

### Audit a specific piece directory (L2 re-run)

```bash
bash plugins/spec-flow/tests/e2e/run-e2e.sh --audit <piece-dir>
```

`<piece-dir>` is the root of a completed piece worktree (must contain a `.git` directory and the standard contract artifacts).

### Verify after a live run

```bash
bash plugins/spec-flow/tests/e2e/run-e2e.sh --verify-live <target> [--transcript <jsonl>]
```

`<target>` is the piece worktree produced by a live `/spec-flow:execute` session. `--transcript <jsonl>` points to the Claude Code session transcript; if omitted, the harness attempts auto-discovery.

### Record a golden snapshot

```bash
bash plugins/spec-flow/tests/e2e/run-e2e.sh --record-golden <target> <transcript>
```

Writes `plugins/spec-flow/tests/e2e/golden/footprint.txt`. Commit this file to anchor the baseline.

### Break-variant tests (self-test only)

```bash
bash plugins/spec-flow/tests/e2e/run-e2e.sh --break <case>
```

Valid `<case>` values: `research-after-spec`, `no-test-data`, `no-spike-artifact`, `skip-transition`, `journal-survives`, `missing-learnings`.

Each case builds a fixture with the named invariant deliberately violated and asserts that the harness detects it.

### Core library self-test

```bash
bash plugins/spec-flow/tests/e2e/self/test-core.sh
```

Unit-tests the `lib/assert.sh` primitives (pass/fail/skip_cap/summary) and golden snapshot logic in isolation.

## Capabilities and SKIPPED semantics

The harness tracks three capability gates. When the pre-condition for a check is absent, the check is emitted as a `SKIPPED:` line — never a failure:

| Capability ID | Pre-condition | Skipped when |
|---|---|---|
| `live-run` | Golden snapshot recorded (`golden/footprint.txt` present) | No golden on file — run the live procedure |
| `transcript` | A `.jsonl` Claude Code transcript is available | No transcript found or provided |
| `metrics-artifact` | FR-010 metrics output present (`metrics.yaml` in piece dir) | FR-010 not yet shipped |

**Never-false-green rule:** a `SKIPPED` line is inert — it never contributes to the pass count. The summary counts `passed`, `failed`, and `skipped` independently. A run that contains only skips with zero failures still exits 0. A run that contains any failure exits non-zero regardless of skips.

**EXCLUDED lines:** lines beginning with `EXCLUDED — ` are informational exclusions emitted by the harness (e.g., ordering checks skipped post-squash-merge); they are not counted in any category.

## Live procedure (operator-driven)

The harness never invokes a model. The live procedure requires an operator to run the interactive session; the harness only verifies the artifacts that result from it.

1. Run `setup-live.sh` to prepare a scratch worktree:

   ```bash
   bash plugins/spec-flow/tests/e2e/setup-live.sh <dir>
   ```

2. Open an interactive Claude Code session inside `<dir>` and run `/spec-flow:execute`. Token cost is operator-chosen; the harness never invokes a model. Expect the spike phase to dispatch an Opus-tier agent per pipeline policy.

3. After the session completes, run `--verify-live` against the output:

   ```bash
   bash plugins/spec-flow/tests/e2e/run-e2e.sh --verify-live <dir>
   ```

4. If verification passes, record a golden snapshot:

   ```bash
   bash plugins/spec-flow/tests/e2e/run-e2e.sh --record-golden <dir> <transcript.jsonl>
   ```

5. Commit `plugins/spec-flow/tests/e2e/golden/footprint.txt` to anchor the new baseline.

## Re-record policy

Re-record the golden snapshot (`--record-golden`) after any change to the pipeline contract that alters observable output. Specifically:

- **L1 token list** — any change to recognised commit-subject prefixes or grammar rules
- **Commit-subject grammar** — any change to the expected subject format for any pipeline phase
- **Dispatch sequence** — any change to the order, count, or type of subagent dispatches
- **Artifact set** — any addition or removal from the required contract artifacts (`## files`)

The four sections in `golden/footprint.txt` are `## commit-subjects`, `## dispatch-sequence`, `## files`, and `## cksum`. Any drift in any section requires a re-record.

## What is NOT asserted

The following are intentionally out of scope for this harness:

- **Journal mid-run state** — the journal file is verified only at rest (after the run); partial-write correctness during execution is not checked here.
- **Metrics values** — gated behind `metrics-artifact` capability (FR-010 not yet shipped); the harness skips those checks until FR-010 lands.
- **Ordering on squashed masters** — commit ordering checks assume a linear history from the piece worktree; squashed merges into master are outside the scope of this harness.
- **CI wiring** — CI integration is deferred to pi-022-vsync-ci.
