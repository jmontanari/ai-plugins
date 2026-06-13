---
piece_class: behavior-bearing
---
# Spec: behaving-missing-result (fixture)

## Acceptance Criteria
AC-1: Given input, When processed, Then output stored [mechanism]
  Independent Test [machine: grep stored]: check output file exists
AC-2: Given record, When saved, Then DB row written [mechanism]
  Independent Test [machine: query DB]: row count > 0
Outcome N/A [outcome:integration]: this piece has no external seam
