---
piece_class: behavior-bearing
---
# Spec: qaspec-testrooted-pointer (fixture)

## Functional Requirements
- FR-1: The ingest service calls an external HTTP reporting API to submit processed records.
- FR-2: The call site at `src/ingest/reporter.py` is the sole production caller of the reporting API.

## Acceptance Criteria
AC-1: Given a processed record, When the ingestion pipeline runs, Then the record is stored in the local DB [mechanism]
  Independent Test [machine: grep "INSERT INTO" src/ingest/store.py]: confirm store code present

AC-2: Given a processed record, When the ingestion pipeline runs, Then the record is submitted to the reporting API [outcome:integration]
  Independent Test [machine: prod-callsite=tests/foo_test.py:10; grep "submit_report" tests/foo_test.py]: confirm call site present

## Integration Coverage
- Integration: ingest-service→reporting-api — inside: ingest service (src/ingest/); doubled externals: ReportingAPI (contract-tested via MockServer); AC-2; completes phase 2
