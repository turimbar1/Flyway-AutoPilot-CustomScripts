# Flyway AI Context Pack

A compact, project-independent, engine-agnostic reference set that tells an AI assistant (or a developer) how to drive [Flyway](https://documentation.red-gate.com/flyway). Drop this folder into any Flyway project. Each file covers one operation and is a terse quick-reference — load only the file you need.

## How to use

1. Read this index, then open the file for your operation.
2. Substitute the `<placeholders>` (see below) with the target project's real values — or fill in the **Project profile** template and keep it beside these files.
3. Every command uses the Flyway CLI. See [cli-reference.md](cli-reference.md) for argument-quoting rules and error handling that apply to *all* commands.

## Files by operation

| File | Operation |
|------|-----------|
| [environments-and-provisioning.md](environments-and-provisioning.md) | Set up environments, connections, provisioners, `clean`, core `flyway.toml` |
| [capturing-changes.md](capturing-changes.md) | Capture live DB changes into the schema model (`diff`, `diffText`, `model`) |
| [generating-migrations.md](generating-migrations.md) | Produce migration scripts (`generate`, `add`, naming, folder layout) |
| [applying-migrations.md](applying-migrations.md) | Apply / inspect / repair (`migrate`, `info`, `validate`, `undo`, `baseline`, `repair`) |
| [deploying-and-drift.md](deploying-and-drift.md) | Deploy & verify (`prepare`, `deploy`, `snapshot`, `check`) |
| [cli-reference.md](cli-reference.md) | Command index, arg quoting, error handling, output-parsing patterns |
| [automation-workflow.md](automation-workflow.md) | Scripted `diff → model → generate` sync of selected objects |

## Conventions

**Engine is a variable.** Examples work for any engine Flyway supports. Where it matters, substitute `<engine>` ∈ `sqlserver | oracle | postgresql | mysql | …`. Comparison config keys are written `redgateCompare.<engine>.*`. Engine-specific artifacts (jdbc URL shape, backup file `.bak` for SQL Server / `.dmp` for Oracle) are called out only where relevant.

**Placeholders** (replace with real values):

| Placeholder | Meaning |
|-------------|---------|
| `<engine>` | Database engine: `sqlserver`, `oracle`, `postgresql`, `mysql`, … |
| `<HOST>` / `<PORT>` | Database server host / port |
| `<DevDatabase>` / `<ShadowDatabase>` | Development / shadow (build) database names |
| `<DevEnv>` / `<ShadowEnv>` / `<TestEnv>` / `<ProdEnv>` | Environment names as defined in `flyway.toml` |
| `<Schema>.<Object>` | A fully-qualified object, e.g. a table or stored procedure |
| `<Description>` | Free-text migration description |
| `<changeId>` | A change hash from `diff` output |
| `<username>` / `<branch>` | Current user / VCS branch (used in auto descriptions) |

**Edition tags.** `[teams]` and `[enterprise]` mark commands/flags requiring a paid edition; everything else works in Community.

## Project profile (fill in per project)

```
Engine:            <engine>
Server:            <HOST>:<PORT>
Config file:       flyway.toml
Schema model:      ./schema-model
Migrations:        ./migrations

Environments:
  <DevEnv>      -> <DevDatabase>      (source of truth for changes)
  <ShadowEnv>   -> <ShadowDatabase>   (build/validate; provisioner = clean)
  <TestEnv>     -> <TestDatabase>
  <ProdEnv>     -> <ProdDatabase>

Static-data tables (data tracked in VCS): <Schema>.<Object>, ...
```
