---
name: charter-flows
description: "{{description}}"
---

# Flows

Dynamic behavior of the system. Complements `architecture.md` (static view) with end-to-end paths agents must respect when designing or modifying code.

## Critical flows

Identify the 3–6 most critical end-to-end flows in this system. For each, describe: entry point, happy path steps, error path, external dependencies, how failures surface.

### {{flow_1_name}}

```
{{diagram_or_ordered_list}}
```

### {{flow_2_name}}

```
{{diagram_or_ordered_list}}
```

### {{flow_3_name}}

```
{{diagram_or_ordered_list}}
```

## Documentation update triggers

When plugin behavior, structure, or public surface changes, these docs must be updated in the same PR:

| What changed | Docs to update |
|---|---|
| {{change_type}} | {{docs_to_update}} |

## External References

- {{external_reference_1}}
- {{external_reference_2}}
