# Test: cli-reference.md

**Context file:** `flyway-ai-context/cli-reference.md` (sole reference)

**Scenario:** "In a PowerShell script I run `flyway migrate` for my `test` environment and I need to reliably detect whether it failed and stop. Also, a teammate's `flyway diff -diff.source=dev -diff.target=schemaModel` keeps failing to parse — why? Answer both."

**Expected:**
- For failure detection: check the exit code, and names `$LASTEXITCODE` (non-zero = failure) in PowerShell.
- For the parse failure: explains that `-key=value` arguments must be quoted, and shows the corrected quoted form (e.g. `"-diff.source=dev" "-diff.target=schemaModel"`).
