---
last_updated: 2026-04-21
---

# Processes

How this marketplace and its plugins ship.

## Branching model

- **Model:** Trunk-based (single `master` branch) with optional feature worktrees.
- **Main branch:** `master`
- **Feature branch convention:** `spec/<piece-name>` for spec-flow pieces (managed by the `spec` skill's worktree workflow). Ad-hoc features may use `feat/<short-name>` but no hard rule.
- **Worktrees location:** `worktrees/` (per `.spec-flow.yaml`)

## Review policy

- **Required reviewers:** Single-maintainer self-review for the repo owner's own commits; external contributions via PR with at least one approval.
- **Approval count:** 1 for external PRs.
- **Who can self-merge:** Repo owner (Joe).
- **When review-board runs:** Only for spec-flow's own pieces that go through `/execute` — the 5-agent parallel review fires before final merge. Ad-hoc commits (docs fixes, typo sweeps, charter edits) don't go through review-board.

## Release cadence

- **Frequency:** On-demand per plugin. No fixed cadence.
- **Release branch convention:** None — release is a commit on `master` that bumps `plugin.json` + `marketplace.json` + appends to `CHANGELOG.md`.
- **Release checklist location:** Documented in this file (below).
- **Release protocol:**
  1. Bump `plugins/<plugin>/.claude-plugin/plugin.json` `version`
  2. Update the plugin's entry in `.claude-plugin/marketplace.json` to match
  3. Add a new `## [X.Y.Z] — YYYY-MM-DD` section at the top of `plugins/<plugin>/CHANGELOG.md` per Keep a Changelog
  4. Single commit: `release(<plugin>): vX.Y.Z — <short summary>`
  5. Optional: `git tag <plugin>-vX.Y.Z` for externally-discoverable releases

## CI gates

- **None currently configured.** Changes merge on maintainer judgment + (for spec-flow work) review-board output.
- **Backlog:** minimal CI job enforcing NN-C-001 version-sync as pre-merge check (PI-002).

## Incident response / rollback

- **Rollback procedure:** `git revert <commit-sha>` for ad-hoc commits; for a released version, produce a patch release (`X.Y.Z+1`) that reverts the offending changes rather than deleting history.
- **Oncall runbook:** Not applicable — single-maintainer hobby-scale project; no paging.
- **Post-incident review:** Captured in `docs/backlog/backlog.md` as lessons-learned items.

## Proposal commit workflow (user preference)

- Design specs and implementation plans live in `docs/superpowers/specs/` and `docs/superpowers/plans/` respectively.
- These documents are **held for user review** and **not auto-committed** by any skill or agent.
- Only after the user explicitly reviews and approves does the user commit them (or instruct Claude to commit them).
- Implementation commits (actual file changes the plan prescribes) follow the skill's normal commit cadence.

## External References

- Keep a Changelog: https://keepachangelog.com/en/1.1.0/
- Conventional Commits: https://www.conventionalcommits.org/en/v1.0.0/
