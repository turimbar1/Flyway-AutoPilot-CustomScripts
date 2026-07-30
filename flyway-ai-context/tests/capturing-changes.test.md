# Test: capturing-changes.md

**Context file:** `flyway-ai-context/capturing-changes.md` (sole reference)

**Scenario:** "I changed some stored procedures directly in my `dev` database. I want to see which objects differ from the schema model folder before I do anything else. Give me the Flyway CLI command."

**Expected:**
- Uses the `diff` command.
- Source is the dev database: contains `-diff.source=dev`.
- Target is the schema model: contains `-diff.target=schemaModel`.
- Arguments are quoted (each `-diff....` wrapped in quotes).
