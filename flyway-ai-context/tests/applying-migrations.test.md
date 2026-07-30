# Test: applying-migrations.md

**Context file:** `flyway-ai-context/applying-migrations.md` (sole reference)

**Scenario:** "A migration failed halfway on my `test` environment and the history table now has a failed entry. I fixed the script. What Flyway command clears the failed entry and realigns checksums so I can migrate again — and does it change my actual tables?"

**Expected:**
- Recommends the `repair` command.
- Targets test: contains `-environment=test`.
- States that repair fixes the schema history table only and does NOT alter/drop schema objects.
