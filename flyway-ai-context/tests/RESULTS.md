# Usability Test Results

Method: each test spawns a **Claude Haiku** subagent given **only** the one target context file (verbatim) plus the scenario, with no repo access. The emitted command is checked against the spec's `Expected:` assertions. See each `*.test.md` for the scenario/assertions.

| # | Context file | Scenario | Result | Emitted answer (summary) |
|---|--------------|----------|--------|--------------------------|
| 1 | capturing-changes.md | See diff between dev DB and schema model | ✅ PASS | `flyway diff "-diff.source=dev" "-diff.target=schemaModel"` |
| 2 | generating-migrations.md | Migration for one change `abc123`, desc `AddAuditColumn`, no deps | ✅ PASS | `flyway generate "-generate.changes=abc123" "-generate.description=AddAuditColumn" "...includeDependencies=false"`; file `V<version>__AddAuditColumn.sql` |
| 3 | environments-and-provisioning.md | Clean shadow env `build` with clean disabled | ✅ PASS | `flyway clean -environment=build "-cleanDisabled=false"` |
| 4 | applying-migrations.md | Clear failed history entry on `test`; does it touch tables? | ✅ PASS | `flyway repair -environment=test`; correctly stated it does NOT alter schema objects |
| 5 | deploying-and-drift.md | Write reviewable script from migrations vs `prod`, don't run it | ✅ PASS | `flyway prepare "-prepare.source=migrations" "-prepare.target=prod" "-prepare.scriptFilename=deploy.sql"`; confirmed nothing executed |
| 6 | cli-reference.md | Detect failure in PowerShell + fix unquoted-arg parse error | ✅ PASS | Checks `$LASTEXITCODE -ne 0`; quotes `-key=value` args |
| 7 | automation-workflow.md | Order the diff→model→diff→generate sync chain (shadow `build`) | ✅ PASS | Correct 4-command order incl. `-diff.buildEnvironment=build`, `includeDependencies=false`, exit-code checks, auto-desc |

**Summary: 7 / 7 passed.** Each file is self-sufficient — a model with only that file produced the correct, correctly-quoted command and honored the key gotchas (dependency exclusion, non-destructive repair, non-executing prepare). No revisions required.

To re-run: feed each `*.test.md`'s context file + scenario to a Haiku agent (model `haiku`) as the sole reference and re-check the assertions.
