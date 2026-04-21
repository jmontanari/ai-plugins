---
last_updated: {{date}}
---

# Tools

The toolchain this project uses. Binding: implementer agents must not introduce alternatives without updating this file first.

## Language(s) and runtime

- **Primary:** {{language}} {{version}}
- **Secondary** (if any): {{language}} {{version}}

## Frameworks

- {{framework}} {{version}} — {{purpose}}

## Test runner & coverage

- **Runner:** {{test_runner}}
- **Coverage tool:** {{coverage_tool}}
- **Target coverage:** {{target_percentage}} (measured how: {{measurement}})

## Linter & formatter

- **Linter:** {{linter}} — config at `{{config_path}}`
- **Formatter:** {{formatter}} — config at `{{config_path}}`

## Package manager

- {{package_manager}} {{version}} — lockfile at `{{lockfile_path}}`

## CI platform

- {{ci_platform}} — pipeline source of truth: `{{pipeline_config_path}}`

## Approved third-party libraries

Libraries pre-approved for use without additional review.

- {{library}} — {{purpose}}

## Banned libraries (if any)

Libraries explicitly forbidden. Implementer agents must BLOCK if a task requires one.

- {{library}} — Reason: {{why_banned}} — Alternative: {{approved_alternative}}
