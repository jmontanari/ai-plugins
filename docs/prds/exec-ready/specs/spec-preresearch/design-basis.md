# Design Basis — spec-preresearch (Investigation-First Design Protocol / "Spec 2.0")

> Durable provenance for this piece. Answers the research question the operator posed at the
> start: **"Reference Boris Cherny and other top agentic developers — what are they doing to
> build solid specs with minimal human involvement?"** Records (1) the operator concerns that
> motivated the piece, (2) the verified industry research, (3) how each pattern maps to this
> piece's design, and (4) the decisions/corrections — including a fabricated statistic the
> original design discussion propagated.
>
> All web sources re-verified 2026-06-08.

---

## Part 1 — Operator concerns (the problem statement, in the operator's framing)

1. **Out-of-thin-air questions.** "A good amount of the time the questions asked are not viable or
   even explored — just out-of-thin-air questions that, when challenged, come back with no
   rational." Questions are generated speculatively, before investigation.
2. **Research and spec are not integrated.** Codebase facts and the user-facing Socratic dialogue
   are disconnected; the AI asks before it investigates.
3. **The fix must be enforcement, not suggestion.** "How do we *enforce* the spec so they are
   grounded before I even get involved?" Every question must trace to a finding.
4. **Explore ALL paths, not a pre-capped 2–3.** "I don't want to narrow scope to 2–3 candidate
   approaches. We should explore all options and paths and figure out viability."
5. **Reuse before greenfield.** "Look at existing code for patterns that can be used or
   re-purposed." Reuse/extend-existing must be a first-class candidate path.
6. **Per-requirement thinking, then whole-system integration.** "Do a thinking exercise for each
   functional requirement … and then all the functional requirements together — do the pieces
   work together?"
7. **Adversarial review of the design itself.** "Our review-board-type action might be good here
   to punch holes in the spec, plan, charter."
8. **This is the end state, not a V1.** "Not a V1 — design out Spec 2.0 that incorporates all the
   best ideas we found." Apply the same protocol to spec, prd, small-change, and charter.
9. **Cost is acceptable where it belongs.** Spec/prd time is exactly where deep investigation is
   rational — "but maybe not at full depth every time" → a complexity gate that scales depth.

These nine are the bar this piece is measured against.

---

## Part 2 — The macro shift: Spec-Driven Development (SDD)

By 2026, the industry answer to "minimal human involvement" is **not** "the AI specs itself" — it
is **front-load all human judgment into a solid, durable specification, then let agents regenerate
code from it.** The spec becomes the primary executable artifact; code becomes regenerable output.

