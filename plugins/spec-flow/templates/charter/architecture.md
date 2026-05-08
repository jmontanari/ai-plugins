---
name: charter-architecture
description: "{{description}}"
---

# Architecture

Project-wide architectural decisions. Binding on every piece.

## Top-level layers

List the layers in your system (e.g., presentation / application / domain / infrastructure). For each, describe its responsibility in one line.

- **{{layer_1}}** — {{responsibility}}
- **{{layer_2}}** — {{responsibility}}

## Dependency direction

Which direction imports flow. Violations are architecture conflicts and cause implementer agents to BLOCK.

- {{layer_1}} may depend on {{allowed_targets}}
- {{layer_2}} may depend on {{allowed_targets}}
- Forbidden: {{forbidden_dependencies}}

## Component ownership

Who owns which modules. Used by review-board architecture reviewer to flag cross-ownership changes.

| Component | Owner | Boundary |
|-----------|-------|----------|
| {{component}} | {{owner}} | {{public_interface_summary}} |

## Data flow

How data enters, transforms, and exits the system. Key transformation stages and where validation happens.

{{data_flow_description}}

## Error and failure handling

How errors propagate across layers. The canonical convention (e.g., exceptions, Result types, error returns). All layers must follow this convention — cross-module inconsistencies are architecture violations.

{{error_handling_convention}}

## Security boundaries

Where authentication and authorization are enforced. What data is sensitive and how it is protected at rest and in transit. Where input validation happens.

{{security_boundaries}}

## External References

Link to external architecture docs or local ADR folders that are also binding.

- {{external_reference_1}}
- {{external_reference_2}}
