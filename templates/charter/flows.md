---
last_updated: {{date}}
---

# Flows

Dynamic behavior of the system. Complements `architecture.md` (static view) with end-to-end paths agents must respect when designing or modifying code.

## Request flow

Describe a typical request from ingress to response. Include middleware order, interceptors, filters.

```
{{diagram_or_ordered_list}}
```

## Auth flow

Login, token issuance, refresh, authorization checks.

```
{{diagram_or_ordered_list}}
```

## Data-write path

API → validation → persistence → events. Include transactional boundaries.

```
{{diagram_or_ordered_list}}
```

## Other critical flows

Add any additional end-to-end paths that agents must honor (e.g., background job scheduling, webhook ingestion, batch-processing pipelines).

### {{flow_name}}

```
{{diagram_or_ordered_list}}
```

## External References

- [{{architecture_diagram_tool}}]({{url}}) — canonical system diagrams (if maintained externally)
- `{{internal_path}}` — local diagram source files
