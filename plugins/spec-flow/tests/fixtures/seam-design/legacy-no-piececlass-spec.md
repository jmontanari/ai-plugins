---
# no piece_class key — legacy spec; all piece_class-gated criteria skip
---
# Spec: legacy-no-piececlass (fixture)

## Functional Requirements
- FR-1: The batch processor reads records from a local file and writes results to a database.

## Acceptance Criteria
AC-1: Given a batch file, When the processor runs, Then all records are written to the DB [mechanism]
  Independent Test [machine: query DB count]: row count matches input

AC-2: Given a batch file, When the processor runs, Then a completion log entry is written [mechanism]
  Independent Test [machine: grep "COMPLETE" log.txt]: log entry present

## Integration Coverage
None in scope.
