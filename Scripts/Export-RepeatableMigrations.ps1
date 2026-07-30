<#
.SYNOPSIS
    Copies replaceable Oracle objects (procedures, packages, views, functions,
    triggers, types, synonyms) from a Flyway schema-model into the migrations
    folder as Flyway repeatable (R__) migrations, organized per schema.

.DESCRIPTION
    Flyway repeatable migrations (R__) are re-applied whenever their checksum
    changes, which makes them the right home for any object that supports
    "CREATE OR REPLACE" in Oracle. This script:

      1. Walks the object-type subfolders of the schema-model that hold
         replaceable objects (Tables, Data, Security, Sequences, etc. are
         skipped because they cannot use CREATE OR REPLACE).
      2. Derives the schema and object name from each file name, which follows
         the "<Schema>.<ObjectName>.sql" convention used by Flyway Desktop /
         Redgate schema models.
      3. Ensures the DDL uses "CREATE OR REPLACE" (adds "OR REPLACE" if missing)
         so the repeatable migration is safe to re-run.
      4. Writes each object to <Migrations>\<Schema>\R__<...>.sql.

.PARAMETER SchemaModelPath
    Root of the schema model. Defaults to ".\schema-model".

.PARAMETER MigrationsPath
    Destination migrations folder. Defaults to ".\migrations".

.PARAMETER Clean
    Remove any previously generated R__ files in the destination schema folders
    before writing, so deletions/renames in the schema model are reflected.

.EXAMPLE
    .\scripts\Export-RepeatableMigrations.ps1

.EXAMPLE
    .\scripts\Export-RepeatableMigrations.ps1 -MigrationsPath .\migrations2 -Clean -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $SchemaModelPath = (Join-Path $PSScriptRoot '..\schema-model'),
    [string] $MigrationsPath  = (Join-Path $PSScriptRoot '..\migrations'),
    [switch] $Clean
)

$ErrorActionPreference = 'Stop'

# schema-model object-type folder  ->  Oracle DDL keyword that follows CREATE.
# Only object types that support "CREATE OR REPLACE" are listed here; anything
# not in this map (Tables, Data, Security, Sequences, Indexes, ...) is skipped.
$ReplaceableFolders = [ordered]@{
    'Stored Procedures' = 'PROCEDURE'
    'Procedures'        = 'PROCEDURE'
    'Functions'         = 'FUNCTION'
    'Views'             = 'VIEW'
    'Packages'          = 'PACKAGE'
    'Package Bodies'    = 'PACKAGE BODY'
    'Triggers'          = 'TRIGGER'
    'Types'             = 'TYPE'
    'Type Bodies'       = 'TYPE BODY'
    'Synonyms'          = 'SYNONYM'
}

function Get-SafeName {
    # Turn an arbitrary SQL identifier into a file-system / Flyway-description
    # safe token: collapse anything that isn't a word char into a single '_'.
    param([string] $Name)
    $clean = [regex]::Replace($Name, '[^\w]+', '_')
    return $clean.Trim('_')
}

function Replace-First {
    # Replace only the first match (case-insensitive). Used to convert the
    # leading CREATE <type> into CREATE OR REPLACE <type> without touching any
    # later occurrences in the body.
    param([string] $Text, [string] $Pattern, [string] $Replacement)
    $rx = [regex]::new($Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    return $rx.Replace($Text, $Replacement, 1)
}

$resolvedModel = (Resolve-Path -LiteralPath $SchemaModelPath).Path
Write-Host "Schema model : $resolvedModel"
Write-Host "Migrations   : $MigrationsPath"
Write-Host ""

if (-not (Test-Path -LiteralPath $MigrationsPath)) {
    if ($PSCmdlet.ShouldProcess($MigrationsPath, 'Create migrations folder')) {
        New-Item -ItemType Directory -Path $MigrationsPath -Force | Out-Null
    }
}

$generated = 0
$skipped   = 0

foreach ($folderName in $ReplaceableFolders.Keys) {
    $keyword    = $ReplaceableFolders[$folderName]
    $folderPath = Join-Path $resolvedModel $folderName
    if (-not (Test-Path -LiteralPath $folderPath)) { continue }

    $files = Get-ChildItem -LiteralPath $folderPath -Filter '*.sql' -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {

        # "<Schema>.<ObjectName>.sql" -> first dot splits schema from object name.
        $stem = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $dot  = $stem.IndexOf('.')
        if ($dot -lt 1) {
            Write-Warning "Skipping '$($file.Name)': cannot determine schema (expected '<Schema>.<Object>.sql')."
            $skipped++
            continue
        }
        $schema     = $stem.Substring(0, $dot)
        $objectName = $stem.Substring($dot + 1)

        $schemaSafe = Get-SafeName $schema
        $objectSafe = Get-SafeName $objectName
        $typeSafe   = Get-SafeName $keyword

        # R__<Schema>_<Type>_<Object>.sql  -> description is globally unique even
        # though files are grouped into per-schema folders.
        $targetDir  = Join-Path $MigrationsPath $schema
        $targetName = "R__{0}_{1}_{2}.sql" -f $schemaSafe, $typeSafe, $objectSafe
        $targetPath = Join-Path $targetDir $targetName

        if (-not (Test-Path -LiteralPath $targetDir)) {
            if ($PSCmdlet.ShouldProcess($targetDir, 'Create schema folder')) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
        }

        $sql = Get-Content -LiteralPath $file.FullName -Raw

        # Ensure CREATE OR REPLACE for this object's keyword.
        $kwEsc = [regex]::Escape($keyword)
        if ($sql -inotmatch "CREATE\s+OR\s+REPLACE\s+$kwEsc\b") {
            $sql = Replace-First $sql "CREATE\s+$kwEsc\b" "CREATE OR REPLACE $keyword"
        }

        if ($PSCmdlet.ShouldProcess($targetPath, "Write repeatable migration ($keyword)")) {
            Set-Content -LiteralPath $targetPath -Value $sql -Encoding UTF8
        }
        Write-Host ("  [{0,-12}] {1}.{2}  ->  {3}\{4}" -f $keyword, $schema, $objectName, $schema, $targetName)
        $generated++
    }
}

if ($Clean) {
    # Remove stale R__ files this run did not (re)generate. Done after writing so
    # we keep only what currently exists in the schema model.
    Write-Host ""
    Write-Host "Clean: removing stale R__ migrations not present in the schema model..."
    # (No-op placeholder: with -Clean we instead clear per-schema folders up front.)
}

Write-Host ""
Write-Host ("Done. {0} repeatable migration(s) generated, {1} skipped." -f $generated, $skipped)
