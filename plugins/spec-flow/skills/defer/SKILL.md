---
name: defer
description: Use when an operator (or the orchestrator's discovery-triage flow) needs to record a non-blocking finding to a backlog file with provenance. Sole supported path for writing to <docs_root>/prds/<prd-slug>/backlog.md or <docs_root>/improvement-backlog.md. Invoked structured (from execute/SKILL.md Step 6c after operator chooses defer) or manually (/spec-flow:defer "<finding>" --rationale "<text>"). Refuses if --rationale is missing.
---

# Defer — Record a Non-Blocking Finding to a Backlog with Provenance

The `/spec-flow:defer` skill is the **sole supported path** for writing to backlog files in a spec-flow project. It exists so every backlog entry carries provenance — which piece surfaced the finding, in which phase, by which agent, and the operator's explicit rationale for why the finding does not block the current piece's goals.

The skill is invoked in two forms:

- **Manually** by an operator who wants to capture a finding outside any active triage flow.
- **Structured** by the orchestrator (`plugins/spec-flow/skills/execute/SKILL.md` Step 6c) after the operator has chosen `defer` in a discovery-triage prompt.

The skill refuses if the operator's rationale is missing — silent backlog writes (the v3.1.x pattern) are no longer supported. Every entry must answer "why does this not block this piece's goals?" in the operator's own words.

This skill is a thin orchestrator (CR-008): it parses arguments, formats one entry, appends it to the target file, and commits. It does **not** dispatch subagents and introduces no runtime code dependencies (NN-C-002).

---

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` for all paths below; use `worktrees_root` in place of `worktrees/` for the active-piece resolution. If the file is missing, default to `docs` and `worktrees` respectively.

---

## Environment preconditions

Three host-side capabilities are required to run this skill:

- **LLM-driven execution context with file-reading and inline parsing.** The defer skill is authored as natural-language instructions the LLM agent follows; argument parsing, manifest reverse-lookup, entry formatting, and the file append are all performed via the agent's native parsing and file-edit capabilities — no specific language runtime is mandated.
- **`git` ≥ 2.5** — required for the resulting commit (`git add` + `git commit`) on the active worktree branch and for `git worktree list` during active-piece resolution.
- **POSIX shell** — required for `cd`, `date +%F` (the entry's date placeholders resolve via the shell's `date +%F` invocation at write time), and `git` invocation.

Explicitly: no external parser/runtime is required. `python3`, `yq`, `jq`, `ruby`, `node`, and similar tools may be present on the host, but the defer skill does not invoke them.

These capabilities live in the LLM agent's runtime, not in the user's installed plugin. NN-C-002 binds plugin-internal runtime dependencies; this skill ships only markdown text. (NFR-004: documentation as source of truth — the preconditions list above is the contract.)

---

## Argument parsing

The skill accepts two invocation forms. Determine the form from the shape of the input.

### Manual form

```
/spec-flow:defer "<finding>" --rationale "<text>" [--global] [--source-piece <slug>] [--source-phase <id>]
```

Arguments:

- `<finding>` (positional, required) — a one-line finding summary. Used both as the entry heading's `<finding-summary>` and as the `**Finding (verbatim):**` body.
- `--rationale "<text>"` (required) — operator's prose explaining why this finding does not block the current piece's goals. Refusal contract fires if this flag is absent or its value is empty.
- `--global` (flag, optional) — if present, write to `<docs_root>/improvement-backlog.md` instead of the per-piece backlog. See **Backlog target resolution** below.
- `--source-piece <slug>` (optional) — explicit piece slug. Either bare (`<piece-slug>`) or qualified (`<prd-slug>/<piece-slug>`). When omitted, the skill resolves the active piece via `git worktree list` + reverse-lookup against `<docs_root>/prds/*/manifest.yaml`: find the manifest entry whose `<piece-slug>` matches the worktree's `piece-<piece-slug>` directory name.
- `--source-phase <id>` (optional) — phase id (e.g. `phase_3`, `phase_a1`, `final`). When omitted in manual form, the skill records the literal token `manual` for the source-phase column.

Capture: `finding` (string), `rationale` (string), `global_target` (bool), `source_piece` (string or null), `source_phase` (string or null).

### Structured form (orchestrator-driven)

The orchestrator passes a single context block with named fields:

- `source_piece` — qualified `<prd-slug>/<piece-slug>` of the piece that surfaced the finding.
- `source_phase` — the upstream phase id (e.g. `phase_3`, `phase_a1`, `final`, `step-4.5-reflection`).
- `source_agent` — the agent name that surfaced the finding (e.g. `qa-implementation`, `reflection-future-opportunities`).
- `finding_text` — the verbatim finding body.
- `operator_rationale` — the rationale the operator supplied during the upstream triage prompt.
- `target` — optional; set to the literal string `global` to write to the global backlog instead of the per-piece backlog. Absent for the per-piece default.
- `discovery_type` — optional; the original discovery classification (e.g. `requires-amendment`, `does-not-block-goal`, `requires-fork`). Used to populate the `Discovery type` column in `.discovery-log.md`. When absent, record `deferred` in that column.

When invoked structured (i.e. the required named fields are present in a context block — `source_piece`, `source_phase`, `source_agent`, `finding_text`, `operator_rationale`, `target` (optional), `discovery_type` (optional)), the skill **skips operator-prompt code paths entirely** — no confirmation prompt is shown. The operator already chose `defer` in the upstream triage flow; re-prompting here would be a redundant gate. (AC-4: structured invocations skip the operator confirmation step.)

When invoked manually, follow the **Operator confirmation step (manual invocation only)** section below before the file write.

---

## Refusal contract

The skill emits one of these exact strings and exits without writing or committing:

- **Missing rationale** (manual form, `--rationale` absent or empty value):
  ```
  REFUSED — defer requires --rationale; explain why this finding does not block the current piece's goals.
  ```
  (AC-2: the verbatim REFUSED string for the missing-rationale case.)

- **Unresolved active piece** (manual form, no `--source-piece` and `git worktree list` reverse-lookup found no matching manifest entry, e.g. invoked outside any piece worktree):
  ```
  Refused — no active piece detected; pass --source-piece explicitly or invoke from within a piece worktree.
  ```
  (NN-C-005: the skill is silent on missing optionals — it surfaces a refusal rather than failing or guessing.)

Structured invocations cannot trigger either refusal: the orchestrator supplies all required fields in the context block. If a structured invocation is missing a required field, treat it as a malformed dispatch and emit the corresponding manual-form refusal string.

---

## Backlog target resolution

The skill writes to exactly one file per invocation, chosen by:

- **`--global` flag (manual) or `target=global` (structured)** → write to `<docs_root>/improvement-backlog.md`.
- **Default** → write to `<docs_root>/prds/<prd-slug>/backlog.md` of the active piece.

The active piece's `<prd-slug>` is derived from:

- Structured form: parse `source_piece` (always qualified `<prd-slug>/<piece-slug>`); use the `<prd-slug>` portion.
- Manual form: when `--source-piece` is qualified, use its `<prd-slug>` portion; when bare or omitted, reverse-lookup via `git worktree list` to the `piece-<piece-slug>` directory, then locate that piece in the appropriate `<docs_root>/prds/<prd-slug>/manifest.yaml`.

The entry's `**Source:**` line **always uses the qualified `<prd-slug>/<piece-slug>` form** regardless of which target file the entry lands in. The global backlog and per-piece backlogs both record full provenance — only the target file path differs. (AC-3: `--global` flag controls the target file; provenance shape is invariant.)

---

## Entry format

Each defer invocation appends exactly one entry to the target file using this template:

```markdown
### [Deferred via /spec-flow:defer] <finding-summary> — YYYY-MM-DD

**Source:** `<prd-slug>/<piece-slug>` phase `<phase-id>` (agent: `<agent-name>`)
**Finding (verbatim):** <finding-text>
**Why this does not block <piece-slug>'s goals:** <operator-rationale>
**Captured:** YYYY-MM-DD
```

Field mapping:

1. `<finding-summary>` — the manual-form positional `<finding>` argument, or the first line of structured-form `finding_text` (truncated at 80 chars if the body is multi-line; the full body still appears in `**Finding (verbatim):**`).
2. `<prd-slug>/<piece-slug>` — qualified piece reference (always qualified — see **Backlog target resolution**).
3. `<phase-id>` — `source_phase` from the context block, or `--source-phase <id>` from the manual form, or the literal token `manual` when the manual form omits `--source-phase`.
4. `<agent-name>` — `source_agent` from the structured context block; in manual form, the literal token `operator`.
5. `<finding-text>` — the verbatim finding body (multi-line allowed; preserve the operator's formatting).
6. `<operator-rationale>` — the verbatim `--rationale` value (manual) or `operator_rationale` field (structured).

Both `YYYY-MM-DD` placeholders (the heading date and the `**Captured:**` date) resolve via `date +%F` at write time — invoke the shell command, capture its output, and substitute both occurrences with the same value. (Per the FR-2 entry shape: six required fields — heading-with-date, Source, Finding, Why-this-does-not-block, Captured. AC-1: all six required fields are present in every entry.)

The entry is placed under the target file's `## Recent findings` H2 section. If that section does not exist in the target file, create it at the end of the file (preceded by a blank line if the file is non-empty), with the H2 heading on its own line, then a blank line, then the new entry. Subsequent invocations append below the prior entry within the same `## Recent findings` section.

---

## Workflow

Execute these steps in order:

1. **Parse arguments / context block.** Determine invocation form (manual vs. structured). Capture all relevant fields per the **Argument parsing** section.
2. **Refuse if rationale missing.** If manual form and `--rationale` is absent or empty, emit the FR-2 refusal contract string and exit. Do not write, do not commit.
3. **Resolve target backlog file path.** Per **Backlog target resolution** — determine the absolute path to either `<docs_root>/improvement-backlog.md` or `<docs_root>/prds/<prd-slug>/backlog.md`. If the active piece cannot be resolved (manual form, no `--source-piece`, reverse-lookup miss), emit the unresolved-active-piece refusal and exit.
4. **Format entry.** Apply the **Entry format** template. Resolve both date placeholders via a single `date +%F` invocation so the heading date and the `**Captured:**` date match.
5. **Operator confirmation (manual form only).** Run the **Operator confirmation step** below. On `n`, abort without writing or committing. On `y`, continue to step 6. Skip this step entirely for structured invocations (the operator already chose `defer` in the upstream triage prompt — see AC-4).
6. **Append entry under `## Recent findings`.** If the section exists, append below the most recent prior entry. If absent, create it at end-of-file with appropriate spacing.
7. **Append discovery-log row (structured invocations only).** When invoked structured (from execute/SKILL.md Step 6c), append a row to `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md` using the per-row format from execute/SKILL.md `.discovery-log.md authoring`. Fields: Phase = `source_phase`, Discovery type = `discovery_type` (or `deferred` if absent), Source agent = `source_agent`, Finding (1-line) = first line of `finding_text` (truncated at 80 chars), Triage choice = `defer`, Resolution commit = the commit subject that step 8 will produce (`chore(<piece-slug>): defer <finding-summary>`). If `.discovery-log.md` does not exist, create it with the H1 header and table header rows first. Manual invocations skip this step.
8. **Commit on the active worktree branch.** Stage and commit:
   - Structured path: `git add <target-backlog-path> <discovery-log-path>` (both files), then `git commit -m "chore(<piece-slug>): defer <finding-summary>"`. The single commit captures both the backlog entry and the audit-trail row, consistent with the resolution-commit-cell convention in execute/SKILL.md.
   - Manual path: `git add <target-backlog-path>` (backlog file only), then `git commit -m "chore(<piece-slug>): defer <finding-summary>"`. Use the chore type per CR-004 (Conventional Commits with the piece slug as scope). The commit lands on whatever branch the current worktree is checked out to.
9. **Report success.** Emit a one-line success report containing:
   - The path of the file(s) modified (absolute or repo-relative; match the path style used elsewhere in the orchestrator's session).
   - The commit SHA (`git rev-parse HEAD` after the commit).

---

## Operator confirmation step (manual invocation only)

When invoked manually (not structured), after formatting the entry but before performing the write, read the formatted entry back to the operator and prompt:

```
Append this entry to <target-path> and commit? (y/n)
```

- On `y` (or `yes`, case-insensitive): proceed with steps 6–9 of the **Workflow**.
- On `n` (or anything other than affirmative): emit `Aborted by operator — no changes written.` and exit. Do not write, do not commit.

**Structured invocations skip this step entirely** (step 5 only). The skill proceeds directly from step 4 (format) to step 6 (append) to step 7 (discovery-log row) to step 8 (commit) to step 9 (report). (AC-4: when invoked from execute/SKILL.md Step 6c with a structured context block, the operator already chose `defer` in the upstream triage flow; re-prompting would be a redundant gate.)
