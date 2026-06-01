# QA Plugin

Paranoid QA validator with adversarial testing skills for Claude Code.

## Description

Full-lifecycle quality assurance plugin: pre-implementation plan review, in-progress spot checks, and post-implementation exit gate verification. The validator-agent performs paranoid adversarial testing across 4 dimensions (MISSING/BROKEN/FRAGILE/EXPLOITABLE).

## Installation

```bash
# Add marketplace (first time only)
/plugin marketplace add /Volumes/joeData/code/claude-plugins

# Install QA plugin
/plugin install qa@claude-plugins
```

## Commands

| Command | Mode | When to Use |
|---------|------|-------------|
| `/qa-validate` | VERIFY | Full paranoid validation after implementation (exit gate) |
| `/qa-attack-plan` | ATTACK-PLAN | Pre-implementation adversarial plan review |
| `/qa-spot-check` | SPOT-CHECK | Quick targeted checks during implementation |

## Components

- **Agent:** `validator-agent.md` — Paranoid adversarial validator (sonnet model)
- **Skills:** `validate/`, `attack-plan/`, `spot-check/` — Three verification modes
- **Hooks:** SessionStart (bootstrap) + SubagentStop (implementer/validator) + Stop (exit gate enforcement)
- **Commands:** `qa.md` — Command router

## Enforcement Architecture

The QA plugin enforces validation through tiered hook-based gates:

### Tiers

| Tier | Trigger | Behavior |
|------|---------|----------|
| 1 (block) | Plan contains `[VERIFY]` items | Exit gate blocks (exit 2) until validator-agent runs |
| 2 (suggest) | Implementation work detected, no `[VERIFY]` | Suggests validation at exit |
| 3 (silent) | Read-only session / no plans | All hooks silent |

### Lifecycle Hooks

| Hook | Trigger | Action |
|------|---------|--------|
| `qa-bootstrap.sh` | SessionStart | Scans plans for `[VERIFY]`, sets tier, initializes state |
| `qa-post-implementer.sh` | SubagentStop(implementer) | Increments counter, sets `qa_pending`, outputs directive |
| `qa-post-validator.sh` | SubagentStop(validator-agent) | Sets `validated=true`, clears `qa_pending` |
| `qa-exit-gate.sh` | Stop | Tier 1: blocks if not validated. Tier 2: suggests. Loop prevention (max 3). |

### State

State file: `~/.claude/state/qa/session.json` — tracks enforcement tier, implementer count, pending/validated flags.

### LRT Coexistence

QA and LRT plugins use separate state directories (`state/qa/` vs `state/agents/`) and fire independently without conflicts.

## Testing

```bash
# Structure tests
bash plugins/qa/tests/static/qa-plugin-structure.sh

# Hook unit tests
bash plugins/qa/tests/unit/test-qa-hooks.sh

# Integration lifecycle tests
bash plugins/qa/tests/integration/test-qa-lifecycle.sh
```

## Auto QA (Optional)

Enable automatic spot-checks after implementer completion by setting `auto_qa: true` in session state. When enabled, the SubagentStop hook prompts the lead to run `/qa-spot-check` on changed files.

Default: Disabled.
