# Agent Instructions — ai-plugins

## Plugin Source vs Installed — Never Edit Installed Copies

The spec-flow plugin (and any future plugins) have TWO locations:

| Location | Purpose | Edit? |
|---|---|---|
| `/Volumes/joeData/ai-plugins/plugins/spec-flow/` | **Source of truth** — git-tracked | ✅ YES |
| `/Users/joemontanari/.copilot/installed-plugins/shared-plugins/spec-flow/` | Installed copy — not a git repo, overwritten on reinstall | ❌ NEVER |

**Always verify the path before editing any plugin file.** If a path starts with
`/Users/joemontanari/.copilot/installed-plugins/`, STOP — find the equivalent file
under `/Volumes/joeData/ai-plugins/plugins/` instead.

After edits to source, sync to installed with:
```bash
cp -r /Volumes/joeData/ai-plugins/plugins/spec-flow/ /Users/joemontanari/.copilot/installed-plugins/shared-plugins/spec-flow/
```
