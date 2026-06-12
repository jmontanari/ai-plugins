# transcript-eval

Internal maintainer tool for mining spec-flow session transcripts. **not shipped** — not part of the installed plugin (NN-C-002 by location, ADR-3 — lives at repo-root `tools/`, outside `plugins/spec-flow/`).

## Setup

```bash
python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
```

No third-party deps are required — the tool uses stdlib only (`json`, `pathlib`, `argparse`, `re`, `os`).

## Usage

```bash
python3 -m transcript_eval --help

# Subcommands (implemented in later phases):
python3 -m transcript_eval extract  --project-dir ~/.claude/projects/my-project/ --store /path/to/store
python3 -m transcript_eval metrics  --store /path/to/store
python3 -m transcript_eval story    --store /path/to/store
```

## Config

| Flag | Env var | Default | Description |
|------|---------|---------|-------------|
| `--store <path>` | `SPEC_FLOW_INSIGHTS_STORE` | `/Volumes/joeData/spec-flow-insights/` | External insight store path (must be writable) |
| `--project-dir <path>` (repeatable) | `SPEC_FLOW_PROJECT_DIRS` (colon-separated) | All `~/.claude/projects/*/` | Source project directories to mine |

Precedence: CLI flag > env var > default.

The store path must be **outside the repo root** — an in-repo store path is rejected at startup (SF-6 guard).

## Producing the baseline

**Precondition:** The extraction-validation spike (`transcript_eval spike`) must have emitted `PROCEED` (coverage ≥ 95%, agreement ≥ 80% if hand-check provided). Only run the full baseline after a `PROCEED`.

**Run the full pipeline** across all configured project dirs (default: all `~/.claude/projects/*/`) writing to the external store:

```bash
cd tools/transcript-eval
python3 -m transcript_eval story
```

The command writes three artifacts to the external store (default `/Volumes/joeData/spec-flow-insights/`):
- `aggregates.json` — per-seat precision/overlap/leave-one-out/rubber-stamp/activity
- `story-latest.md` — cross-repo pipeline-health narrative with `## FR-016 per-seat evidence`
- `run-index.jsonl` — new entry recording run metadata

**Nothing mined is written into the repo** (SF-5/SF-6). The only in-repo artifact from this step is `BASELINE.md` (metadata only — no aggregates, findings, or transcript content).

**Operator confirmations (required before closing the baseline):**

1. **AC-3 — Story accuracy:** Read `<store>/story-latest.md` and confirm it is accurate and decision-useful (the `## FR-016 per-seat evidence` section reflects real cross-repo usage).
2. **AC-5 — No in-repo leakage:** Run `git status --porcelain` after the baseline run and confirm the ONLY new/changed in-repo files are `README.md` + `BASELINE.md`. No `aggregates.json`, `story-latest.md`, `*.jsonl`, or transcript content anywhere under the repo.
3. **AC-6 — Full-corpus coverage:** Compare the `story-latest.md` coverage figure to the Phase-2 spike sample (≥ 95%). A large regression (> 5 pp below the spike) is a halt-and-investigate.

Fill in `tools/transcript-eval/BASELINE.md` with the run metadata after confirming all three.

## Notes

- **Read-only** against `~/.claude/projects/` — the tool never writes to the source transcripts (SF-NFR-1).
- All output lands in the external store; nothing mined is written under the repo.
- An unwritable store path causes a loud non-zero failure with no in-repo fallback (SF-NFR-4).
- Secrets in transcripts are scrubbed before reaching the store (implemented in Phase 2).
