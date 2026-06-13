---
charter_snapshot:
  architecture: 2026-01-01
  non-negotiables: 2026-01-01
tdd: true
---
# Plan: clean-correct (fixture)

## Integration-Test Registry
| integration | registered_in_phase | completes_in_phase | test_file | contract_tests |
|---|---|---|---|---|
| report-pipeline→archive-service | 1 | 2 | tests/test_report_integration.py | yes |

---

### Phase 1: Implement formatter and exporter

**ACs covered:** AC-1, AC-2 (partial — wiring phase)
**In scope:** src/report/formatter.py, src/report/exporter.py
**Charter constraints honored in this phase:**
- NN-C-001 (additive): Phase 1 only adds new production source files

- [ ] **[TDD-Red]** Write failing test for formatter
- [ ] **[QA-Red]** Review test for theater patterns
- [ ] **[Build]** Implement formatter and exporter
  **T-1: CREATE src/report/formatter.py**
  - Structure: `format_data(records) -> list[str]` formatting each record as `"id: value"`
  - Done: `format_data` returns list of formatted strings
  **T-2: CREATE src/report/exporter.py**
  - Anchor: new file
  - Structure: `export_archive(data, client)` at line 22 — calls `client.submit(data)` to push to the archive service
  - Done: `export_archive` at `src/report/exporter.py:22` wires report data to ArchiveService client
- [ ] **[Verify]** `pytest tests/test_formatter.py tests/test_exporter.py` — Expected: all pass

---

### Phase 2: Integration test (complete seam)

**ACs covered:** AC-2 (completes seam)
**In scope:** tests/test_report_integration.py, tests/test_archive_contract.py
**Charter constraints honored in this phase:**
- NN-C-001 (additive): Phase 2 only adds integration and contract test files

- [ ] **[Write-Tests]** Author integration test skeleton
- [ ] **[Integration-Test]** Complete report-pipeline→archive-service seam
  **T-1: CREATE tests/test_report_integration.py**
  - Structure: `TestReportIntegration.test_export_pipeline` — wires `formatter.format_data` → `exporter.export_archive` → FakeArchive (contract-tested double)
  - Done: integration test exercises the real `src/report/exporter.py` call site with FakeArchive
  **T-2: CREATE tests/test_archive_contract.py**
  - Structure: contract test verifying FakeArchive faithfully implements the ArchiveService `.submit()` interface
  - Done: contract test present for the doubled external
- [ ] **[Verify]** `pytest tests/test_report_integration.py tests/test_archive_contract.py` — Expected: all pass
