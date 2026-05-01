# spec-flow Release Checklist

Authoritative list of all files that must be updated for every spec-flow version bump.
Referenced by NN-C-009 ("consult `releasing.md` before cutting a release").

---

## Files to update (in order)

| # | File | What to change | Added in |
|---|------|---------------|----------|
| 1 | `plugins/spec-flow/plugin.json` | `"version"` field → new version | v2.1.0 (Copilot CLI co-ship) |
| 2 | `plugins/spec-flow/.claude-plugin/plugin.json` | `"version"` field → new version | v1.0.0 (Claude Code descriptor) |
| 3 | `.claude-plugin/marketplace.json` | spec-flow entry `"version"` → new version | v1.0.0 |
| 4 | `plugins/spec-flow/CHANGELOG.md` | Prepend `## [X.Y.Z] — YYYY-MM-DD` section | v1.0.0 |

All four must match exactly. Any drift is a NN-C-009 / NN-C-001 violation.

---

## Quick verification

Run from the repo root after making changes on your branch:

```bash
# All four version strings — must all print the same value
grep '"version"' plugins/spec-flow/plugin.json \
                 plugins/spec-flow/.claude-plugin/plugin.json
python3 -c "
import json
d = json.load(open('.claude-plugin/marketplace.json'))
entry = next(p for p in d['plugins'] if p['name'] == 'spec-flow')
print('marketplace.json:', entry['version'])
"
head -6 plugins/spec-flow/CHANGELOG.md   # should show ## [X.Y.Z] at line 5
```

---

## Why four files?

spec-flow co-ships for two hosts from a single source tree (v2.1.0, PI-007):

- **`plugin.json`** — Copilot CLI descriptor (root of plugin dir, read by `copilot plugin install`)
- **`.claude-plugin/plugin.json`** — Claude Code descriptor (read by `claude plugin install`)
- **`.claude-plugin/marketplace.json`** — root marketplace registry (both hosts discover plugins here)
- **`CHANGELOG.md`** — human-readable release history (Keep a Changelog format)

The `plugin.json` at the plugin root was added in v2.1.0 and is easy to miss because it sits
alongside the `.claude-plugin/` subdirectory rather than inside it. This doc exists because
v3.7.0 was released with that file still at 3.6.0 — caught post-merge.

---

## Sync to installed-plugins

After merging to master, sync the plugin dir to the local installed copy:

```bash
rsync -av --delete \
  /Volumes/joeData/ai-plugins/plugins/spec-flow/ \
  ~/.copilot/installed-plugins/shared-plugins/spec-flow/
```

Verify: `grep '"version"' ~/.copilot/installed-plugins/shared-plugins/spec-flow/plugin.json`

---

## Adding a new version-bearing file in the future

1. Add it to the table above with the version it was introduced.
2. Update NN-C-009's "How QA verifies" list in `docs/charter/non-negotiables.md`.
3. Bump the spec-flow minor version (new capability → minor per NN-C-003).
