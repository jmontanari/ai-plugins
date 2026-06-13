---
piece_class: behavior-bearing
---
# Spec: qaplan-unmapped-seam (fixture)

## Functional Requirements
- FR-1: The ingest service fetches external data via HTTP using `src/ingest/http_client.py`.

## Acceptance Criteria
AC-1: Given a batch job, When the ingest pipeline runs, Then data is stored locally [mechanism]
  Independent Test [machine: grep "insert" src/ingest/store.py]: confirm store call

AC-2: Given a batch job, When the ingest pipeline runs, Then external data is fetched via HTTP [outcome:integration]
  Independent Test [machine: prod-callsite=src/ingest/http_client.py:88; grep "fetch" src/ingest/http_client.py]: confirm HTTP call

## Integration Coverage
- Integration: ingest-pipeline→external-http-api — inside: ingest service (src/ingest/); doubled externals: ExternalHTTPAPI (contract-tested via FakeHTTP); AC-2; completes phase 2
