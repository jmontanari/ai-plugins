# timestamp-hooks

A Claude Code plugin that injects send and receive timestamps into each conversation turn, with elapsed time shown on the response side.

## Output format

```
→ 19:01:32
← 19:02:14 (42s)
← 19:02:14 (1m 2s)
← 19:02:14
```

- `→ HH:MM:SS` — emitted when you send a message
- `← HH:MM:SS (Xs)` — emitted when Claude finishes, with elapsed seconds
- `← HH:MM:SS (Nm Xs)` — elapsed time formatted as minutes and seconds for responses over 60 seconds
- `← HH:MM:SS` — emitted when no start record exists for the session

## Installation

Install via the Claude Code plugin manager, pointing it at `plugins/timestamp-hooks`. The plugin manager reads `plugins/timestamp-hooks/plugin.json` and wires the hooks from `plugins/timestamp-hooks/.claude-plugin/hooks.json` into your Claude Code hooks configuration.

After installing via the plugin manager, activate by adding the following to `enabledPlugins` in your `~/.claude/settings.json`:

```json
"timestamp-hooks@shared-plugins": true
```

## Hook scripts

| Script | Event | Location |
|---|---|---|
| ts-start.sh | UserPromptSubmit | `plugins/timestamp-hooks/hooks/ts-start.sh` |
| ts-stop.sh | Stop | `plugins/timestamp-hooks/hooks/ts-stop.sh` |

## State file location

Session state is written to `~/.claude/timestamp-hooks/`. Each active session creates a file named `<session_id>.start` containing a Unix epoch integer. The Stop hook reads and removes the file after computing elapsed time.

## Runtime dependencies

None. Both scripts require only POSIX bash and the system `date` command — no jq, Python, or Node.js.
