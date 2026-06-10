# spec.md — demo/hello

## Goal

Provide a minimal greet utility that says hello to a named subject, with a
configurable suffix resolved at execute time by spike-agent.

## Functional Requirements

- FR-1: `greet <name>` prints `hello, <name>` to stdout.
- FR-2: The suffix value is determined at execute time via spike; wired through
  `src/config.txt` with key `greet_suffix`.

## Acceptance Criteria

- AC-1 (greet behavior): Given input "world", `greet world` outputs `hello, world`.
- AC-2 (config glue): `src/config.txt` contains `greet_suffix=<resolved-value>`;
  the greet function reads it at runtime.
- AC-3 (spike-resolved value): The spike-resolved suffix appears verbatim in
  `plan.md` Test Data and in the greet test oracle.
- AC-4 (phase coverage): All four plan phases produce passing oracle gates.

## Non-Negotiables

- No model invocations in any test or source file.
