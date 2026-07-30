# Scripted Sync Workflow

Operation: automate syncing selected (or all) database objects from development into the schema model *and* into a new migration in one step. This is a generic pattern — wrap it in any script (PowerShell, bash, CI). See [README.md](README.md) for placeholders.

## The pattern

For each target object, chain three commands ([capturing-changes.md](capturing-changes.md) + [generating-migrations.md](generating-migrations.md)):

```bash
# 1. Find changes and their IDs
flyway diff "-diff.source=<DevEnv>" "-diff.target=schemaModel"

# 2. Apply the chosen change IDs to the schema model
flyway model "-model.changes=<changeId>,<changeId>" "-redgateCompare.<engine>.options.behavior.includeDependencies=false"

# 3. Generate a migration for the same changes
flyway diff "-diff.source=<DevEnv>" "-diff.target=migrations" "-diff.buildEnvironment=<ShadowEnv>"
flyway generate "-generate.changes=<changeId>,<changeId>" "-generate.description=<Description>" "-redgateCompare.<engine>.options.behavior.includeDependencies=false"
```

## Typical script inputs

| Input | Purpose |
|-------|---------|
| Object list | Objects in `<Schema>.<Object>` form; map them to change IDs from step 1's diff |
| All | Process every detected change (omit `-*.changes`) |
| Description | Migration description (auto-generate if omitted) |
| Skip-generate | Only update the schema model (steps 1–2) |
| Dry-run | Print the commands/plan without executing |

## Auto-description shape

When no description is supplied, derive a deterministic one:

```
<branch>_<ChangeType>_<Schema>_<Object>_<username>
```

Example form: `main_Edit_<Schema>_<Object>_<username>`.

## Rules

- Always pass `includeDependencies=false` in `model`/`generate` so syncing one object doesn't drag in unrelated dependents.
- Build the change-ID list by parsing the diff table (see [cli-reference.md](cli-reference.md)).
- Check the exit code after each command and stop the chain on failure.
