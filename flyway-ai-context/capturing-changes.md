# Capturing Changes into the Schema Model

Operation: detect changes made directly in a database and write them into the file-based schema model. See [README.md](README.md) for placeholder conventions and [cli-reference.md](cli-reference.md) for arg-quoting rules.

Flow: **`diff`** (find changes) → optionally **`diffText`** (inspect) → **`model`** (apply to schema model).

## diff

Compare two sources and list the differences. Produces a set of change IDs used by `model` and `generate`.

```bash
flyway diff "-diff.source=<DevEnv>" "-diff.target=schemaModel"
```

- `-diff.source` / `-diff.target` — any environment or `schemaModel` / `migrations`.
- When a target must be built from scripts, add `"-diff.buildEnvironment=<ShadowEnv>"`.
- **Gotcha:** every `-key=value` arg must be quoted (see cli-reference).

**Output shape** (parse the pipe-delimited rows):

```
+-----------------------------+--------+-------------+-----------+----------+
| Id                          | Change | Object Type | Schema    | Name     |
+-----------------------------+--------+-------------+-----------+----------+
| 1nMIZkukADLTk5oFjPZPesZjqvQ | Edit   | Table       | <Schema>  | <Object> |
+-----------------------------+--------+-------------+-----------+----------+
```

- **Id** — change hash; pass to `-model.changes` / `-generate.changes`.
- **Change** — `Add` | `Edit` | `Delete`.
- **Object Type** — `Table`, `View`, `Stored Procedure`, `Function`, …

## diffText

Show the detailed text diff for the changes computed by `diff`.

```bash
flyway diffText "-diff.source=<DevEnv>" "-diff.target=schemaModel"
```

## model

Apply diff changes into the `./schema-model` folder.

```bash
# Specific changes (comma-separated IDs from diff)
flyway model "-model.changes=<changeId>,<changeId>" "-redgateCompare.<engine>.options.behavior.includeDependencies=false"

# All changes (omit -model.changes)
flyway model "-redgateCompare.<engine>.options.behavior.includeDependencies=false"
```

- Omit `-model.changes` to apply everything.
- **Gotcha:** add `includeDependencies=false` when syncing specific objects, or unrelated dependent objects get pulled in.

## Schema model layout (generic)

```
schema-model/
├── Data/                 # static-data scripts
├── Security/Schemas/
├── Stored Procedures/
├── Tables/
└── Views/
```
