# shared-plugins

A Claude Code plugin marketplace. One repository, one or more plugins, installable through the standard plugin marketplace mechanism.

## Plugins

| Plugin | Description |
|---|---|
| [**spec-flow**](./plugins/spec-flow) | PRD-to-code pipeline with TDD agents, adversarial QA gates, and PRD traceability. Turns requirements docs into shipped, reviewed code through a chain of skills (`/prd`, `/spec`, `/plan`, `/execute`, `/status`) and specialized subagents. |

## Installing

Add this marketplace to Claude Code:

```bash
claude plugin marketplace add <git-url-for-this-repo>
```

Then install a plugin:

```bash
claude plugin install spec-flow
```

Plugin-specific documentation lives in each plugin's directory — see [`plugins/spec-flow/README.md`](./plugins/spec-flow/README.md) for the full design, pipeline overview, and usage walkthrough.

## Repository layout

```
.
├── .claude-plugin/
│   └── marketplace.json   # Marketplace manifest (lists all plugins)
└── plugins/
    └── spec-flow/         # One plugin per directory
        ├── .claude-plugin/
        │   └── plugin.json
        ├── skills/
        ├── agents/
        ├── templates/
        ├── reference/
        ├── hooks/
        └── README.md
```

## Adding a new plugin

1. Create `plugins/<your-plugin>/` with its own `.claude-plugin/plugin.json`.
2. Add an entry to `.claude-plugin/marketplace.json` under `plugins`.
3. Bump the plugin's `version` field on each release.

## License

MIT (per-plugin — see each plugin's `plugin.json`).
