# Applying, Inspecting & Repairing Migrations

Operation: run migrations against an environment and manage the schema history. See [README.md](README.md) for placeholders and [cli-reference.md](cli-reference.md) for arg quoting.

## migrate

Apply all pending migrations to a target.

```bash
flyway migrate -environment=<TestEnv>
flyway migrate -environment=<TestEnv> "-target=<version>"   # stop at a version
```

- Creates the schema + history table if missing, applies each pending script, prints a final "now at version" summary.

## info

Show migration status and history.

```bash
flyway info -environment=<DevEnv>
```

**State values:** `Pending` (not applied) · `Success` · `Baseline` (marker) · `Future` (applied but script now missing) · `Failed` (needs `repair`).

## validate

Check applied migrations match the scripts on disk (checksums, ordering).

```bash
flyway validate -environment=<DevEnv>
flyway validate -environment=<DevEnv> "-ignoreMigrationPatterns=*:pending"   # ignore pending
```

## testConnection

Confirm connectivity to an environment.

```bash
flyway testConnection -environment=<DevEnv>
```

## undo `[teams]`

Undo the most recently applied versioned migration (requires its `U` script).

```bash
flyway undo -environment=<TestEnv>
```

## baseline

Mark an existing, non-empty database at a version so future migrations start after it.

```bash
flyway baseline -environment=<ProdEnv> "-baselineVersion=<version>" "-baselineDescription=<Description>"
```

## repair

Fix the schema history table — remove failed entries and realign checksums after editing a migration. Does not touch your schema objects.

```bash
flyway repair -environment=<DevEnv>
```

## Validate-before-deploy pattern

```bash
flyway info -environment=<TestEnv>        # current state
flyway validate -environment=<TestEnv>    # validate
flyway migrate -environment=<TestEnv>     # apply
```
