# Deliberation — timestamp-hooks (small-change)

## Investigation Summary

**Resolved depth:** `lite`

This is a single decision-unit small-change: a new Claude Code plugin `timestamp-hooks`
that captures per-message send/receive timestamps, computes elapsed time, and keeps a
recent-history log, surfaced to the operator in a "standard date format for easily
visibility and formatted."

Phase B enumerated paths across five decision dimensions (surfacing channel, state store,
computation, date format, failure/no-op). Phase C was a no-op (single cluster) and recorded
single-cluster coherence. Phase D ran two adversarial lenses — `scope/simplicity` and
`risk` — and **both returned CONTESTED**. Phase E folded all five sub-challenges: four were
resolved by concrete recommendation revisions (cut `additionalContext`; switch JSONL → plain
formatted log line; add `stop_hook_active` re-entry guard; specify missing-start-timestamp
behavior; document the atomic-append bound). One product-intent question survived unresolved
and is recorded as `VOQ-1`.

## Viability Analysis

Decision unit: **the change** (add `timestamp-hooks` plugin). Paths evaluated per dimension.

### DU-1 — Surfacing channel

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| 1a `additionalContext` (inject timing into Claude's context every turn) | NON-VIABLE | Scope creep — makes Claude timing-aware (a different capability) at per-turn token cost; no AC requires it. The user requirement ("so can see") is an operator-visibility need, satisfied by 1b. | No | No AC behind it; adds per-turn token cost for a capability the requirement does not ask for. |
| 1b `systemMessage` (Stop hook surfaces elapsed to operator) | VIABLE | Directly satisfies "can see how long things are taking." Operator-facing, zero per-turn cost. | No | — |
| 1c history file (recent-message log) | VIABLE | Satisfies "last messages sent in history." | No | — |

### DU-2 — State store

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| 2a in-memory / env var | NON-VIABLE | UserPromptSubmit and Stop are separate hook process invocations; no shared memory survives between them. | No | Process isolation — start epoch written by one process is not visible to the other without a file. |
| 2b file-backed state (start epoch + recent-history log under `~/.claude/timestamp-hooks/`) | VIABLE | File survives across the two hook invocations. POSIX-bash + filesystem only — no runtime deps (charter-tools compliant). | No | — |

### DU-3 — Computation

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| 3a pure-bash epoch subtraction (`date +%s`) | VIABLE | No runtime dependency; portable on macOS/Linux. Satisfies charter-tools (POSIX bash only). | No | — |

### DU-4 — Date format

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| 4a ISO-8601 display | VIABLE | "Standard date format for easily visibility" — ISO-8601 is the standard. | No | — |
| 4b human duration (`Xm Ys`) for elapsed | VIABLE | "See how long things are taking" reads naturally as a human duration, not a raw second count. | No | — |

### DU-5 — Failure / no-op

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| 5a guarded reads, always exit 0 with valid JSON | VIABLE | A hook that errors or emits invalid JSON disrupts the session. Necessary baseline. **Note:** "always exit 0" is necessary but not sufficient — see Adversarial Review R1/R2 for the additional re-entry and missing-start branches that 5a alone did not cover. | No | — |

## Integration Check

Phase C was a **no-op** (single cluster). Single-cluster coherence holds: the composite path
`1b + 1c → 2b → 3a → 4a + 4b → 5a` is internally consistent — the file-backed store (2b)
feeds both the elapsed computation (3a, surfaced via 1b) and the recent-history log (1c),
formatted per 4a/4b, all behind the guarded-exit baseline (5a). After folding (see
Recommendation), 1a is dropped, and the history log format changes from JSONL to a plain
formatted line; the composition remains coherent under the revision.

## Adversarial Review

### Lens: `scope/simplicity` — CONTESTED → both points folded

1. **`additionalContext` (1a) is scope creep.** UPHELD. `systemMessage` (1b) already
   satisfies "can see"; injecting timing into Claude's context every turn is a different
   capability with a per-turn token cost and no AC. **Resolution: 1a cut** (folded into
   Recommendation; recorded in Answered by Investigation).
2. **JSONL history may be over-engineered.** UPHELD as stated. The requirement
   ("standard date format for easily visibility and formatted", "last messages sent in
   history") reads as a human-readable log; JSONL is a machine format needing an extra
   formatting step before human consumption. **Resolution: switch to a plain formatted log
   line** (e.g. `2026-06-13T19:01:32Z → 2026-06-13T19:02:14Z  elapsed: 0m 42s`), which
   directly satisfies "formatted for easily visibility" and is simpler. Folded into
   Recommendation. (The downstream product-intent question this raises — shared vs.
   per-session log — survives as `VOQ-1`.)

### Lens: `risk` — CONTESTED → all three points folded

1. **R1 — `stop_hook_active` unhandled (defect).** UPHELD. Stop hooks can re-enter;
   without an early-exit on `stop_hook_active == true`, `ts-stop.sh` writes duplicate
   history rows on re-entry. **Resolution: add an explicit early-exit branch** when
   `stop_hook_active` is true (exit 0, no append, no recompute). Folded into Recommendation.
2. **R2 — Missing-start-timestamp behavior unspecified.** UPHELD. When `Stop` fires with no
   start epoch (resumed session, hook added mid-session, start hook errored),
   `now − (empty)` silently computes `now − 0` ≈ a 56-year elapsed. **Resolution: guard the
   read** — when no valid start epoch exists, emit a "start unavailable" notice, skip the
   elapsed display, and skip the history append (do not surface nonsense). Folded into
   Recommendation.
3. **R3 — Concurrent history-file write race unstated.** UPHELD as an unstated assumption.
   A shared history file `>>`-appended by concurrent sessions relies on POSIX `O_APPEND`
   atomicity, which holds for single writes under `PIPE_BUF` (~4096 bytes). A single
   formatted log line is well under that bound, so the append is safe — but the design was
   silent on it. **Resolution: document the atomic-append bound explicitly** in the design
   (one append = one line, < PIPE_BUF) AND record the residual product question (shared vs.
   per-session log) as `VOQ-1`, since resolving the race does not resolve the product intent.
   Folded into Recommendation.

## Recommendation

**Composite path (revised after Phase D fold):** `1b + 1c → 2b → 3a → 4a + 4b → 5a+`

- **DU-1 Surfacing:** `systemMessage` (1b) surfaces elapsed time to the operator on Stop, plus
  a recent-history log file (1c). **`additionalContext` (1a) is CUT** — out of scope.
- **DU-2 State store:** File-backed under `~/.claude/timestamp-hooks/`. The **start epoch** is
  kept per-session keyed by `session_id`. The **recent-history log** is a shared rolling
  formatted log (pending `VOQ-1`; see below).
- **DU-3 Computation:** Pure-bash epoch subtraction (`date +%s`).
- **DU-4 Date / format:** Epoch storage; **ISO-8601 display**; **human duration (`Xm Ys`)** for
  elapsed. History rows are **plain formatted log lines**, not JSONL — e.g.
  `2026-06-13T19:01:32Z → 2026-06-13T19:02:14Z  elapsed: 0m 42s`.
- **DU-5 Failure / no-op (hardened — 5a+):** Guarded reads, always exit 0 with valid JSON,
  **plus**:
  - **`stop_hook_active` early-exit** (R1): if the Stop payload's `stop_hook_active` is true,
    exit 0 immediately — no recompute, no append.
  - **Missing-start guard** (R2): if no valid start epoch exists for the session, emit a
    "start unavailable" notice, skip elapsed display, and skip the history append. Never
    compute against an empty/zero start.
  - **Atomic-append bound** (R3): each history write is a single `>>` append of one line,
    guaranteed under `PIPE_BUF` (~4096 bytes), so concurrent appends are atomic and
    interleaving-safe. Document this bound in the design and keep log lines short.

**Plugin structure (unchanged from Phase C):**
- `hooks/ts-start.sh` (UserPromptSubmit) — capture epoch, write per-session start file.
- `hooks/ts-stop.sh` (Stop) — `stop_hook_active` early-exit → read start epoch (missing-start
  guard) → compute elapsed → append one formatted log line → emit `systemMessage`.
- `.claude-plugin/hooks.json`, `plugin.json`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`.

## Validated Open Questions

### VOQ-1 — Recent-history log: shared rolling log vs. per-session file?

The `risk` lens (R3) forced this into the open by raising the concurrent-write race. Resolving
the race (atomic-append bound) makes a **shared** rolling log *safe*, but does not resolve the
**product intent**: does the operator want one shared "recent messages" log across all
sessions (a single place to glance at recent activity), or a per-session log (clean isolation,
no cross-session interleaving, trivially race-free)? The user requirement ("last messages sent
in history") is ambiguous on this axis. The recommendation provisionally assumes a shared
rolling log; the brainstorm should surface this as the one open product question.

## Answered by Investigation

| Dimension | Disposition | Rationale |
|-----------|-------------|-----------|
| DU-1 `additionalContext` (1a) | Resolved (cut) | `scope/simplicity` lens: out of scope — `systemMessage` already satisfies "can see"; per-turn token cost with no AC. |
| DU-1/DU-4 history format (JSONL vs. plain log) | Resolved (plain log) | `scope/simplicity` lens: requirement reads as human-readable; plain formatted line directly satisfies "formatted for easily visibility" and is simpler. |
| DU-2 state store (in-memory vs. file) | Resolved (file-backed) | Hook process isolation — start epoch must persist across the two separate hook invocations via a file. |
| DU-3 computation | Resolved (pure-bash) | `date +%s` subtraction; no runtime dependency (charter-tools: POSIX bash only). |
| DU-4 date display + elapsed format | Resolved (ISO-8601 + `Xm Ys`) | "Standard date format" = ISO-8601; "how long things are taking" = human duration. |
| DU-5 R1 `stop_hook_active` re-entry | Resolved (early-exit branch) | `risk` lens: prevents duplicate history rows on Stop-hook re-entry. |
| DU-5 R2 missing-start-timestamp | Resolved (guard: notice + skip) | `risk` lens: prevents `now − 0` ≈ 56-year nonsense from reaching the operator. |
| DU-5 R3 concurrent write race | Resolved (atomic-append bound documented) | `risk` lens: single `>>` append of one line < PIPE_BUF is atomic; documented. Residual product axis → VOQ-1. |
