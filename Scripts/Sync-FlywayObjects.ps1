<#
.SYNOPSIS
    Syncs database objects from development to schema-model and generates Flyway migrations.

.DESCRIPTION
    This script automates the Flyway workflow for syncing specific database objects or all changes
    from the development database to the schema-model folder, and optionally generates versioned
    migration scripts. It streamlines the process of capturing development changes and creating
    repeatable migration scripts for deployment.

.AUTHOR
    Andrew Pierce
    
.CREATED
    February 2026

.VERSION
    2.0

.PARAMETER Objects
    Array of database objects to sync in "Schema.ObjectName" format (e.g., "Operation.Products").
    Cannot be used with -All parameter.

.PARAMETER All
    Switch to process all detected changes between development and schema-model.
    When used, -model.changes and -generate.changes parameters are omitted from Flyway commands,
    allowing Flyway to sync all differences.

.PARAMETER Description
    Custom description for the generated migration script. If not provided, a description is
    auto-generated using format: {branch}_{changeType}_{schema}_{object}_{user}

.PARAMETER SkipGenerate
    Skip the migration script generation step. Only updates the schema-model folder.

.PARAMETER DryRun
    Preview mode - shows what changes would be made without actually modifying files or databases.
    Displays schema-model changes and migration script preview.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -Objects "Operation.Products"
    Syncs the Operation.Products table and generates a migration script.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -Objects "Operation.Products","Sales.Customers" -Description "Add_New_Columns"
    Syncs multiple objects with a custom migration description.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -All
    Syncs all changes detected between development and schema-model.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -All -DryRun
    Preview all changes without making modifications.

.EXAMPLE
    .\Sync-FlywayObjects.ps1 -Objects "Operation.Products" -SkipGenerate
    Only updates schema-model, does not generate a migration script.

.NOTES
    Workflow:
    1. Runs 'flyway diff' to compare development database to schema-model
    2. Parses diff output to extract change IDs
    3. Filters for requested objects (if -Objects specified)
    4. Runs 'flyway model' to update schema-model folder
    5. Runs 'flyway diff' from development to migrations (with shadow build environment)
    6. Runs 'flyway generate' to create versioned migration script
    
    Requirements:
    - Flyway Enterprise Edition
    - Access to development and shadow databases
    - Git (for auto-generating descriptions with branch and user info)
    - Environments 'development' and 'shadow' must be defined in flyway.toml
    
    Configuration:
    - Source database: development (fixed - must be defined in flyway.toml)
    - Build environment: shadow (fixed - must be defined in flyway.toml)
    - Schema-model location: ./schema-model (from flyway.toml)
    - Migrations location: ./migrations (from flyway.toml)
    
    The flyway.toml file must contain environment definitions like:
        [environments.development]
        url = "jdbc:sqlserver://..."
        
        [environments.shadow]
        url = "jdbc:sqlserver://..."
        provisioner = "clean"

#>

