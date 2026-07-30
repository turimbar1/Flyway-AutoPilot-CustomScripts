# Generating Migration Scripts

Operation: turn changes into versioned migration scripts on disk. See [README.md](README.md) for placeholders and [cli-reference.md](cli-reference.md) for arg quoting.

Flow: **`diff`** against the migrations (build) → **`generate`** the script. Use **`add`** to hand-write one instead.

## diff (against migrations)

Compute what the migrations are missing versus a source, building the target in a shadow DB.

```bash
flyway diff "-diff.source=<DevEnv>" "-diff.target=migrations" "-diff.buildEnvironment=<ShadowEnv>"
```

- `-diff.buildEnvironment` is required so Flyway can build the current migration state to compare against.
- Yields change IDs for `-generate.changes`.

## generate

Create a versioned migration SQL script from the diff.

```bash
# Specific changes
flyway generate "-generate.changes=<changeId>,<changeId>" "-generate.description=<Description>" "-redgateCompare.<engine>.options.behavior.includeDependencies=false"

# All changes (omit -generate.changes)
flyway generate "-generate.description=<Description>" "-redgateCompare.<engine>.options.behavior.includeDependencies=false"

# Custom output location
flyway generate "-generate.changes=<changeId>" "-generate.description=<Description>" "-generate.location=<path>"
```

- Omit `-generate.changes` to include everything.
- Output name: `V<version>__<Description>.sql`.
- If `flywayDesktop.generate.undoScripts = true`, a matching undo script is produced.
- **Gotcha:** add `includeDependencies=false` when generating for specific objects only.

## add

Create a new **empty** migration for hand-editing.

```bash
flyway add "-add.description=<Description>" "-add.type=versioned"   # V
flyway add "-add.description=<Description>" "-add.type=undo"        # U  [teams]
flyway add "-add.description=<Description>" "-add.type=repeatable"  # R
```

## Naming conventions

| Prefix | Meaning |
|--------|---------|
| `B<version>__<Description>.sql` | Baseline |
| `V<version>__<Description>.sql` | Versioned migration |
| `U<version>__<Description>.sql` | Undo of that version `[teams]` |
| `R__<Description>.sql` | Repeatable (re-run when checksum changes) |

## Migrations folder layout (generic)

```
migrations/
├── B<version>__baseline.sql
├── V<version>__<Description>.sql
├── U<version>__<Description>.sql
└── R__<Description>.sql
```
