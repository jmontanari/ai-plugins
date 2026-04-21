---
last_updated: 2026-04-21
---

# Flows

Dynamic behavior of the marketplace + plugin system. Agents designing or modifying plugins must respect these paths.

## Plugin install flow

```
user runs: claude plugin marketplace add <git-url>
  → Claude Code clones/caches the marketplace repo
  → reads .claude-plugin/marketplace.json
  → lists plugins by name

user runs: claude plugin install <plugin-name>
  → Claude Code resolves the plugin entry in marketplace.json
  → follows the `source` path (relative to repo root)
  → registers plugin with harness (skills, agents, hooks become available)
  → fires any install-time hook (if declared)

user starts a session:
  → SessionStart hook(s) fire
  → plugin's `hooks/session-start` script outputs additionalContext
  → Claude Code injects that context into the system prompt
```

## Session-start flow (spec-flow's hook, representative)

```
SessionStart event
  ├─ read .spec-flow.yaml (or copy template if missing)
  ├─ read reference/spec-flow-doctrine.md
  ├─ if docs/charter/ exists and config's charter.doctrine_load is non-empty:
  │    └─ read each listed charter file and append to session context
  ├─ JSON-escape the composed context string
  └─ emit {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}
```

Every missing optional input silently no-ops (NN-C-005).

## Skill invocation flow

```
user types: /plugin:skill <args>
  → Claude Code locates plugins/<plugin>/skills/<skill>/SKILL.md
  → reads frontmatter (name, description, allowed-tools)
  → injects SKILL.md content into Claude's context
  → Claude follows the skill's instructions sequentially
  → skill may dispatch subagents via Agent tool
  → skill may read/write files, run commands, call other tools
  → skill reports completion to user
```

## Agent dispatch flow (from within a skill)

```
skill composes agent prompt:
  → reads plugins/<plugin>/agents/<agent>.md
  → interpolates orchestrator-injected context (Mode flag, pre-flight
    snapshot, oracle anchors, AC matrix, charter entries)
  → Agent tool call with: description, prompt, model, optional subagent_type

fresh Claude instance handles the prompt:
  → no memory of orchestrator conversation (NN-C-008)
  → executes the task
  → returns a structured report

orchestrator (the skill):
  → parses the report
  → decides: proceed / retry / escalate
  → commits state changes to git (if applicable)
```

## Release flow (per NN-C-001 + processes.md release protocol)

```
maintainer decides version bump (semver)
  ├─ edit plugins/<plugin>/.claude-plugin/plugin.json → new version
  ├─ edit .claude-plugin/marketplace.json → matching version
  ├─ prepend new section to plugins/<plugin>/CHANGELOG.md
  ├─ git commit -m "release(<plugin>): v<X.Y.Z> — <summary>"
  └─ (optional) git tag <plugin>-v<X.Y.Z>
```

Version-drift (plugin.json ≠ marketplace.json) violates NN-C-001 and is caught at next charter-aware QA gate.

## External References

- Plugin manifest schema: https://docs.claude.com/en/docs/claude-code/plugins
- `plugins/spec-flow/README.md` — full spec-flow pipeline flow diagrams (charter → prd → spec → plan → execute → merge)
