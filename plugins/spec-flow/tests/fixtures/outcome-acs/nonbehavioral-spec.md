---
piece_class: non-behavioral
behavior_rationale: this fixture is a configuration-only scaffold; no output is produced or consumed by external components
---
# Spec: nonbehavioral-spec (fixture)

## Acceptance Criteria
AC-1: Given a config file, When the deploy script runs, Then the config is copied to the target directory [mechanism]
  Independent Test [machine: ls target]: target/config.yaml exists