param(
    [Parameter(Mandatory=$false)]
    [string[]]$Objects,
    [Parameter(Mandatory=$false)]
    [switch]$All,
    
    [Parameter(Mandatory=$false)]
    [string]$Description,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipGenerate,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# Fixed values for source and target
$Source = "development"
$Target = "shadow"

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Flyway Object Sync Tool" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Validate objects format (unless -All requested)
if (-not $All) {
    if (-not $Objects -or $Objects.Count -eq 0) {
        Write-Error "Specify -Objects or use -All to process all changes"
        exit 1
    }

    foreach ($obj in $Objects) {
        if ($obj -notmatch '^\w+\.[\w\s]+$') {
            Write-Error "Invalid object format: $obj. Expected format: Schema.ObjectName"
            exit 1
        }
    }
}

Write-Host "Objects to sync:" -ForegroundColor Yellow
if ($All) {
    Write-Host "  - ALL changes (processing every change found in diff)" -ForegroundColor Gray
} else {
    $Objects | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
}
Write-Host ""

# Step 1: Run flyway diff (development to schemaModel to find what needs to be synced)
Write-Host "Step 1: Running flyway diff..." -ForegroundColor Green
$diffCommand = "flyway diff -source=development -target=schemaModel"
$diffOutput = Invoke-Expression $diffCommand 2>&1 | Out-String

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flyway diff failed. Output:`n$diffOutput"
    exit 1
}

Write-Host $diffOutput
Write-Host ""

# Step 2: Parse diff output to extract change IDs
Write-Host "Step 2: Parsing diff output..." -ForegroundColor Green

# Extract the table from diff output
$lines = $diffOutput -split "`n"
$tableStarted = $false
$changes = @()

foreach ($line in $lines) {
    # Detect table start
    if ($line -match '^\+[-+]+\+' -or $line -match '^\| Id\s+\|') {
        $tableStarted = $true
        continue
    }
    
    # Skip separator lines and empty lines
    if ($line -match '^\+[-+]+\+' -or $line -match '^\s*$') {
        continue
    }
    
    # Parse data lines
    if ($tableStarted -and $line -match '^\|\s*(\S+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*([^|]+)\s*\|') {
        $changeId = $matches[1].Trim()
        $changeType = $matches[2].Trim()
        $objectType = $matches[3].Trim()
        $schema = $matches[4].Trim()
        $objectName = $matches[5].Trim()
        
        # Skip header and "No differences found" messages
        if ($changeId -eq "Id" -or $changeId -match "^No") {
            continue
        }
        
        $changes += [PSCustomObject]@{
            ChangeId = $changeId
            ChangeType = $changeType
            ObjectType = $objectType
            Schema = $schema
            ObjectName = $objectName
            FullName = "$schema.$objectName"
        }
    }
}

if ($changes.Count -eq 0) {
    Write-Host "No differences found between $Source and $Target" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($changes.Count) changes:" -ForegroundColor Yellow
$changes | ForEach-Object {
    Write-Host "  - $($_.FullName) [$($_.ObjectType)] - $($_.ChangeType)" -ForegroundColor Gray
}
Write-Host ""

# Step 3: Filter changes based on requested objects
Write-Host "Step 3: Filtering for requested objects..." -ForegroundColor Green

$matchedChanges = @()
if ($All) {
    $matchedChanges = $changes
    if ($matchedChanges.Count -eq 0) {
        Write-Host "No differences found between $Source and $Target" -ForegroundColor Yellow
        exit 0
    }
    Write-Host "  ✓ Processing all $($matchedChanges.Count) change(s)" -ForegroundColor Green
} else {
    foreach ($obj in $Objects) {
        $matched = $changes | Where-Object { $_.FullName -eq $obj }
        
        if ($matched) {
            $matchedChanges += $matched
            Write-Host "  ✓ Matched: $obj" -ForegroundColor Green
        } else {
            Write-Warning "  ✗ No match found for: $obj"
        }
    }

    if ($matchedChanges.Count -eq 0) {
        Write-Error "No changes found for the specified objects"
        exit 1
    }
}

Write-Host ""
Write-Host "Objects to process:" -ForegroundColor Yellow
$matchedChanges | ForEach-Object {
    Write-Host "  - $($_.FullName) [$($_.ChangeId)]" -ForegroundColor Gray
}
Write-Host ""

# Build comma-separated list of change IDs
$changeIds = ($matchedChanges | ForEach-Object { $_.ChangeId }) -join ','

# Generate description if not provided
if (-not $Description) {
    Write-Host "Generating migration description..." -ForegroundColor Gray
    
    # Get git branch name
    $branchName = git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        $branchName = "unknown-branch"
    }
    
    # Get git user name
    $userName = git config user.name 2>$null
    if ($LASTEXITCODE -ne 0) {
        $userName = $env:USERNAME
    }
    
    # Build object summary
    $objectSummary = ($matchedChanges | ForEach-Object {
        "$($_.ChangeType)_$($_.Schema)_$($_.ObjectName)"
    }) -join "_"
    
    # Format: BranchName_Operation_Object(s)_UserName
    $Description = "$branchName" + "_" + "$objectSummary" + "_" + "$userName"
    
    # Replace spaces and periods with underscores
    $Description = $Description -replace '[\s\.]', '_'
    
    Write-Host "  Description: $Description" -ForegroundColor Gray
    Write-Host ""
}

if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
    
    # Show what would be updated in schema model
    Write-Host "Schema Model Changes Preview:" -ForegroundColor Cyan
    Write-Host "-----------------------------" -ForegroundColor Cyan
    $diffTextCommand = "flyway diffText `"-diff.source=development`" `"-diff.target=schemaModel`""
    $diffTextOutput = Invoke-Expression $diffTextCommand 2>&1 | Out-String
    
    # Filter to show only the selected changes
    $lines = $diffTextOutput -split "`n"
    $inSelectedObject = $false
    $outputLines = @()
    
    foreach ($change in $matchedChanges) {
        $objectPattern = "$($change.Schema)\.$($change.ObjectName)"
        foreach ($line in $lines) {
            if ($line -match "--- $($change.ObjectType)/$objectPattern" -or $line -match "\+\+\+ $($change.ObjectType)/$objectPattern") {
                $inSelectedObject = $true
            }
            if ($inSelectedObject) {
                $outputLines += $line
                if ($line -match "^GO\s*$") {
                    $inSelectedObject = $false
                }
            }
        }
    }
    
    if ($outputLines.Count -gt 0) {
        $outputLines | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No schema model changes detected for selected objects" -ForegroundColor Gray
    }
    Write-Host ""
    
    if (-not $SkipGenerate) {
        # Run diff for generate preview
        Write-Host "Migration Script Preview:" -ForegroundColor Cyan
        Write-Host "-------------------------" -ForegroundColor Cyan
        $tempMigrationDir = Join-Path $env:TEMP "flyway-dryrun-$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -ItemType Directory -Path $tempMigrationDir -Force | Out-Null
        
        $genDiffCommand = "flyway diff `"-diff.source=development`" `"-diff.target=migrations`" `"-diff.buildEnvironment=$Target`""
        $genDiffOutput = Invoke-Expression $genDiffCommand 2>&1 | Out-String

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "flyway diff (development -> migrations) failed with exit code $LASTEXITCODE"
            Write-Host $genDiffOutput
            Write-Host "Skipping generate preview due to diff error" -ForegroundColor Yellow
        } else {
            # Generate to temp location
            if ($All) {
                $generateCommand = "flyway generate `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`" `"-generate.location=$tempMigrationDir`" `"-generate.description=$Description`""
            } else {
                $generateCommand = "flyway generate `"-generate.changes=$changeIds`" `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`" `"-generate.location=$tempMigrationDir`" `"-generate.description=$Description`""
            }
            $genOutput = Invoke-Expression $generateCommand 2>&1 | Out-String

            # Find and display the generated file
            $generatedFiles = Get-ChildItem -Path $tempMigrationDir -Filter "*.sql"
            if ($generatedFiles) {
                foreach ($file in $generatedFiles) {
                    Write-Host "--- $($file.Name) ---" -ForegroundColor Green
                    Get-Content $file.FullName | ForEach-Object { Write-Host $_ }
                }
            } else {
                Write-Host "No migration script generated" -ForegroundColor Gray
            }
        }
        
        # Clean up temp directory
        Remove-Item -Path $tempMigrationDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    exit 0
}

