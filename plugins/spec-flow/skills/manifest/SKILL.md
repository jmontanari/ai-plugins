---
name: manifest
description: >-
  Query and mutate spec-flow manifest.yaml files. Triggers: "read the manifest",
  "what's open", "what can I work on next", "what's ready", "what depends on X",
  "mark piece X as Y", "set status".
---

# Manifest — Query and Mutate a manifest.yaml

The `/spec-flow:manifest` skill is a thin wrapper around the
`${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query` tool. It reads or updates a
`manifest.yaml` file without loading the full pipeline context.

All subcommands require `--file <path>` pointing at a manifest.yaml. There are
no interactive prompts — each invocation produces output and exits.

---

## Runtime

`manifest-query` uses a `python3` fast path when `python3` is available. When
`python3` is absent the tool falls back to a complete pure-bash/awk
implementation — zero extra dependencies required. Set `MANIFEST_QUERY_NO_PY=1`
to force the bash/awk path explicitly (useful for testing or when the Python
environment is suspect).

---

## Subcommands

### open

List all pieces whose status is not `merged` (in manifest order).

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query" open \
  --file "${CLAUDE_PLUGIN_ROOT}/scripts/tests/fixtures/exec-ready.yaml"
```

Example output (from the stable exec-ready fixture):

```
spec-preresearch
flywheel-repo
flywheel-global
```

### deps

Forward lookup: list the dependencies of a named piece, one per line.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query" deps spike-agent \
  --file "${CLAUDE_PLUGIN_ROOT}/scripts/tests/fixtures/exec-ready.yaml"
```

Example output:

```
plan-concrete
sonnet-coord
```

Reverse lookup: list pieces whose `dependencies` field includes a named piece.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query" deps plan-concrete --reverse \
  --file "${CLAUDE_PLUGIN_ROOT}/scripts/tests/fixtures/exec-ready.yaml"
```

Example output:

```
test-data-up
sonnet-coord
spike-agent
```

### ready

List pieces that are workable next: `status: open` AND every dependency's status
is `merged` or `done` (the backward-compatible terminal alias per spec-flow's
piece-status state machine).

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query" ready \
  --file "${CLAUDE_PLUGIN_ROOT}/scripts/tests/fixtures/exec-ready.yaml"
```

Example output:

```
flywheel-repo
```

### table

Print an aligned overview table: `slug | status | deps | prd_sections`.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query" table \
  --file "${CLAUDE_PLUGIN_ROOT}/scripts/tests/fixtures/exec-ready.yaml"
```

Example output (from the stable exec-ready fixture):

```
slug              status   deps                         prd_sections
----------------  -------  ---------------------------  -------------------------------------------
research-unify    merged                                FR-001, NFR-001, NFR-003, G-1
plan-concrete     merged   research-unify               FR-002, G-1, G-2
test-data-up      merged   plan-concrete                FR-003, G-1
sonnet-coord      merged   plan-concrete                FR-004, NFR-002, NFR-003, NFR-004, G-3, G-4
spike-agent       merged   plan-concrete, sonnet-coord  FR-005, FR-008, G-2, G-3
spec-preresearch  specced  research-unify               FR-009
flywheel-repo     open     sonnet-coord                 FR-006, G-5
flywheel-global   open     flywheel-repo                FR-007, G-5
```

### set-status

Rewrite one piece's `status:` field in-place. The new status must be a member of
the vocabulary: `open`, `specced`, `planned`, `in-progress`, `merged`, `done`,
`superseded`, `blocked`. The slug must exist in the manifest — unknown slugs are
rejected with a non-zero exit.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/manifest-query" set-status flywheel-repo specced \
  --file "${CLAUDE_PLUGIN_ROOT}/scripts/tests/fixtures/exec-ready.yaml"
```

On success: exits 0 with no output (the file is updated in place).

Error cases:

- Unknown status value: `Error: unknown status: 'badstatus'. Valid: open specced ...` (exit 2)
- Unknown slug: `Error: unknown slug: nonexistent-slug` (exit 2)
