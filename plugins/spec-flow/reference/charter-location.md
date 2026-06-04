# Charter Location Resolution

Charter is published as a set of **skill files**, one per domain, under a host-native skills
root. Two roots are supported and treated as equivalent:

- `.github/skills/charter-<domain>/SKILL.md` — GitHub / Copilot CLI convention
- `.claude/skills/charter-<domain>/SKILL.md` — Claude Code convention

A project uses **exactly one** root. This file is the single source of truth for how every
spec-flow skill resolves that root — both for **reading** existing charter and for **choosing
where to write** new charter. There is **no** `docs/charter/` directory (the pre-v4 layout is
not supported).

In the procedures below, the resolved root is written `<charter_root>` (either `.github` or
`.claude`), the charter directory is `<charter_root>/skills`, and an individual domain file is
`<charter_root>/skills/charter-<domain>/SKILL.md`.

---

## Reading — resolve the active charter root

Any skill that reads charter (`status`, `intake`, `spec`, `plan`, `execute`, `review-board`,
`charter --update`) resolves the location in this order:

1. **Explicit config.** If `.spec-flow.yaml` sets `charter_root:` (`.github` or `.claude`), use
   `<charter_root>/skills/charter-*/SKILL.md`.
2. **Detect by existence.** Otherwise, glob for charter skills under each root and use whichever
   one actually contains `charter-*/SKILL.md` files:
   - `.claude/skills/charter-*/SKILL.md`
   - `.github/skills/charter-*/SKILL.md`
3. **Both present (misconfiguration).** If both roots contain charter skills, prefer the one
   named by `charter_root` if set; otherwise prefer `.claude/skills/`, then `.github/skills/`,
   and surface a one-line note recommending the user consolidate to a single root.
4. **Neither present.** There is no charter (a pre-charter project). Skills that require charter
   (`charter.required: true` in `.spec-flow.yaml`) prompt the user to run `/spec-flow:charter`;
   skills that merely cite charter degrade gracefully (no project-level NN-C/CR available).

Resolution is read-only and never writes `charter_root`.

---

## Writing — choose a root for new charter

When `/spec-flow:charter` bootstraps a charter and no root is yet established (no `charter_root`
in config and no existing `charter-*/SKILL.md` under either root), choose the destination by
**detecting which host directories already exist** — never by assuming a default.

1. **Detect host directories** present at the repo root (any content counts):
   - `.github/` present → GitHub / Copilot signal
   - `.claude/` present → Claude Code signal
2. **Recommend** based on what was found, and tell the user what was detected:
   - Only `.github/` exists → recommend `.github/skills/charter-*/`.
   - Only `.claude/` exists → recommend `.claude/skills/charter-*/`.
   - **Both** exist → present both and ask the user to choose (no auto-pick).
   - **Neither** exists → ask the user to choose (no auto-pick, no default).
3. **Example prompts:**
   - One detected:
     > "Detected a `.github/` directory in this project — recommend writing charter skills to
     > `.github/skills/charter-*/`. Use this location? (yes / use `.claude` instead)"
   - Neither detected:
     > "No `.github/` or `.claude/` directory found. Where should charter skills live —
     > `.github/skills/` or `.claude/skills/`?"
4. **Persist the choice.** After the user confirms, write `charter_root: .github` (or `.claude`)
   to `.spec-flow.yaml` so every downstream skill resolves the same location without re-detecting
   or re-prompting. Create `<charter_root>/skills/charter-<domain>/` as needed and write each
   domain's `SKILL.md` there.

`charter --update` operates on the already-resolved root (Reading rules above); it does not
re-prompt for a location.

---

## `charter_root` key

`.spec-flow.yaml`:

```yaml
charter_root: .claude    # .github | .claude — where charter skills live; written by /spec-flow:charter
```

When `charter_root` is absent, readers fall back to detection (Reading step 2). Setting it is
recommended for determinism and to disambiguate the both-present case.
