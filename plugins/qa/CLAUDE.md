# QA Plugin

Paranoid adversarial QA for implementation work. Hunts for what's MISSING, BROKEN, FRAGILE, or EXPLOITABLE.

## Available Skills

- **qa-validate** — Full exit gate validation with 4-dimension adversarial assessment. Use after any implementation phase, before merge, or before PR.
- **qa-attack-plan** — Pre-implementation adversarial review. Identifies attack vectors before you write code.
- **qa-spot-check** — Quick targeted checks for focused concerns without full ceremony.

## Available Agents

- **validator-agent** — Dispatched by the QA skills for deep adversarial validation. Executed in a separate context window.

## Quick Start

```
/skill qa-validate
/skill qa-attack-plan
/skill qa-spot-check
```
