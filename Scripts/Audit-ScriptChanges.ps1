# Script Audit Tool - Analyze who added, modified, or deleted scripts
# This script audits git history for specific folders and reports user activity

param(
    [string[]]$Folders = @('Scripts', 'migrations', 'Quests'),
    [string]$OutputFormat = 'Console', # Console or CSV
    [string]$CsvOutputPath = 'script-audit-report.csv'
)

# Ensure we're in a git repository
if (-not (Test-Path .git)) {
    Write-Error "Not in a git repository. Please run this script from the repository root."
    exit 1
}

Write-Host "Script Audit Tool - Git History Analysis" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Analyzing folders: $($Folders -join ', ')" -ForegroundColor Yellow
Write-Host ""

# Array to store all changes
$allChanges = @()

# Process each folder
foreach ($folder in $Folders) {
    if (-not (Test-Path $folder)) {
        Write-Warning "Folder not found: $folder"
        continue
    }

    Write-Host "Scanning folder: $folder" -ForegroundColor Green
    
    # Get all commits affecting this folder
    $gitLog = git log --name-status --pretty=format:"%H|%an|%ae|%ad|%s" --date=short -- $folder 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not retrieve git history for $folder"
        continue
    }

    $currentCommit = $null
    $currentAuthor = $null
    $currentEmail = $null
    $currentDate = $null
    $currentMessage = $null

    foreach ($line in $gitLog) {
        if ($line -match '^\w{40}\|') {
            # This is a commit line
            $parts = $line -split '\|'
            $currentCommit = $parts[0]
            $currentAuthor = $parts[1]
            $currentEmail = $parts[2]
            $currentDate = $parts[3]
            $currentMessage = $parts[4]
        }
        elseif ($line -match '^[AMD]\s+') {
            # This is a file change line
            $changeParts = $line -split '\s+', 2
            $changeType = $changeParts[0]
            $filePath = $changeParts[1]
            
            $changeTypeMap = @{
                'A' = 'Added'
                'M' = 'Modified'
                'D' = 'Deleted'
            }
            
            $allChanges += [PSCustomObject]@{
                Folder = $folder
                Author = $currentAuthor
                Email = $currentEmail
                Date = $currentDate
                ChangeType = $changeTypeMap[$changeType]
                File = $filePath
                Commit = $currentCommit
                Message = $currentMessage
            }
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AUDIT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to normalize and consolidate user accounts
function ConsolidateUsers {
    param($changes)
    
    $uniqueAuthors = $changes | Select-Object -ExpandProperty Author -Unique | Where-Object {$_}
    
    # Build groups of related accounts
    $groups = @()
    $processed = @()
    
    foreach ($author in $uniqueAuthors) {
        if ($author -in $processed) { continue }
        
        $group = @($author)
        $processed += $author
        
        foreach ($otherAuthor in $uniqueAuthors) {
            if ($otherAuthor -eq $author -or $otherAuthor -in $processed) { continue }
            
            $authorLower = $author.ToLower()
            $otherLower = $otherAuthor.ToLower()
            
            $authorParts = $author -split '\s+' | Where-Object {$_}
            $otherParts = $otherAuthor -split '\s+' | Where-Object {$_}
            
            $isMatch = $false
            
            # Check for email vs full name match
            if ($authorLower -match '(\w+)\.(\w+)@' -and $otherParts.Count -ge 2) {
                $emailFirst = $matches[1]
                $emailLast = $matches[2]
                $otherFirstLower = ([string]$otherParts[0]).ToLower()
                $otherLastLower = ([string]$otherParts[-1]).ToLower()
                
                if ($emailFirst -eq $otherFirstLower -and $emailLast -eq $otherLastLower) {
                    $isMatch = $true
                }
            }
            elseif ($otherLower -match '(\w+)\.(\w+)@' -and $authorParts.Count -ge 2) {
                $emailFirst = $matches[1]
                $emailLast = $matches[2]
                $authorFirstLower = ([string]$authorParts[0]).ToLower()
                $authorLastLower = ([string]$authorParts[-1]).ToLower()
                
                if ($emailFirst -eq $authorFirstLower -and $emailLast -eq $authorLastLower) {
                    $isMatch = $true
                }
            }
            
            # Check for case/whitespace variations
            if (-not $isMatch) {
                if (($authorLower -replace '\s+', '') -eq ($otherLower -replace '\s+', '')) {
                    $isMatch = $true
                }
            }
            
            if ($isMatch) {
                $group += $otherAuthor
                $processed += $otherAuthor
            }
        }
        
        $groups += , @($group)
    }
    
    # Create mapping: prefer full names over emails, prefer formatted names over non-formatted
    $authorMap = @{}
    foreach ($group in $groups) {
        if ($group.Count -eq 1) {
            $authorMap[$group[0]] = $group[0]
        } else {
            # Sort to prefer: full names with spaces over email/non-spaced versions
            $preferred = ($group | Sort-Object -Property @{Expression={$_ -match '\s'}; Ascending=$false} | Sort-Object -Property @{Expression={$_ -match '@'}; Ascending=$true})[0]
            foreach ($member in $group) {
                $authorMap[$member] = $preferred
            }
        }
    }
    
    # Apply consolidation
    $consolidatedChanges = $changes | ForEach-Object {
        $change = $_
        $change.Author = $authorMap[$change.Author]
        $change
    }
    
    return $consolidatedChanges
}

# Consolidate duplicate user accounts
$allChanges = ConsolidateUsers -changes $allChanges

# Summary statistics
$uniqueUsers = $allChanges | Select-Object -ExpandProperty Author -Unique | Where-Object {$_}
$userCount = $uniqueUsers.Count

Write-Host "Total Changes Found: $($allChanges.Count)" -ForegroundColor Yellow
Write-Host "Number of Unique Users: $userCount" -ForegroundColor Yellow
Write-Host ""

# User summary with change counts
Write-Host "USER ACTIVITY BREAKDOWN:" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan

$userStats = $allChanges | Group-Object -Property Author | 
    ForEach-Object {
        $changeBreakdown = ($_.Group | Group-Object -Property ChangeType | 
            ForEach-Object { "$($_.Name): $($_.Count)" }) -join ', '
        
        [PSCustomObject]@{
            Author = $_.Name
            TotalChanges = $_.Count
            BreakdownByType = $changeBreakdown
            Commits = ($_.Group | Select-Object -ExpandProperty Commit -Unique).Count
        }
    } | Sort-Object -Property TotalChanges -Descending

$userStats | ForEach-Object {
    Write-Host "$($_.Author)" -ForegroundColor White
    Write-Host "  - Total Changes: $($_.TotalChanges)" -ForegroundColor Gray
    Write-Host "  - Change Types: $($_.BreakdownByType)" -ForegroundColor Gray
    Write-Host "  - Commits: $($_.Commits)" -ForegroundColor Gray
    Write-Host ""
}

# Change type summary
Write-Host "CHANGE TYPE SUMMARY:" -ForegroundColor Cyan
Write-Host "--------------------" -ForegroundColor Cyan

$allChanges | Group-Object -Property ChangeType | 
    Sort-Object -Property Count -Descending |
    ForEach-Object {
        Write-Host "$($_.Name): $($_.Count)" -ForegroundColor Yellow
    }

Write-Host ""

# Folder summary
Write-Host "CHANGES BY FOLDER:" -ForegroundColor Cyan
Write-Host "------------------" -ForegroundColor Cyan

$allChanges | Group-Object -Property Folder | 
    Sort-Object -Property Count -Descending |
    ForEach-Object {
        Write-Host "$($_.Name): $($_.Count) changes" -ForegroundColor Yellow
    }

Write-Host ""

# Recent changes
Write-Host "RECENT CHANGES (Last 10):" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor Cyan

$allChanges | 
    Sort-Object -Property Date -Descending |
    Select-Object -First 10 |
    ForEach-Object {
        Write-Host "$($_.Date) | $($_.Author) | $($_.ChangeType) | $($_.File)" -ForegroundColor Gray
    }

Write-Host ""

# Export to CSV if requested
if ($OutputFormat -eq 'CSV') {
    $allChanges | Export-Csv -Path $CsvOutputPath -NoTypeInformation
    Write-Host "Report exported to: $CsvOutputPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Audit Complete" -ForegroundColor Green
