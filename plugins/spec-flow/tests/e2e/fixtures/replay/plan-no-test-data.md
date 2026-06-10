# plan.md — demo/hello

tdd: true

### Phase 1 — greet implementation [TDD]

[SPIKE: greet suffix value]
routed-resolution: resolved at execute by spike-agent

- [ ] **[TDD-Red]** Write failing test for greet behavior.

    **[Verify]** `bash tests/test-greet.sh` → exit 0

### Phase 2 — config wiring [Implement]

- [ ] **[Implement]** Wire `src/config.txt` with `greet_suffix` key.

    **[Verify]** `grep -q greet_suffix src/config.txt` → exit 0
