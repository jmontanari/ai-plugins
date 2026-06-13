---
piece_class: behavior-bearing
---
# Spec: rbi-unwired-pointer (fixture)

## Functional Requirements
- FR-1: The report generator calls `src/report/exporter.py` to export formatted data to an external archive service.

## Acceptance Criteria
AC-1: Given a report batch, When the report pipeline runs, Then data is formatted for output [mechanism]
  Independent Test [machine: grep "format_data" src/report/formatter.py]: confirm format function

AC-2: Given a formatted report, When the pipeline runs, Then data is exported to the archive service [outcome:integration]
  Independent Test [machine: prod-callsite=src/report/exporter.py:42; grep "export_archive" src/report/exporter.py]: confirm export call site

## Integration Coverage
- Integration: report-pipeline→archive-service — inside: report service (src/report/); doubled externals: ArchiveService (contract-tested via FakeArchive); AC-2; completes phase 2
