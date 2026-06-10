tdd: true

### Phase 1 — greet behavior [TDD]

- [x] **[TDD-Red]** Write failing test for greet core behavior.

    **Test Data:**
    - g-1: input "world" → expect "hello, world"

    **[Verify]** `bash tests/test-greet.sh` → exit 0

### Phase 2 — config wiring [Implement]

- [x] **[Implement]** Write `src/config.txt` with `greet_suffix` key.

    **[Verify]** `grep -q greet_suffix src/config.txt` → exit 0

### Phase 3 — spike-resolved suffix [TDD]

- [x] **[TDD-Red]** Write failing test for spike-resolved suffix.

    Deliverable spike marker (resolved):
    ```
    [SPIKE: greet suffix value]
    ```
    resolved-42

    **Test Data:**
    - rt-1: input "spike" → expect "resolved-42"

    **[Verify]** `bash tests/test-greet.sh` → exit 0

### Phase 4 — edge behavior [TDD]

- [x] **[TDD-Red]** Write failing test for additional greet edge case.

    **Test Data:**
    - e-1: input "there" → expect "hello, there"

    **[Verify]** `bash tests/test-greet.sh` → exit 0
