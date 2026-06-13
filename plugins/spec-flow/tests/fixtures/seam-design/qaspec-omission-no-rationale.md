---
piece_class: behavior-bearing
---
# Spec: qaspec-omission-no-rationale (fixture)

## Functional Requirements
- FR-1: The data exporter calls an external SMTP server to send notification emails.
- FR-2: The call site wires the exporter service directly to the SMTP gateway at `src/export/mailer.py`.

## Acceptance Criteria
AC-1: Given a data batch, When export runs, Then each record is formatted for output [mechanism]
  Independent Test [machine: grep "format_record" src/export/formatter.py]: confirm format function present

AC-2: Given a data batch, When export runs, Then notification email is sent via SMTP [mechanism]
  Independent Test [machine: grep "send_email" src/export/mailer.py]: confirm mailer function present

Outcome N/A [outcome:integration]: no externals

## Integration Coverage
None in scope.
