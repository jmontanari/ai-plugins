# timestamp-hooks

A Claude Code plugin that shows send and receive timestamps alongside the elapsed time for each message exchange. Timestamps appear as system messages injected into each conversation turn.

## What it does

On every message you send, the plugin records the current time and displays a send timestamp. When Claude finishes responding, it displays a receive timestamp and the elapsed seconds (or minutes and seconds for longer responses).

Example output:

```
→ 19:01:32
← 19:02:14 (42s)
← 19:02:14 (1m 2s)
← 19:02:14
```

The final form (no elapsed time) appears when no matching start record is found for the session.

## How to install

Install via the Claude Code plugin manager pointing at this plugin's directory. The plugin manager will wire the hooks defined in `.claude-plugin/hooks.json` into your Claude Code hooks configuration automatically.

## Hook events

- `UserPromptSubmit` — runs `hooks/ts-start.sh`, records start epoch, emits the send timestamp
- `Stop` — runs `hooks/ts-stop.sh`, computes elapsed time, emits the receive timestamp

## State files

Session state is stored under `~/.claude/timestamp-hooks/` as `<session_id>.start` files. Each file holds a Unix epoch integer and is removed after the Stop hook reads it.

## Runtime dependencies

None. Both hook scripts use only POSIX bash and the system `date` command.
