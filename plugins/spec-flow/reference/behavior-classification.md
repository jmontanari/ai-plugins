# Behavior Classification

Single source of truth for piece-level behavioral status and outcome facet definitions.
Every gate that reads `piece_class` or matches AC-line tags (`[mechanism]`, `[outcome:result]`,
`[outcome:integration]`) derives its token literals from this document.

## Piece classification

Classification is decided **at piece granularity** during spec authoring — before planning begins.

- **`behavior-bearing`** — the piece's deliverable produces or transforms output a consumer
  depends on. A wrong value, a missing result, or a wired-but-broken path is observable
  by a user or downstream system.
- **`non-behavioral`** — the piece's deliverable is configuration, glue, scaffolding, or
  docs-as-code whose correctness is structural, not output-bearing. There is no runtime
  output that a consumer could receive the wrong value of.

**Ambiguity rule:** When piece classification is genuinely ambiguous, default to `behavior-bearing`.

**Front-matter keys:**

```yaml
piece_class: behavior-bearing | non-behavioral
behavior_rationale: {{required only when non-behavioral}}
```

`behavior_rationale` is required when `piece_class: non-behavioral`; it is omitted for
`behavior-bearing` pieces. The absence of `piece_class` entirely signals a legacy spec
predating this classification scheme — gates treat that as an exempt/skip condition.

## Outcome facets

Behavior-bearing specs must address negative space across two facets. Each facet targets a
distinct failure mode.

- **`result`** — the running system's output values or content. An unacceptable result is a
  wrong value that reaches a consumer: "$0 masquerading as an earned result", a truncated
  record, a stale timestamp presented as current. The `result` facet asks: what value could
  this produce that would be unacceptable even if the code ran without errors?

- **`integration`** — the seams are plumbed and wired; the e2e path produces a real result,
  not a fixture; nothing is stubbed; no glue is missing. The `integration` facet asks: what
  could be left unwired, stubbed, or not actually plumbed so the e2e path silently short-circuits
  rather than exercising the real implementation?

For each facet, a behavior-bearing spec must carry at least one AC whose AC-line tag is
`[outcome:<facet>]`, or a per-facet N/A sentinel (see glossary below).

## Canonical token glossary

Exactly one of the following tags appears on every `AC-N:` line (case-sensitive, exact literal):

- `[mechanism]` — the AC asserts construction ("returns X", "writes row Y"). It states HOW
  the feature is built, not WHAT unacceptable value it must never produce.
- `[outcome:result]` — the AC states an unacceptable output value or content that the system
  must never produce (result facet).
- `[outcome:integration]` — the AC states a seam that must be wired/plumbed end-to-end (integration facet).

**Per-facet N/A sentinel form** (exact literal, case-sensitive):

```
Outcome N/A [outcome:<facet>]: <reason>
```

Example: `Outcome N/A [outcome:result]: this piece emits no runtime output values.`

**Matching rules:** Tags are exact-literal and case-sensitive. `[Outcome:result]`, `[MECHANISM]`,
or any variant does NOT match. A mis-cased or mis-spelled tag fails safe — it is treated as
if the tag is absent.

## Relationship to `spec-flow-doctrine.md`

This document is the **piece-level spec-time** classifier: it defines whether a whole piece
is behavior-bearing or non-behavioral, and what outcome facets a behavior-bearing spec must
address before QA sign-off. `spec-flow-doctrine.md` line 179 is the **phase-level plan-time**
TDD-track default — it governs which implementation track (TDD vs Implement) a plan phase
uses. The two concerns operate at different stages and different granularities; this document
does not modify, extend, or supersede `spec-flow-doctrine.md` line 179.

## Boundary-touching predicate

Applies to `behavior-bearing` pieces at spec time. Classifies the piece's relationship to
integration boundaries into three states:

- **boundary-touching** — the piece's implementation wires, calls, or extends a seam across
  an integration boundary (a real external, a cross-component call, a filesystem, a network
  service, a database). These pieces MUST declare their integrations in `## Integration Coverage`
  OR record an `integration_rationale` front-matter exemption.
- **non-boundary** — the piece's implementation does not cross an integration boundary at
  runtime (it may edit markdown, configuration, or static files; it may not call external
  services or wire components). These pieces MAY declare `integration_rationale: <reason>`
  to make the non-boundary claim explicit.
- **ambiguous** — the boundary-touching status is genuinely unclear. Default to
  `boundary-touching`.

**judgment-backstopped caveat:** This predicate is evaluated at spec time from the author's
knowledge of the piece's intended implementation. It is not deterministically verifiable from
static analysis. Gates that apply this predicate challenge non-boundary claims they judge
inconsistent with the piece's FRs. Rationale PRESENCE (not correctness) is the deterministic
clean state for gates.

**Front-matter key:**

```yaml
integration_rationale: {{required only when behavior-bearing AND the piece declares it touches no integration boundary}}
```

`integration_rationale` is the exemption rationale — it explains why a `behavior-bearing`
piece that declares no integrations genuinely touches no boundary. It is omitted when the
piece declares ≥1 integration (the integration block is its own evidence). The
`behavior_rationale` parallel is explicit: just as `behavior_rationale` is the exemption for
non-behavioral pieces, `integration_rationale` is the exemption for non-boundary
behavior-bearing pieces.

For the production-call-site pointer convention that applies to declared integrations, see
`spec-flow-doctrine.md` §Integration Tests & Path Coverage.
