---
name: fixture-clean
description: A coherent SKILL.md-shaped fixture that lints clean (exit 0).
---

# Fixture Clean

This fixture is internally consistent across all four invariants.

## Overview

The flow runs through three numbered steps. See the §Step 1: Gather inputs
heading below for where it begins, then proceeds to Step 2 and Step 3.

### Step 1: Gather inputs

Collect the target paths. When done, advance to Step 2.

### Step 2: Process

Process each input. On completion move to Step 3.

### Step 3: Commit

Finalize. This is the last step; control returns to Step 1 on the next run.

## Configuration notes

The `deferred_commit:` knob governs the commit model. When set to `auto`,
the section runs git-free with one deferred commit at the barrier; when set
to `off`, sub-phases commit per-phase (pre-5.0.0 behavior). Both `auto` and
`off` are documented here so the branch parity holds.
