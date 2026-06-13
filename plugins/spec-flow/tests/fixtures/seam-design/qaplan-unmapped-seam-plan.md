---
charter_snapshot:
  architecture: 2026-01-01
  non-negotiables: 2026-01-01
tdd: true
---
# Plan: qaplan-unmapped-seam (fixture)

## Integration-Test Registry
| integration | registered_in_phase | completes_in_phase | test_file | contract_tests |
|---|---|---|---|---|
| ingest-pipeline→external-http-api | 1 | 2 | tests/test_ingest_integration.py | yes |

---

### Phase 1: Parse ingest data

**ACs covered:** AC-1
**In scope:** src/ingest/parser.py
**Charter constraints honored in this phase:**
- NN-C-001 (additive): Phase 1 only modifies src/ingest/parser.py

- [ ] **[TDD-Red]** Write failing test for parse logic
- [ ] **[QA-Red]** Review test for theater patterns
- [ ] **[Build]** Implement parse logic
  **T-1: MODIFY src/ingest/parser.py**
  - Anchor: `parse_record` function (line 10)
  - Current: stub returning None
  - Target: parse fields from raw input
  - Pattern: `10  def parse_record(raw): return None`
  - Done: `parse_record` returns dict with `id` and `data` keys
- [ ] **[Verify]** `pytest tests/test_parser.py` — Expected: all pass

---

### Phase 2: Integration test (complete seam)

**ACs covered:** AC-2
**In scope:** tests/test_ingest_integration.py
**Charter constraints honored in this phase:**
- NN-C-001 (additive): Phase 2 only adds integration test file

- [ ] **[Write-Tests]** Author integration test skeleton
- [ ] **[Integration-Test]** Complete ingest-pipeline→external-http-api seam
  **T-1: CREATE tests/test_ingest_integration.py**
  - Structure: test class `TestIngestIntegration` with `test_fetch_and_store` using FakeHTTP
  - Done: integration test wires `parser → store` path with FakeHTTP doubled
- [ ] **[Verify]** `pytest tests/test_ingest_integration.py` — Expected: all pass