# Step 4: Update schema model
Write-Host "Step 4: Updating schema model..." -ForegroundColor Green

if ($All) {
    $modelCommand = "flyway model `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`""
} else {
    $modelCommand = "flyway model `"-model.changes=$changeIds`" `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`""
}
Write-Host "Executing: $modelCommand" -ForegroundColor Gray

$modelOutput = Invoke-Expression $modelCommand 2>&1 | Out-String

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flyway model failed. Output:`n$modelOutput"
    exit 1
}

Write-Host $modelOutput
Write-Host "✓ Schema model updated successfully" -ForegroundColor Green
Write-Host ""

# Step 5: Generate migration script (if not skipped)
if (-not $SkipGenerate) {
    Write-Host "Step 5: Generating migration script..." -ForegroundColor Green
    
    # Run diff from development with build environment
    Write-Host "  Running diff from development with build environment..." -ForegroundColor Gray
    $genDiffCommand = "flyway diff -diff.source=development `"-diff.target=migrations`" `"-diff.buildEnvironment=$Target`""
    $genDiffOutput = Invoke-Expression $genDiffCommand 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        Write-Error "flyway diff (development -> migrations) failed. Output:`n$genDiffOutput"
        exit 1
    }

    if ($All) {
        $generateCommand = "flyway generate `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`" `"-generate.description=$Description`""
    } else {
        $generateCommand = "flyway generate `"-generate.changes=$changeIds`" `"-redgateCompare.sqlserver.options.behavior.includeDependencies=false`" `"-generate.description=$Description`""
    }
    Write-Host "Executing: $generateCommand" -ForegroundColor Gray

    $generateOutput = Invoke-Expression $generateCommand 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flyway generate failed. Output:`n$generateOutput"
        exit 1
    }

    Write-Host $generateOutput
    
    # Extract generated file path
    if ($generateOutput -match 'Generated:\s+(.+\.sql)') {
        $generatedFile = $matches[1].Trim()
        Write-Host "✓ Migration generated: $generatedFile" -ForegroundColor Green
    } else {
        Write-Host "✓ Migration generated successfully" -ForegroundColor Green
    }
    Write-Host ""
} else {
    Write-Host "Step 5: Skipping migration generation" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Sync Complete!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Objects processed: $($matchedChanges.Count)" -ForegroundColor Gray
$matchedChanges | ForEach-Object {
    Write-Host "    - $($_.FullName)" -ForegroundColor Gray
}
Write-Host ""