- **Sean Grove (OpenAI), "The New Code"** (AI Engineer World's Fair 2025): coding is only ~10–20%
  of the work; ~80% is **structured communication**, which is where value (and human effort)
  actually lives. Specifications replace ad-hoc prompting as the primary artifact. OpenAI's own
  **Model Spec** is a set of versioned, change-logged markdown files that non-engineers (product,
  legal, safety, policy) can read and contribute to. Closing advice: *"Start with the
  specification"* — state the goal, assumptions, constraints, and example inputs/outputs.
- **SDD as a movement**: a direct response to "vibe coding" drift (plausible code that diverges
  from intent, hallucinates APIs, decays at scale). Early adopters report **~3–10× higher
  first-pass success** from agents when a structured spec drives the work.

**Implication for this piece:** the leverage on "minimal human involvement" comes from making the
*spec phase* both **thorough** (so execution rarely needs the human) and **cheap to reach** (so the
human iterates less to get there). This piece attacks the second half — getting to a solid spec
with fewer, better questions.

**Sources:** [Sean Grove — The New Code (summary)](https://www.darekm101.com/articles/the-new-code-sean-grove-openai) · [Implicator — Specs as the new source code](https://www.implicator.ai/the-end-of-coding-how-specifications-are-becoming-the-new-source-code/) · [SDD: The Definitive 2026 Guide (BCMS)](https://thebcms.com/blog/spec-driven-development) · [Martin Fowler — Understanding SDD (Kiro, spec-kit, Tessl)](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)

---

## Part 3 — What the top agentic developers / tools actually do

### 3.1 Boris Cherny (creator of Claude Code) — plan-mode-first, "minimal to get on track"

- Starts **~80% of sessions in plan mode** (Shift+Tab twice → think/analyze, no code). Once the
  plan looks solid, tell Claude to execute; with Opus 4.5+, "once the plan is solid the model stays
  on track almost every time."
- Philosophy of **minimal intervention**: "do the minimal possible thing to get the model on
  track." Delete CLAUDE.md, add instructions back one at a time only when the model drifts; newer
  models need fewer.
- **Proof of the payoff**: the Claude Code *plugins* feature was built by a **swarm of agents over
  a weekend with minimal human intervention** — an engineer gave Claude a spec, pointed it at an
  Asana board, and Claude created tickets, spawned agents, and the agents executed independently.
  Minimal human involvement was a *consequence of a solid upfront spec*, not of removing the human
  from design.

**Sources:** [How the Creator of Claude Code Actually Uses Claude Code (Push to Prod)](https://getpushtoprod.substack.com/p/how-the-creator-of-claude-code-actually) · [10 Claude Code Tips from Boris Cherny (Feb 2026)](https://www.jitendrazaa.com/blog/others/tips/10-claude-code-tips-from-the-creator-boris-cherny-february/)

### 3.2 Harper Reed — "idea honing": one question at a time toward a thorough spec

- Phase 1 **Idea Honing**: a conversational model is told *"Ask me one question at a time so we can
  develop a thorough, step-by-step spec for this idea,"* each question building on the last. Phase
  2 **Planning**: hand the spec to a reasoning model for `prompt_plan.md` + `todo.md`. Phase 3
  **Execution** in discrete loops.
- **This piece evolves Harper's pattern**: rather than asking questions one-at-a-time to *discover*
  the spec, it investigates first and asks only the questions investigation could not resolve —
  "one question at a time" becomes "only the *validated* questions, each traceable to a finding."

**Source:** [Harper Reed — My LLM codegen workflow atm](https://harper.blog/2025/02/16/my-llm-codegen-workflow-atm/)

### 3.3 Andrej Karpathy — "LLM Council": multi-model generate → blind peer review → chairman synthesis

- 3 stages: (1) query goes to **multiple different models in parallel** (GPT, Claude, Gemini, Grok)
  for independent answers; (2) **blind peer review** — models rank each other anonymously to reduce
  bias; (3) a **"Chairman" model** merges answers + reviews into one consensus. Reliability comes
  from **separating generation / critique / decision** and from **model diversity** ("when frontier
  models disagree, you pause; when they converge, you have a stronger foundation").
- This piece adopts the *structure* (parallel independent review → synthesis) but **diverges on
  model diversity** — see Part 5, Decision D-1.

**Sources:** [Analytics Vidhya — Karpathy's LLM Council](https://www.analyticsvidhya.com/blog/2025/12/llm-council-by-andrej-karpathy/) · [VirtusLab — llm-council deep dive](https://virtuslab.com/blog/ai/llm-council)

### 3.4 Addy Osmani — the spec is the bottleneck; questions emerge from exploration

- Thesis (O'Reilly Radar, backed by GitHub's analysis of 2,500+ agent-config files): *"The AI is
  not the bottleneck — your specification is."* Specs are living, executable source-of-truth.
- **Questions emerge during exploration, not before it**: Plan Mode keeps the agent read-only so it
  drafts a spec *while exploring the existing code*, surfacing what it needs as it goes.
- This is the direct basis for the core invariant: **questions are findings of investigation, not
  inputs to it.**

**Sources:** [Addy Osmani — How to write a good spec for AI agents (O'Reilly Radar)](https://www.oreilly.com/radar/how-to-write-a-good-spec-for-ai-agents/) · [addyosmani.com — Good spec](https://addyosmani.com/blog/good-spec/)

### 3.5 AWS Kiro + EARS notation — structured, testable, unambiguous requirements

- Kiro (agentic IDE, launched 2025-07-14) requires **three sequential documents before any code**:
  `requirements.md` → `design.md` → `tasks.md`.
- `requirements.md` is written in **EARS** (Easy Approach to Requirements Syntax, from Rolls-Royce):
  the `WHEN [event/condition] THE SYSTEM SHALL [response]` pattern. EARS forces testability and
  **eliminates ambiguous words** ("should", "may", "appropriate") — the exact "no rational"
  vagueness the operator is fighting. It is deliberately both human-readable and machine-parseable.
- **Alignment**: spec-flow already uses Given/When/Then acceptance criteria — a close cousin of
  EARS. The deliberation protocol's VIABLE/NON-VIABLE-with-explicit-reasoning verdicts apply the
  same "no unjustified claims" discipline to *design paths*, not just ACs.

**Sources:** [Kiro — Feature Specs docs](https://kiro.dev/docs/specs/feature-specs/) · [EARS Format Complete Guide (Kiro Directory)](https://kiro.directory/tips/ears-format)

### 3.6 GitHub Spec Kit & Tessl — spec as the maintained source of truth

- **GitHub Spec Kit** (open-source, model-agnostic, 90k+ stars): structures agent workflows around
  the spec as the central source of truth.
- **Tessl**: pushes "spec-as-source" furthest — the spec is the primary maintained artifact, code
  is generated from it; ships audit trails for regulated industries.

**Sources:** [Tessl — A look at GitHub Spec Kit](https://tessl.io/blog/a-look-at-spec-kit-githubs-spec-driven-software-development-toolkit/) · [Augment Code — Best SDD tools 2026](https://www.augmentcode.com/tools/best-spec-driven-development-tools)

### 3.7 SCoT (structured reasoning) — segregate structuring from generation

- Li et al., 2023. Verified result: SCoT beats ordinary CoT by **up to 13.79% Pass@1** on code
  generation (HumanEval w/ ChatGPT, 53.29% → 60.64%) — a **correctness** metric. Mechanism: build
  explicit structure *before* generating. Transferable principle: **segregating comprehension/
  structuring from generation improves output** — applied here as the phase ordering (read →
  analyze → only then generate questions).

**Source:** [Li et al. 2023 — Structured Chain-of-Thought Prompting (arXiv:2305.06599)](https://arxiv.org/abs/2305.06599)

---

## Part 4 — How each pattern maps to this piece's design

| Industry pattern | This piece's design element |
|---|---|
| Cherny: plan-mode-first; solid plan → autonomous execution; minimal intervention | Investigation-first protocol front-loads design judgment into `deliberation.md` before any question |
| Sean Grove / SDD: spec is the primary artifact; front-load structured communication | `deliberation.md` + spec as durable, reviewed source of truth; plan consumes the recommendation |
| Harper Reed: one question at a time toward a thorough spec | Brainstorm draws only from §Validated Open Questions, in order — evolved so each question traces to a finding |
| Karpathy Council: parallel independent review → synthesis; separate generate/critique/decide | Phase D multi-lens adversarial board (parallel) → Phase E convergence synthesizes verdicts |
| Osmani: spec is the bottleneck; questions emerge from exploration | Core invariant — every user question must trace to a `deliberation.md` finding |
| Kiro/EARS: structured, testable, ambiguity-eliminating requirements | VIABLE/NON-VIABLE verdicts require explicit reasoning + concrete blocker; no "seems hard" |
| SCoT: segregate structuring from generation | 5-phase ordering; questions emitted only at convergence |

---

## Part 5 — Decisions, divergences, and one correction

### D-1 — Multi-lens (single-model) board, NOT a multi-model council. **Deliberate.**

Karpathy's Council derives diversity from **different models**; this piece's Phase D board runs
**five lenses on Opus**. Rationale: **NN-P-005 mandates Opus for all thinking tasks**, and
adversarial review is a thinking task — a true multi-model council would require non-Opus thinking,
a charter violation. The targeted failure modes (architecture drift, scope creep, missed intent,
backward-compat breakage, unseen risk) are **dimension-specific**, so lens diversity covers them
more directly than model diversity would. This converts what was a *silent substitution* in the
original discussion into a *recorded, charter-grounded decision*. True multi-model council remains
a future option if a charter carve-out for non-thinking "cross-check" review is ever added.

### D-2 — Adversarial board reviews the *design recommendation*, not the finished spec/plan/charter.

The operator asked to "punch holes in the spec, plan, charter." Those already have dedicated gates
(qa-spec, qa-plan, qa-charter, Final Review board). Phase D is placed **upstream** — it punches
holes in the deliberation *recommendation* before it hardens into a spec — catching flaws at the
cheapest point. Deliberate placement, not a miss.

### C-1 — Correction: the "16.8% faithfulness" figure is **fabricated** and has been removed.

The original design discussion cited a "16.8% faithfulness improvement" for structured reasoning
**22 times** across the session transcript. Web verification (2026-06-08) found **no such figure**.
The real, paper-supported SCoT result is **13.79% Pass@1** (a correctness metric, not faithfulness).
Only the verified principle is retained. This correction is itself an instance of the exact failure
mode — a confident, unsourced claim that collapses under challenge — that this piece exists to
eliminate.

---

## Part 7 — Second-tier validation: the answer-validation loop (Tier 2)

Tier 1 (Parts 1–5) investigates *before* asking, so the questions are grounded. Tier 2 closes
the complementary gap: **the operator's own free-form answers are themselves ungrounded design
assertions that Tier 1 never evaluated.** The Phase D board adversarially reviews the AI's
recommendation, but a typed human answer was, until Tier 2, accepted into the spec with no
scrutiny at all. That asymmetry contradicts the piece's own premise ("no ungrounded design choice
reaches the spec"). Tier 2 makes grounding **bidirectional**.

### Research basis (verified 2026-06-08)

- **Human-in-the-loop iterative refinement is the established shape.** LLM requirement-engineering
  systems (AISD, MARE) wrap generation in a *reformulation/validation loop* that gives each
  human-supplied requirement "explicit validation," explicitly to **intercept ungrounded
  assertions before they propagate** into the spec. The successful pattern is human-as-co-creator
  in a tight iterate→validate→refine loop, not one-shot Q&A.
  Sources: [SMU — LLM multi-agent systems for SE](https://ink.library.smu.edu.sg/cgi/viewcontent.cgi?article=11489&context=sis_research) · [arXiv — LLMs in UI/UX (SLR)](https://arxiv.org/pdf/2507.04469)
- **Addy Osmani's loop is explicitly iterative** — "instruct → verify → refine," not write-once
  (Part 3.4). Tier 2 is the verify/refine half applied to the operator's inputs.

### Reuse anchor (codebase, not greenfield)

The merged `spike-agent` piece already implements the needed mechanism as the spike agent's
**`scope` mode** (`plugins/spec-flow/agents/spike.md`): given a change + current plan, it
determines blast-radius, classifies the change, and writes a scoped artifact. Tier 2 is that exact
pattern **relocated from execute-time to brainstorm-time** and pointed at a typed answer instead of
a code change. New narrow agent `deliberation-validate.md` mirrors the spike-scope contract.

### Decisions (operator-confirmed 2026-06-08)

- **D-3 Detection gate:** the calling skill classifies a free-form answer *inline* against the
  deliberation's evaluated path-set + §Answered-by-Investigation. A path in neither = a new
  assertion → auto-fire validation. The trigger is itself artifact-traceable (no opaque classifier).
- **D-4 Auto-fire:** a detected new assertion validates automatically (no "want me to check?" prompt).
- **D-5 Lite, scoped:** validation is scoped to the single assertion — viability + scope/risk
  lenses + prior-art (web + codebase) — not a re-run of the full 5-phase protocol.
- **D-6 Two-tier verdict:** a flag is **hard** (charter/non-negotiable violation → operator must
  revise; no override — honors NN-P-001 and the binding NN-C set) or **soft** (risk/scope/complexity
  → operator may override; the override is recorded with rationale in `deliberation.md`).
- **D-7 Human-paced termination:** the loop ends when the operator introduces no new assertions and
  signs off. No artificial round cap; the human is always the terminating authority.
- **D-8 One piece:** Tier 1 + Tier 2 ship as a single piece (`spec-preresearch`). Rationale: the
  full effort touches a small file set (the deliberation agents + `deliberation-validate.md` +
  `brainstorm-procedure.md` + the four skill wirings); many FRs, one focused surface. Accepts an
  AC count above the ≤7 granularity guideline as a deliberate, operator-made tradeoff.

---

## Part 8 — Sources (consolidated)

- Sean Grove / SDD movement — [The New Code (summary)](https://www.darekm101.com/articles/the-new-code-sean-grove-openai) · [Implicator](https://www.implicator.ai/the-end-of-coding-how-specifications-are-becoming-the-new-source-code/) · [SDD 2026 Guide (BCMS)](https://thebcms.com/blog/spec-driven-development) · [Martin Fowler — SDD tools](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- Boris Cherny — [Push to Prod](https://getpushtoprod.substack.com/p/how-the-creator-of-claude-code-actually) · [10 Tips (Feb 2026)](https://www.jitendrazaa.com/blog/others/tips/10-claude-code-tips-from-the-creator-boris-cherny-february/)
- Harper Reed — [My LLM codegen workflow atm](https://harper.blog/2025/02/16/my-llm-codegen-workflow-atm/)
- Andrej Karpathy LLM Council — [Analytics Vidhya](https://www.analyticsvidhya.com/blog/2025/12/llm-council-by-andrej-karpathy/) · [VirtusLab](https://virtuslab.com/blog/ai/llm-council)
- Addy Osmani — [O'Reilly Radar](https://www.oreilly.com/radar/how-to-write-a-good-spec-for-ai-agents/) · [addyosmani.com](https://addyosmani.com/blog/good-spec/)
- AWS Kiro / EARS — [Kiro Feature Specs](https://kiro.dev/docs/specs/feature-specs/) · [EARS Format Guide](https://kiro.directory/tips/ears-format)
- GitHub Spec Kit / Tessl — [Tessl on Spec Kit](https://tessl.io/blog/a-look-at-spec-kit-githubs-spec-driven-software-development-toolkit/) · [Augment Code — Best SDD tools](https://www.augmentcode.com/tools/best-spec-driven-development-tools)
- SCoT — [Li et al. 2023, arXiv:2305.06599](https://arxiv.org/abs/2305.06599)
- HITL iterative refinement (Tier 2) — [SMU — LLM multi-agent systems for SE](https://ink.library.smu.edu.sg/cgi/viewcontent.cgi?article=11489&context=sis_research) · [arXiv — LLMs in UI/UX (SLR)](https://arxiv.org/pdf/2507.04469)
