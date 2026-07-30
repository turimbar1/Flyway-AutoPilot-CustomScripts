# Deploying & Drift Verification

Operation: produce a reviewable deployment script, deploy it, and check for schema drift. See [README.md](README.md) for placeholders and [cli-reference.md](cli-reference.md) for arg quoting.

## prepare

Write a deployment script to disk **without** applying it (for review/approval).

```bash
# From schema model to an environment
flyway prepare "-prepare.source=schemaModel" "-prepare.target=<TestEnv>" "-prepare.scriptFilename=deploy.sql"

# From migrations to an environment
flyway prepare "-prepare.source=migrations" "-prepare.target=<ProdEnv>" "-prepare.scriptFilename=deploy.sql"
```

## deploy

Execute a prepared deployment script against an environment.

```bash
flyway deploy "-deploy.scriptFilename=deploy.sql" -environment=<ProdEnv>

# Save a snapshot for later drift detection
flyway deploy "-deploy.scriptFilename=deploy.sql" -environment=<ProdEnv> "-deploy.saveSnapshot=true"
```

## snapshot `[enterprise]`

Capture a point-in-time state for comparison/drift.

```bash
flyway snapshot "-snapshot.source=<DevEnv>" "-snapshot.filename=snap.snp"
flyway snapshot "-snapshot.source=schemaModel" "-snapshot.filename=model.snp"
```

## check `[enterprise]`

Produce confidence reports before deploying.

```bash
flyway check "-changes" "-environment=<DevEnv>" "-check.buildEnvironment=<ShadowEnv>"   # change report
flyway check "-drift" "-environment=<ProdEnv>" "-check.deployedSnapshot=snap.snp"        # drift report
flyway check "-code" "-environment=<DevEnv>"                                              # static code analysis
```

## Detect drift with diff

Quick drift check without the enterprise report: compare the live target to the schema model.

```bash
flyway diff "-diff.source=<ProdEnv>" "-diff.target=schemaModel"
# Any differences = drift; investigate before deploying.
```

## Prepare → review → deploy pattern

```bash
flyway prepare "-prepare.source=migrations" "-prepare.target=<ProdEnv>" "-prepare.scriptFilename=deploy.sql"
# review deploy.sql manually
flyway deploy "-deploy.scriptFilename=deploy.sql" -environment=<ProdEnv>
```
