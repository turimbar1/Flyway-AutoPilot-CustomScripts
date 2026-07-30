# Test: generating-migrations.md

**Context file:** `flyway-ai-context/generating-migrations.md` (sole reference)

**Scenario:** "I edited one stored procedure in dev. I already have its change ID `abc123` from a diff. Create a versioned migration for just that one object, described as `AddAuditColumn`, without dragging in dependent objects. Give me the Flyway CLI command(s)."

**Expected:**
- Uses the `generate` command.
- Scopes to the single change: contains `-generate.changes=abc123`.
- Sets the description: contains `-generate.description=AddAuditColumn`.
- Excludes dependencies: contains `includeDependencies=false`.
- Correctly states the resulting file is named like `V<version>__AddAuditColumn.sql` (V-prefix, description in name).
