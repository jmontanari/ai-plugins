---
name: fixture-3defect
description: A fixture with exactly three blocking findings (one per blocking invariant).
---

# Fixture Three Defects

This fixture mirrors the clean fixture but introduces one defect per blocking
invariant (1, 2, 3).

## Overview

The flow runs through three numbered steps. See §Nonexistent heading for the
entry point. Then proceed to Step 2 and Step 3.

Defect (invariant 1): the prose here references Step G9z, but no heading for
it exists in this file — that step reference cannot resolve.

### Step 1: Gather inputs

Collect the target paths. When done, advance to Step 2.

### Step 2: Process

Process each input. On completion move to Step 3.

### Step 3: Commit

Finalize. Control returns to Step 1 on the next run.

## Configuration notes

The `phase_groups:` knob governs Phase Group scheduling and has three documented
values. This region documents two of them — `phase_groups: auto` (the default
concurrent dispatch) and `phase_groups: always` (which errors on a flat plan) —
but OMITS the third documented value (the rollback mode). Because this is a
branch-documentation region (it mentions two distinct enum values) that fails to
document every value, config-branch parity (invariant 3) is violated for
`phase_groups` here.
