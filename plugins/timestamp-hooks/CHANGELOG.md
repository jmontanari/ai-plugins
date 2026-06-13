# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-13

### Added

- `hooks/ts-start.sh` — UserPromptSubmit hook that records the session start epoch and emits a formatted start timestamp as a system message
- `hooks/ts-stop.sh` — Stop hook that computes elapsed time since the start epoch and emits a formatted receive timestamp (with elapsed time) as a system message
- `plugin.json` — plugin manifest declaring name, version, author, license, and hooks pointer
- `.claude-plugin/hooks.json` — hook wiring for UserPromptSubmit and Stop events
- `README.md` — installation guide, output format reference, and state file documentation
- `CLAUDE.md` — in-conversation reference for hook events, output format, and runtime dependencies
