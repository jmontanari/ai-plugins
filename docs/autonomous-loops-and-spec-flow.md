# Autonomous Loops + Spec-Flow: How to Drive Feature-After-Feature Without Blowing Out Context

> Research notes synthesizing Boris Cherny's "write loops, not prompts" workflow with the
> `spec-flow` pipeline. Purpose: figure out how to extend/implement autonomous, long-running
> feature delivery while keeping human judgment exactly where it belongs.

---

## Part 1 — The "write loops, not prompts" idea

Boris Cherny (Claude Code creator), 2026 dev conference:
> *"I don't prompt Claude anymore. I have loops running that prompt Claude and figuring out
> what to do. My job is to write loops."*

The part people miss is **what makes a loop work**. It is not "run Claude on repeat." His principles:

- **A workflow graph** — explicit steps, dependencies, retries, and **stop conditions**
- **Typed I/O** — every agent call has a schema, not free text in / free text out
- **Evaluator gates** — the loop advances only when *checks pass*, not when the *model says it's done*
- **A supervision layer** — a coordinator decides what runs next, instead of the LLM silently
  mutating its own mission forever

### You already built that workflow graph — it's spec-flow

| Boris's principle                         | spec-flow implementation                                            |
|-------------------------------------------|--------------------------------------------------------------------|
| Workflow graph w/ deps + stop conditions  | `manifest.yaml` (pieces, dependencies, `status:` field)            |
| Explicit steps                            | `plan.md` phases with `- [ ]` / `- [x]` checkboxes                  |
| Evaluator gates                           | QA gates + the 8–9 agent final review board                        |
| Typed I/O                                 | schema-validated structured outputs from QA / review agents        |
| Supervision / isolation                   | `execute` dispatches sub-agents — *the main window writes zero code* |

The loop's logic doesn't need inventing. **The loop's logic is "advance the manifest."**

---

## Part 2 — The context problem (and why spec-flow mostly solves it)

**Critical mechanical fact:** `/loop` does **not** reset context between iterations. It's one
session; the transcript accumulates; eventually auto-compaction kicks in and then *thrashes*. A
naive `/loop "build the next feature"` blows out main context after a few pieces. This is the trap.

Three things keep context bounded — spec-flow gives all three for free:

1. **State lives on disk, not in the window.** The manifest `status:` field and plan checkboxes
   ARE the memory. A fresh context reads them and knows exactly where the pipeline is. The
   transcript is disposable.
2. **`execute` already fans work out to sub-agents.** Each gets its own fresh ~200K window, reads
   dozens of files, and returns a one-paragraph conclusion. The token bulk never touches the main thread.
3. **The natural unit of context is one piece.** A whole PRD won't fit in one window even with
   delegation — but one piece (spec → plan → execute → review) comfortably does.

**The rule that follows:** the driver loop's only job is orchestration. Every unit of real work
runs in an isolated context, and the loop re-reads the manifest from disk at the top of every
iteration so it never relies on remembering anything.

---

## Part 3 — Three architectures for "finish the whole product" unattended

**A. `/schedule` (remote cloud routines) — best for true unattended, multi-day.**
Each scheduled run is a **brand-new cloud session = fresh context every run**, and it survives the
laptop being closed. A cron routine like *"Run `/spec-flow:status`. Take the next actionable piece.
Drive it one stage forward. Commit. Stop."* gives a clean context per piece by construction — the
context problem disappears because you never accumulate. Tradeoff: cloud runs may not reach
interactively-authenticated MCP servers; you review results after the fact.

**B. Self-paced `/loop` that delegates each piece wholesale to a sub-agent — best for supervising live.**
`/loop` with no interval lets the model self-pace (via the `ScheduleWakeup` tool, 1 min–1 hr between
iterations). Discipline that keeps context flat: each iteration the **main thread does almost
nothing** — read status, dispatch *one* sub-agent (or `Workflow`) for an entire bounded chunk,
record the one-line result, schedule the next wake. Heavy context lives and dies inside the
sub-agent. Tradeoff: still one session, so periodically `/clear` and restart the driver (it just
re-reads the manifest and continues).

