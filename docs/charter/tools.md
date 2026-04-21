---
last_updated: 2026-04-21
---

# Tools

The toolchain for the `shared-plugins` marketplace. Implementer agents must not introduce alternatives without updating this file first.

## Language(s) and runtime

- **Primary:** Markdown (content) + YAML (config) + JSON (manifests) + POSIX Bash 4+ (hooks only)
- No compiled languages. No interpreted runtimes beyond the shell.

## Frameworks

- None. This is a plain-file marketplace. Plugins are content + config consumed by Claude Code at runtime.

## Test runner & coverage

- **Runner:** None. No test suite exists; verification is:
  1. **Adversarial review** by spec-flow's own QA agents (self-hosted dogfooding)
  2. **Manual smoke tests** of hooks and skills before committing
  3. **Session reload (`/reload-plugins`)** + manual invocation on a scratch project
- **Coverage tool:** Not applicable.
- **Target coverage:** Not applicable.

## Linter & formatter

- **Linter:** None enforced. Markdown is free-form within its structural requirements (frontmatter, section headings).
- **Formatter:** None enforced.

## Package manager

- None. No dependencies.

## CI platform

- **None currently configured.** Verification is manual + review-by-humans + spec-flow self-review when changes go through its own pipeline.
- **Backlog item:** consider adding a minimal CI check for NN-C-001 version-sync (`jq`-based shell assertion) — tracked as PI-002.

## Approved third-party libraries

None. Plugins are self-contained.

## Banned libraries (if any)

- **Runtime dependencies of any kind** — bans all `npm`, `pip`, `cargo`, `go get`, etc., per NN-C-002. Requires explicit exception documented in `non-negotiables.md` to lift.
