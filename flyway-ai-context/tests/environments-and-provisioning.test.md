# Test: environments-and-provisioning.md

**Context file:** `flyway-ai-context/environments-and-provisioning.md` (sole reference)

**Scenario:** "Before rebuilding it, I need to wipe every object out of my shadow build database, which is registered as the `build` environment. Clean is disabled in the project config for safety. Give me the exact Flyway CLI command."

**Expected:**
- Uses the `clean` command.
- Targets the shadow env: contains `-environment=build`.
- Overrides the safety setting: contains `-cleanDisabled=false`.
- Must NOT run clean against a production environment.
