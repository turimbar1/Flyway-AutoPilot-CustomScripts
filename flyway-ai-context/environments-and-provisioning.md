# Environments & Provisioning

Operation: define connections, set up provisioners, reset a build database, and the core `flyway.toml` settings. See [README.md](README.md) for placeholder conventions.

## Environments

An *environment* is a named connection defined in `flyway.toml`. Reference one on any command with `-environment=<name>`. Typical roles:

| Role | Purpose |
|------|---------|
| `<DevEnv>` | Development DB — source of truth for changes |
| `<ShadowEnv>` | Shadow/build DB — rebuilt to validate migrations |
| `<TestEnv>` / `<ProdEnv>` | Downstream deployment targets |
| `schemaModel` | File-based schema (a folder, not a DB) |
| `migrations` | The versioned migration scripts (a folder) |

```toml
[environments.<DevEnv>]
url = "<jdbc-url>"          # engine-specific, see below
user = "<user>"
password = "${localSecret.<Key>}"
```

**jdbc URL by engine** (substitute `<HOST>`/`<PORT>`/db name):
- `sqlserver`: `jdbc:sqlserver://<HOST>:<PORT>;databaseName=<Db>;trustServerCertificate=true`
- `postgresql`: `jdbc:postgresql://<HOST>:<PORT>/<Db>`
- `oracle`: `jdbc:oracle:thin:@<HOST>:<PORT>/<Service>`
- `mysql`: `jdbc:mysql://<HOST>:<PORT>/<Db>`

## Provisioners

A provisioner controls how an environment's database is (re)created before use. Set `provisioner = "<type>"` under the environment.

| Type | Behaviour |
|------|-----------|
| `clean` | Cleaned automatically before ops like `check`. Manual clean needs `-cleanDisabled=false`. |
| `create-database` | Created if it doesn't exist |
| `backup` | `[enterprise]` Restore from a backup file (`.bak` SQL Server / `.dmp` Oracle) |
| `snapshot` | `[enterprise]` Provision from a Flyway snapshot file |
| `docker` | Provision via a Docker container |
| `redgate-clone` | Provision via Redgate Clone |
| (none) | No auto-provisioning; managed manually |

## clean

Drops all objects in the configured schemas. Destructive.

```bash
flyway clean -environment=<ShadowEnv> "-cleanDisabled=false"
```

- Projects usually set `cleanDisabled = true` for safety; override with `-cleanDisabled=false`.
- Environments with `provisioner = "clean"` are cleaned automatically during `check`.
- **Gotcha:** never run against `<ProdEnv>`.

## Reset & rebuild a build/shadow database

```bash
flyway clean -environment=<ShadowEnv> "-cleanDisabled=false"
flyway migrate -environment=<ShadowEnv>
flyway info -environment=<ShadowEnv>
```

## backup provisioner `[enterprise]`

Restores a DB from a backup instead of running every migration — faster for large histories, and can carry static data plus the `flyway_schema_history` table.

```toml
[environments.<ShadowEnv>]
provisioner = "backup"

[environments.<ShadowEnv>.resolvers.backup]
backupFilePath = '<path-accessible-to-DB-server>'   # .bak / .dmp
backupVersion  = "<version>"                          # last migration the backup represents
```

- `backupFilePath` (required) must be reachable by the **database server**, not just the client.
- `backupVersion` (optional) — Flyway baselines here, then applies later migrations. Required if the backup has no history table.
- Restore to v995 instantly, then only apply migrations 996+.

## Core `flyway.toml` settings

```toml
[flyway]
locations = ["filesystem:migrations"]   # where migration scripts live
mixed = true                            # allow mixing migration types
outOfOrder = true                       # allow out-of-order migrations
validateMigrationNaming = true
defaultSchema = "<Schema>"
baselineOnMigrate = true
baselineVersion = "<version>"

[flywayDesktop]
developmentEnvironment = "<DevEnv>"
shadowEnvironment = "<ShadowEnv>"
schemaModel = "./schema-model"

[flywayDesktop.generate]
undoScripts = true                      # auto-generate undo scripts

[redgateCompare.<engine>]
filterFile = "Filter.scpf"              # object filter

[redgateCompare.<engine>.options.behavior]
includeDependencies = true              # override per-command with a CLI flag
```

## Verify connectivity

```bash
flyway testConnection -environment=<DevEnv>
```
