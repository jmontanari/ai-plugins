tdd: true

### Phase 1 — greet behavior [TDD]

- [ ] **[TDD-Red]** Write failing test for greet core behavior.

    **Test Data:**
    - g-1: input "world" → expect "hello, world"

    **[Verify]** `bash tests/test-greet.sh` → exit 0

### Phase 2 — config wiring [Implement]

- [ ] **[Implement]** Write `src/config.txt` with `greet_suffix` key.

    **[Verify]** `grep -q greet_suffix src/config.txt` → exit 0

### Phase 3 — spike-resolved suffix [TDD]

- [ ] **[TDD-Red]** Write failing test for spike-resolved suffix.

    Deliverable spike marker (resolve before coding):
    ```
    [SPIKE: greet suffix value]
    ```

    **[Verify]** `bash tests/test-greet.sh` → exit 0

### Phase 4 — edge behavior [TDD]

- [ ] **[TDD-Red]** Write failing test for additional greet edge case.

    **[Verify]** `bash tests/test-greet.sh` → exit 0
