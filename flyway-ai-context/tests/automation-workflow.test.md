# Test: automation-workflow.md

**Context file:** `flyway-ai-context/automation-workflow.md` (sole reference)

**Scenario:** "I want to script syncing a single changed object from my `dev` database into BOTH the schema model and a new migration in one pass, using the shadow env `build` to compare migrations. Outline the ordered Flyway commands the script should run."

**Expected:**
- Lists the three-step chain in order: `diff` (source=dev, target=schemaModel) → `model` → `diff` against migrations (with `-diff.buildEnvironment=build`) → `generate`.
- Includes `includeDependencies=false` on the `model` and `generate` steps.
- Mentions the auto-description shape `<branch>_<ChangeType>_<Schema>_<Object>_<username>` OR that a description is passed to generate.
- Mentions checking exit code / stopping the chain on failure.
