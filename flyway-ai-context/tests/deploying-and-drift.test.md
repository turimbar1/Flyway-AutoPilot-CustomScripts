# Test: deploying-and-drift.md

**Context file:** `flyway-ai-context/deploying-and-drift.md` (sole reference)

**Scenario:** "Before deploying, I want a deployment script written to a file so my team can review it — generated from the migrations against our `prod` environment — and I do NOT want it executed yet. Give me the Flyway CLI command."

**Expected:**
- Uses the `prepare` command (NOT `deploy`/`migrate`).
- Source is migrations: contains `-prepare.source=migrations`.
- Target is prod: contains `-prepare.target=prod`.
- Writes to a script file: contains `-prepare.scriptFilename=` (e.g. `deploy.sql`).
- Makes clear nothing is executed / applied by this step.
