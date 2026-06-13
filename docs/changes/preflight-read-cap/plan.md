---
slug: preflight-read-cap
tdd: false
fast: false
status: done
---

# Plan: preflight-read-cap — Cap execute pre-flight to bounded probes

One Implement-track phase. The change is prose (a guardrail in the execute
SKILL.md) plus version metadata. There is no behavior-bearing code and no test
surface, so TDD does not apply — track is **Implement** with a grep-based
`[Verify]`.

All paths are relative to the worktree root
`worktrees/preflight-read-cap/` unless absolute.

## Phase 1: Probe-budget guardrail + version bump  [x] [Implement]

**Scope:**
- `plugins/spec-flow/skills/execute/SKILL.md`
- `plugins/spec-flow/plugin.json`
- `plugins/spec-flow/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `plugins/spec-flow/CHANGELOG.md`

### Edit 1 — Step 1b Probe budget guardrail (AC-1, AC-2)

In `plugins/spec-flow/skills/execute/SKILL.md`, locate the `### Step 1b: Phase
Pre-Flight (read-only)` heading and its intro paragraph that ends
"…use path filters targeting scope directories or skip it." Immediately AFTER
that intro paragraph and BEFORE the numbered item `1. **LOC snapshot**`, insert
this new bolded guardrail block verbatim:

```markdown
**Probe budget (read discipline).** Pre-flight is a *bounded-probe* step, not a
code-reading step. Scoped to the phase's declared files/symbols, the coordinator
MAY use only these read forms:

- `wc -l <file>` — line counts.
- `head -N <file>` / `tail -N <file>` — a **bounded** sample only (the item-2
  schema probe is the canonical use; keep N ≤ ~20).
- `git grep -l` / `git grep -n` / `grep -n` — match **paths and line numbers**,
  never whole-file bodies.
- Reading the small structured config/doc files the items below already name:
  `.pre-commit-config.yaml` (item 4) and `introspection.md` (item 8), plus
  `plan.md` and `spec.md`.

The coordinator MUST NOT `Read` full source or test file bodies during
pre-flight to discover a signature, constructor shape, or usage example. That
work belongs to the implementer — it reads the files it edits — and any signature
the implementer genuinely needs up front belongs in the plan's Change
Specification Block, not a coordinator file-body read. Reading file bodies into
the coordinator's long-lived context is the same defect the **Coordinator Return
Discipline** (above) forbids for agent returns: raw file bodies live on disk and
are referenced by path, never pasted into the coordinator's context.
```

Do not alter probe items 1–8 themselves (AC-6).

### Edit 2 — Orchestrator Role bullet (AC-3)

In the same file, in the `## The Orchestrator Role` section, replace the
existing sentence:

> You write ZERO implementation code. Fact-gathering probes (`wc`, `head`, `git grep`, reading `.pre-commit-config.yaml`) are explicitly part of the conductor role — they are cheap reads that collapse 5–15 agent tool calls per dispatch. Synthesis and code-writing still come from subagents.

with:

> You write ZERO implementation code. Fact-gathering probes (`wc -l`, bounded `head -N`, `git grep -l`/`-n` for paths and line numbers, and reading small structured config/doc files like `.pre-commit-config.yaml`) are explicitly part of the conductor role — they are cheap reads that collapse 5–15 agent tool calls per dispatch. This is a **bounded-probe budget, not a license to read source**: the coordinator MUST NOT `Read` full source or test file bodies to discover signatures or usage — that is the implementer's job, and any signature it needs belongs in the plan. See Step 1b → **Probe budget** for the binding enumeration. Synthesis and code-writing still come from subagents.

### Edit 3 — Version bump to 5.19.0 (AC-4)

Set `"version": "5.19.0"` (from `5.18.0`) in each of:
- `plugins/spec-flow/plugin.json`
- `plugins/spec-flow/.claude-plugin/plugin.json`
- the spec-flow entry in `.claude-plugin/marketplace.json`
  (the object with `"name": "spec-flow"`).

### Edit 4 — CHANGELOG entry (AC-5)

In `plugins/spec-flow/CHANGELOG.md`, directly below the `## [Unreleased]` line,
insert a new section:

```markdown
## [5.19.0] — 2026-06-13

### Changed
- **Execute pre-flight probe budget.** Step 1b ("Phase Pre-Flight") and the
  Orchestrator Role section now explicitly cap the coordinator to bounded probes
  (`wc -l`, bounded `head -N`, `git grep -l`/`-n`, and small structured
  config/doc files) and forbid reading full source/test file bodies into the
  coordinator's long-lived context to discover signatures or usage. Signatures
  the implementer needs up front belong in the plan's Change Specification Block.
  This extends the existing Coordinator Return Discipline (which already barred
  raw file bodies in agent *returns*) to pre-flight *reads*, keeping the
  orchestrator lean over long pieces. No change to probe items 1–8, plan format,
  or config keys.
```

[Verify]
```bash
cd /Volumes/joeData/ai-plugins/worktrees/preflight-read-cap
# AC-1/AC-2: guardrail present in Step 1b
grep -q "Probe budget (read discipline)" plugins/spec-flow/skills/execute/SKILL.md \
  && grep -q "MUST NOT .Read. full source or test file bodies during" plugins/spec-flow/skills/execute/SKILL.md \
  && echo "AC-1/2 OK"
# AC-3: orchestrator-role bullet names the cap + cross-ref
grep -q "bounded-probe budget, not a license to read source" plugins/spec-flow/skills/execute/SKILL.md \
  && echo "AC-3 OK"
# AC-4: versions synced at 5.19.0
test "$(jq -r .version plugins/spec-flow/plugin.json)" = "5.19.0" \
  && test "$(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json)" = "5.19.0" \
  && test "$(jq -r '.plugins[] | select(.name=="spec-flow") | .version' .claude-plugin/marketplace.json)" = "5.19.0" \
  && echo "AC-4 OK"
# AC-5: changelog section
grep -q "## \[5.19.0\] — 2026-06-13" plugins/spec-flow/CHANGELOG.md && echo "AC-5 OK"
```
Expected: `AC-1/2 OK`, `AC-3 OK`, `AC-4 OK`, `AC-5 OK` all print.

**Track rationale:** Implement — prose + metadata edits with no behavior-bearing
logic; correctness is verified by grep/jq assertions, not by unit tests.
