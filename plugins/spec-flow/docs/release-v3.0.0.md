# v3.0.0 release procedure (post-merge)

This document describes the steps the human releaser performs after PI-008-multi-prd-v3.0.0 merges to master. It is the AC-18 deliverable from the plan/execute pipeline; the actual release commit and dog-food run happen at human-driven release time and are verified against AC-18 and AC-15 independent tests.

## 1. Run dog-food migration on master

From `/mnt/c/ai-plugins`:

```bash
git checkout master && git pull
# Remove the stale PI-005 worktree directory if still present (ignore errors if absent)
git worktree remove worktrees/PI-005-copilot-cli-parity-map --force 2>/dev/null || true
# Clean clone for the migration run (avoids touching master directly)
rm -rf /tmp/sf-dogfood-clone
git clone /mnt/c/ai-plugins /tmp/sf-dogfood-clone
cd /tmp/sf-dogfood-clone
git checkout master
git status --porcelain   # must be empty
```

In a separate Claude Code session targeting `/tmp/sf-dogfood-clone`:

```
/spec-flow:migrate shared-plugins --inspect
```

Verify the dry-run plan looks correct, then in the same session:

```
/spec-flow:migrate shared-plugins
```

Confirm the apply prompt; let the migration commit land. Capture the migration commit SHA:

```bash
cd /tmp/sf-dogfood-clone
MIGRATION_SHA=$(git log -1 --pretty=%H)
echo "$MIGRATION_SHA"
```

## 2. AC-15 assertions (verify the migration produced the expected layout + history)

From `/tmp/sf-dogfood-clone`:

```bash
# Target layout exists
[ -f docs/prds/shared-plugins/prd.md ] && \
[ -f docs/prds/shared-plugins/manifest.yaml ] && \
[ -d docs/prds/shared-plugins/specs/PI-008-multi-prd-v3.0.0 ] && \
echo "AC-15 layout: OK"

# History preserved (commits predating the migration commit are visible)
git log --follow --oneline docs/prds/shared-plugins/prd.md | wc -l
# Expect ≥ 2 (the pre-migration history + the migration commit itself)

# MIGRATION_NOTES.md was written
[ -f MIGRATION_NOTES.md ] && grep -q "Files moved" MIGRATION_NOTES.md && echo "AC-14 MIGRATION_NOTES: OK"
```

## 3. Cut the v3.0.0 release commit

The release tag/commit message MUST reference the dog-food run per AC-18:

```
release: spec-flow v3.0.0

Multi-PRD support. Breaking layout change.

Dog-food run: <MIGRATION_SHA>
Target layout: docs/prds/shared-plugins/

<CHANGELOG body excerpt — copy from plugins/spec-flow/CHANGELOG.md [3.0.0] entry>
```

Substitute `<MIGRATION_SHA>` with the SHA captured in Step 1.

## 4. Verify AC-18 post-tag

After tagging, confirm both required references appear in the tag's commit message:

```bash
git log -1 --pretty=%B v3.0.0 | grep "<MIGRATION_SHA>"
# Expect: line containing the dog-food migration SHA

git log -1 --pretty=%B v3.0.0 | grep "docs/prds/shared-plugins"
# Expect: line containing the target layout path
```

Both greps must return their matched lines; either failing means AC-18 is unmet.

## 5. Push tag + release

Use `/release spec-flow` per the release skill's normal workflow.

## Notes

- This document is the AC-18 deliverable for the plan/execute pipeline. The actual release commit happens at human-driven release time.
- AC-15 verification is performed during Step 2 above using the dog-food clone (NOT the production master). This satisfies NN-P-003 (dog-food before recommend): the maintainer runs the documented `/spec-flow:migrate` flow on a real clone of this repo before v3.0.0 ships externally.
- The dog-food run produces no impact on master if executed in `/tmp/sf-dogfood-clone`. Do not run `/spec-flow:migrate` against `/mnt/c/ai-plugins` directly until the release procedure is fully validated.
