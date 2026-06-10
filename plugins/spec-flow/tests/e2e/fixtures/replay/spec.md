# spec.md — demo/hello

## Goal

Provide a minimal greet utility that says hello to a named subject, with a configurable suffix resolved at execute time by spike-agent.

## Functional Requirements

- FR-1: `greet <name>` prints `hello, <name>` followed by the spike-resolved suffix.
- FR-2: The suffix value is determined at execute time and wired via config; the config key is `greet_suffix`.

## Acceptance Criteria

- AC-1 (greet behavior): Given input "world", `greet world` outputs a line containing `hello, world`.
- AC-2 (config glue): A `src/config.txt` file provides `greet_suffix=<value>`; the greet function reads it at runtime.
- AC-3 (spike-resolved value): The spike-resolved suffix value appears verbatim in `plan.md` Test Data block and in the greet test oracle.
