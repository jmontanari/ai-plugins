---
piece_class: behavior-bearing
---
# Spec: clean-correct (fixture)

## Functional Requirements
- FR-1: The report generator exports formatted data to an external archive service via `src/report/exporter.py`.
- FR-2: The archive service is an external dependency; the exporter is the sole production caller.

## Acceptance Criteria
AC-1: Given a formatted report, When the export pipeline runs, Then data is formatted for transmission [mechanism]
  Independent Test [machine: grep "format_data" src/report/formatter.py]: confirm format function present

AC-2: Given a formatted report, When the export pipeline runs, Then data is exported to the archive service [outcome:integration]
  Independent Test [machine: prod-callsite=src/report/exporter.py:22; grep "export_archive" src/report/exporter.py]: confirm export call site in production code

Outcome N/A [outcome:result]: this fixture tests integration gate evaluation; result coverage is not the test target

## Integration Coverage
- Integration: report-pipeline→archive-service — inside: report service (src/report/); doubled externals: ArchiveService (contract-tested via FakeArchive); AC-2; completes phase 2
