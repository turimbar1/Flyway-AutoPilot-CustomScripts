# CLI Reference & Conventions

Rules and patterns that apply to **every** Flyway command. See [README.md](README.md) for placeholders.

## Invocation

```
flyway [options] [command]
flyway help [command]      # per-command help
```

Config is read from `flyway.toml`; command-line options override it. Select an environment with `-environment=<name>`.

## Command index

| Command | Purpose | See |
|---------|---------|-----|
| `migrate` | Apply pending migrations | [applying-migrations.md](applying-migrations.md) |
| `info` | Show status/history | applying-migrations.md |
| `validate` | Validate applied vs on-disk migrations | applying-migrations.md |
| `undo` `[teams]` | Undo last versioned migration | applying-migrations.md |
| `baseline` | Baseline an existing DB at a version | applying-migrations.md |
| `repair` | Fix the schema history table | applying-migrations.md |
| `testConnection` | Test connectivity | applying-migrations.md |
| `clean` | Drop all objects in configured schemas | [environments-and-provisioning.md](environments-and-provisioning.md) |
| `diff` | Summarise differences between two sources | [capturing-changes.md](capturing-changes.md) |
| `diffText` | Detailed text diff | capturing-changes.md |
| `model` | Apply diff changes to the schema model | capturing-changes.md |
| `generate` | Generate a migration from a diff | [generating-migrations.md](generating-migrations.md) |
| `add` | Create an empty migration script | generating-migrations.md |
| `prepare` | Write a deployment script to disk | [deploying-and-drift.md](deploying-and-drift.md) |
| `deploy` | Execute a deployment script | deploying-and-drift.md |
| `snapshot` `[enterprise]` | Capture DB state to a file | deploying-and-drift.md |
| `check` `[enterprise]` | Change/drift/code reports | deploying-and-drift.md |
| `auth` | Authenticate with Redgate licensing | — |
| `version` / `-v` | Print version & edition | — |

## Argument quoting

Any `-key=value` argument **must be quoted** so the shell doesn't split on `=`.

```powershell
# Correct
flyway diff "-diff.source=<DevEnv>" "-diff.target=schemaModel"
# Wrong — will fail
flyway diff -diff.source=<DevEnv> -diff.target=schemaModel
```

Applies to PowerShell and bash alike. `-environment=<name>` (a single token) is generally fine unquoted but quoting is safe.

## Error handling

- Exit code `0` = success; non-zero = failure — check it after every command.
  - PowerShell: `$LASTEXITCODE` · bash: `$?`
- Capture output for inspection:
  - PowerShell: `... 2>&1 | Out-String`
  - bash: `... 2>&1`
- Add `-X` for debug output, `-q` to suppress all but errors/warnings.

## Patterns for AI assistants

**Parse the diff table** (pipe-delimited rows):

```regex
^\|\s*(\S+)\s*\|\s*(\w+)\s*\|\s*([^|]+?)\s*\|\s*(\w+)\s*\|\s*([^|]+?)\s*\|
```
Groups: `changeId, changeType, objectType, schema, objectName`.

**Build a change-ID list** for `-model.changes` / `-generate.changes`:

```powershell
$changeIds = ($changes | ForEach-Object { $_.ChangeId }) -join ','   # "id1,id2,id3"
```

**Exclude dependencies** when acting on specific objects (prevents unrelated changes leaking in):

```
"-redgateCompare.<engine>.options.behavior.includeDependencies=false"
```
