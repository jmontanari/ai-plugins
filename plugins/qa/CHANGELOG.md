# Changelog

All notable changes to the **qa** plugin are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — [Semantic Versioning](https://semver.org/)

## [1.1.1] — 2026-05-14

### Fixed
- Renamed `hooks/hooks.json` to `hooks/copilot-hooks.json` so Claude Code no longer auto-discovers and validates the Copilot CLI hooks file (which uses camelCase event names). Resolves "Hook load failed: Invalid key in record" error on Claude Code startup.

## [1.1.0] — 2026-05-06

### Added
- Claude Code dual-platform support: `.claude-plugin/plugin.json` manifest and `CLAUDE.md`
- Agent symlink convention: `validator-agent.agent.md → validator-agent.md` for Copilot CLI discovery

### Changed
- Audited and updated skill/agent content to current dual-platform format and content standards
- `validator-agent` description sharpened for accurate host invocation

## [1.0.0] — 2026-02-13

### Added
- Initial release: `qa-validate`, `qa-spot-check`, `qa-attack-plan` skills
- `validator-agent` subagent — paranoid adversarial 4-dimension assessment (MISSING / BROKEN / FRAGILE / EXPLOITABLE)
- Copilot CLI `plugin.json` manifest and skill registration
- Migrated to official Claude Code plugin marketplace format
- Fixed skill names for plugin namespace compatibility (`qa:validate`, `qa:spot-check`, `qa:attack-plan`)
