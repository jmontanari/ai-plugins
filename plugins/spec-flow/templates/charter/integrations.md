---
name: charter-integrations
description: "{{description}}"
---

# Integrations

Optional external service integrations available to plugins in this project. Skills that depend on an integration must document the requirement in their `CLAUDE.md` and reference this file.

---

## {{integration_name}} (via {{mechanism}})

**Status:** {{available_planned_deprecated}} — {{availability_note}}

### What it enables

- {{capability_1}}
- {{capability_2}}

### Prerequisites

{{prerequisites_description}}

### Skills that use this integration

| Plugin | Skill | Usage |
|---|---|---|
| {{plugin}} | {{skill}} | {{how_used}} |

### Graceful degradation

{{degradation_behavior}}

---

## Adding a new integration

To document a new integration:

1. Add a section to this file following the format above: status, what it enables, prerequisites, which skills use it, graceful degradation behavior.
2. Update any plugin `CLAUDE.md` files that use the integration to reference this file.
3. Open a PR per the project's review policy.
