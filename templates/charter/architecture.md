---
last_updated: {{date}}
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

## External References

Link to external architecture docs or local ADR folders that are also binding.

- [Clean Architecture (Uncle Bob)](https://...)
- `docs/adr/` — Architecture Decision Records