**C. `Workflow` (ultracode) — best for parallel fan-out, not serial pipelines.**
A JS orchestration script holds intermediate results in *script variables* (not context) and spawns
up to 16 concurrent agents. Right for *wide* work ("audit all N pieces", "review board across every
open piece"), not the inherently serial spec→plan→execute chain of one piece.

**Recommendation:** A as the engine, B when you want to watch. Scheduled routines for the grind;
drop into a self-paced `/loop` session to supervise live.

---

## Part 4 — The hard part: spec & plan need human iteration. How does Boris handle it?

Honest headline: **Boris does NOT loop the spec and plan. He loops execution.** The human iteration
on spec/research is the gate he *deliberately keeps a human on*.

### The asymmetry that decides what can be looped

A loop can only run unattended if it has an **objective check** to advance on.

- **Execution is verifiable** — tests pass, QA gates pass, review board signs off. A machine can
  decide "done." → loopable.
- **A spec is not verifiable against intent** — there's no test for "is this the *right* thing to
  build, scoped the *right* way." Only the human has that signal. → not loopable.

### What Boris actually does: pay the judgment cost once, then crystallize it

Three phases — notice where the human lives:

1. **Research** — a session whose only job is to come out with a complete picture: read files,
   grep, call MCPs, **no implementation**. Front-loads the unknowns.
2. **Plan** — Claude writes `spec.md` / `design.md` / `tasks.md` to the repo. **The human reviews
   each. "Important decisions get written down rather than held in the agent's head."** This is the
   iteration you feel — and he treats it as the high-value work. For any change touching 3+ files,
   plan mode is *non-negotiable*.
3. **Implement** — a **fresh, clean context** receives the markdown and does nothing but execute,
   updating `tasks.md` as it goes.

The messy research/Q&A happens **once, with you**, frozen into durable files. The loop never
re-derives it. **This is exactly spec-flow** (`spec.md` + `plan.md` + human sign-off = Boris's
phases 1–2). The spec/plan iteration is the system working as designed, not failing.

### How he makes that human iteration cheaper and rarer — not zero

1. **Plan files are editable on disk, synced back to context.** From his own post: *"Claude now
   writes plan files to your filesystem… edit them… changes sync back… so you can tailor Claude's
   plan to your exact requirements if it's not perfect."* Tuning a plan = **editing markdown**, not
   re-prompting. Far less context churn and drift.
2. **Parallelism pipelines *your* attention.** 5 Claudes in 5 checkouts + 5–10 browser sessions,
   20–30 PRs/day. While one Claude *executes* a locked plan, he *iterates the spec of the next
   piece* in another tab. Human judgment overlaps autonomous execution instead of blocking it.
3. **Review is meta-work that makes the next spec start better.** When review catches something, he
   tags `@claude` to **fold the learning into CLAUDE.md**. Every recurring spec miss becomes a
   written rule → the *next* spec needs fewer rounds.
4. **Give the work a self-check.** Letting the agent verify itself (tests, browser, bash) improves
   quality "2–3x." That's why execution loops safely — and why spec/plan can't (no equivalent
   self-check for "right thing to build").

### Mapping to spec-flow (you're ahead of his hand-rolled setup)

- **Adversarial pre-human loop already exists.** `qa-spec` and `qa-plan` agents critique the spec
  *before it reaches you* — a machine loop tightening quality, narrowing what you catch by hand.
  Lean on them harder; that *is* the loop for spec quality.
- **Pre-answer research before the Q&A.** Run a research sub-agent (or `deep-research`) to gather
  facts and *propose* answers to open `NEEDS CLARIFICATION` questions. Arrive at the gate choosing
  between drafted options instead of blank — fewer rounds.
- **Write decisions where they compound.** The `charter-*` NN-C rules are Boris's "decisions
  written down." Promote recurring spec-iteration resolutions to the charter (e.g. NN-C-015).
  Permanently reduces future iterations.
- **Batch the gates, loop only execute.** Do spec+plan for several pieces in a focused human
  session (qa-spec/qa-plan doing the heavy critique), approve them, then let an unattended loop
  grind `execute` across the locked backlog. Human attention concentrates at the front; autonomy
  takes the back.

---

## Part 5 — The one real blocker: human sign-off gates

spec-flow's `spec` and `plan` skills **require human sign-off**. Fully unattended
"spec→plan→execute on a brand-new piece" needs something to stand in for approval. Two clean options:

- **Constrain the loop to `execute` only.** A backlog of pieces already past the gates is safe to
  run unattended *today*, no gate changes needed. Start here.
- **Batch the gates.** Let the loop run spec+plan on several pieces, then stop and hand them all to
  you to approve in one sitting; after approval, let it execute the lot.

---

## Part 6 — A concrete driver to start from (safe path: execute already-planned work)

```
Read /spec-flow:status (re-read every iteration; trust the manifest, not memory).
Pick the highest-priority piece whose status is `planned` and whose
dependencies are all `done`.
If none exists, report "no executable work" and stop the loop.
Otherwise: cd into its worktree and run /spec-flow:execute to completion
(it will fan out to sub-agents and run its own QA + review board).
When the piece reaches `done`, commit on its branch. Do NOT push.
Then schedule the next iteration.
```

Run as `/loop <that prompt>` (self-paced, option B), or paste as the prompt of a daily `/schedule`
routine (option A).

---

## Bottom line

"I write loops, not prompts" is true for **execution** and misleading if read as "the AI specs
itself." Boris's leverage on the spec/plan side comes from **front-loading research into a dedicated
phase, freezing decisions into files, pipelining his own attention across parallel checkouts, and
feeding review learnings back so specs start stronger** — not from removing himself from design
judgment. The realistic target is not "zero spec iterations." It's: make each spec iteration
**cheaper** (edit files, not re-prompt), **rarer** (better charter priors + adversarial QA before
you), and **overlapped** (spec piece N+1 while the loop executes piece N).

---

## Primitives available in this Claude Code install

Verified live (not speculative):
- `/loop` skill — self-paced or fixed-interval
- `/schedule` skill — remote cloud cron routines
- `ScheduleWakeup` tool — dynamic-pacing for self-paced `/loop`
- `CronCreate` / `CronList` / `CronDelete` — fixed-interval scheduling
- `Agent` tool — sub-agents, `isolation: worktree`
- `Workflow` tool — ultracode multi-agent orchestration
- spec-flow skills — `intake`, `status`, `spec`, `plan`, `execute`, plus qa-* / review-board agents

Could **not** confirm in this version (treat as unverified): a `/goal` command; a customizable
`.claude/loop.md`. Build on the confirmed primitives above.

---

## Sources

- Boris Cherny — stopped prompting, now writes autonomous loops: https://digg.com/ai/q0idpj2w
- How Boris Cherny Uses Claude Code (research/plan/implement): https://karozieminski.substack.com/p/boris-cherny-claude-code-workflow
- Building Claude Code with Boris Cherny (5 checkouts, plan-mode-first, review as meta-work): https://newsletter.pragmaticengineer.com/p/building-claude-code-with-boris-cherny
- Boris Cherny — plan files written to filesystem, editable, synced back (Threads): https://www.threads.com/@boris_cherny/post/DRgyCN5jjYA/claude-now-writes-plan-files-to-your-filesystem-and-you-can-edit-them-by
- How the agent loop works (Claude Code Docs): https://code.claude.com/docs/en/agent-sdk/agent-loop
- Claude Code autonomous loops — ship features while you sleep: https://claudefa.st/blog/guide/mechanics/autonomous-agent-loops
- Boris Cherny's workflow — system-level practices (Reading List): https://reading.torqsoftware.com/notes/software/ai-ml/agentic-coding/2026-01-11-boris-cherny-claude-code-workflow-system/
- The creator of Claude Code reveals his workflow (VentureBeat): https://venturebeat.com/technology/the-creator-of-claude-code-just-revealed-his-workflow-and-developers-are
