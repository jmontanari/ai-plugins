---
piece_class: behavior-bearing
integration_rationale: edits a static config file; no runtime boundary crossed
---
# Spec: qaspec-omission-with-rationale (fixture)

## Functional Requirements
- FR-1: The data exporter reads a dictionary of field-to-column mappings and generates a static CSV config file.
- FR-2: The config writer serializes the mapping rows to `src/export/config_map.csv` with no external service call.

## Acceptance Criteria
AC-1: Given a field-to-column dictionary, When export runs, Then each mapping is serialized as a CSV row [mechanism]
  Independent Test [machine: grep "serialize_mapping" src/export/config_writer.py]: confirm serializer function present

AC-2: Given a field-to-column dictionary, When export runs, Then the output is written to `src/export/config_map.csv` [mechanism]
  Independent Test [machine: grep "write_config" src/export/config_writer.py]: confirm writer function present

Outcome N/A [outcome:integration]: no externals

## Integration Coverage
None in scope.
