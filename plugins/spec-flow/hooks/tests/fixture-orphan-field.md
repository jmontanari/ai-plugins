---
name: fixture-orphan-field
description: Clean for invariants 1–3, but contains both an orphan PRODUCER (written-never-read) and an orphan CONSUMER (read-never-written) state field (invariant-4 WARNINGs).
---

# Fixture Orphan Field

This fixture is clean for the three blocking invariants but trips the
state-field producer→consumer warning heuristic (invariant 4).

## Overview

The flow runs through three numbered steps. See the §Step 1: Begin heading
below. Then proceed to Step 2 and Step 3.

### Step 1: Begin

The journal records a `phase_start_sha` value when the section opens. We write
and persist `phase_start_sha` here. Advance to Step 2.

### Step 2: Continue

Process work. On completion move to Step 3.

### Step 3: Finish

Finalize and advance back to Step 1 on the next run. The recovery path reads and
loads `group_resume_state` to resume — but nothing in this file ever writes or
produces `group_resume_state`, so it is an orphan CONSUMER (invariant-4,
read-but-never-written).

## Configuration notes

The `deferred_commit:` knob governs the commit model: `auto` runs git-free
with a deferred commit, while `off` keeps per-phase commits. Both `auto` and
`off` appear here so branch parity holds.
