#!/bin/bash

# Script Audit Tool - Analyze who added, modified, or deleted scripts
# This script audits git history for specific folders and reports user activity
# Usage: ./audit-script-changes.sh [--folders folder1,folder2,folder3] [--csv output.csv]

set -e

# Default configuration
FOLDERS="Scripts,migrations,Quests"
OUTPUT_FORMAT="console"
CSV_OUTPUT="script-audit-report.csv"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --folders)
            FOLDERS="$2"
            shift 2
            ;;
        --csv)
            OUTPUT_FORMAT="csv"
            CSV_OUTPUT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure we're in a git repository
if [ ! -d .git ]; then
    echo "Error: Not in a git repository. Please run this script from the repository root."
    exit 1
fi

echo "Script Audit Tool - Git History Analysis"
echo "========================================"
echo "Analyzing folders: $FOLDERS"
echo ""

# Temporary file to store all changes
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Process each folder
IFS=',' read -ra FOLDER_ARRAY <<< "$FOLDERS"

for folder in "${FOLDER_ARRAY[@]}"; do
    folder=$(echo "$folder" | xargs)  # Trim whitespace
    
    if [ ! -d "$folder" ]; then
        echo "Warning: Folder not found: $folder" >&2
        continue
    fi
    
    echo "Scanning folder: $folder"
    
    # Get git log with name-status
    git log --name-status --pretty=format:"%H%n%an%n%ae%n%ad%n%s%n---" --date=short -- "$folder" 2>/dev/null | {
        current_commit=""
        current_author=""
        current_email=""
        current_date=""
        current_message=""
        
        while IFS= read -r line; do
            if [ "$line" = "---" ]; then
                # Separator between commits
                if [ -n "$current_commit" ]; then
                    current_commit=""
                fi
            elif [ -z "$current_commit" ]; then
                current_commit="$line"
            elif [ -z "$current_author" ]; then
                current_author="$line"
            elif [ -z "$current_email" ]; then
                current_email="$line"
            elif [ -z "$current_date" ]; then
                current_date="$line"
            elif [ -z "$current_message" ]; then
                current_message="$line"
            elif [[ "$line" =~ ^[AMD][[:space:]] ]]; then
                # File change line
                change_type="${line:0:1}"
                file_path="${line:2}"
                
                case "$change_type" in
                    A) change_name="Added" ;;
                    M) change_name="Modified" ;;
                    D) change_name="Deleted" ;;
                    *) continue ;;
                esac
                
                echo "$folder|$current_author|$current_email|$current_date|$change_name|$file_path|$current_commit|$current_message" >> "$TEMP_FILE"
            fi
        done
    } || true
done

echo ""
echo "========================================"
echo "AUDIT SUMMARY"
echo "========================================"
echo ""

# Count total changes and unique users
total_changes=$(wc -l < "$TEMP_FILE" 2>/dev/null || echo "0")
unique_users=$(cut -d'|' -f2 "$TEMP_FILE" 2>/dev/null | sort -u | wc -l)

echo "Total Changes Found: $total_changes"
echo "Number of Unique Users: $unique_users"
echo ""

# Function to consolidate user accounts
consolidate_users() {
    local temp_file="$1"
    local temp_consolidated=$(mktemp)
    
    # Get unique authors
    local authors=()
    while IFS= read -r author; do
        authors+=("$author")
    done < <(cut -d'|' -f2 "$temp_file" | sort -u)
    
    declare -A author_map
    
    for author in "${authors[@]}"; do
        if [ -z "${author_map[$author]}" ]; then
            local preferred="$author"
            local matched=0
            
            # Check other authors for matches
            for other_author in "${authors[@]}"; do
                if [ "$other_author" = "$author" ]; then
                    continue
                fi
                
                local author_lower=$(echo "$author" | tr '[:upper:]' '[:lower:]')
                local other_lower=$(echo "$other_author" | tr '[:upper:]' '[:lower:]')
                
                # Remove spaces for comparison
                local author_nospace=$(echo "$author_lower" | tr -d ' ')
                local other_nospace=$(echo "$other_lower" | tr -d ' ')
                
                # Check for exact match without spaces
                if [ "$author_nospace" = "$other_nospace" ]; then
                    # Prefer the one with spaces
                    if [[ "$other_author" =~ " " ]]; then
                        preferred="$other_author"
                    fi
                    matched=1
                fi
                
                # Email vs full name matching
                if [[ "$author_lower" =~ ^([a-z]+)\.([a-z]+)@ ]]; then
                    local email_first="${BASH_REMATCH[1]}"
                    local email_last="${BASH_REMATCH[2]}"
                    local other_parts=($other_author)
                    
                    if [ ${#other_parts[@]} -ge 2 ]; then
                        local other_first=$(echo "${other_parts[0]}" | tr '[:upper:]' '[:lower:]')
                        local other_last=$(echo "${other_parts[-1]}" | tr '[:upper:]' '[:lower:]')
                        
                        if [ "$email_first" = "$other_first" ] && [ "$email_last" = "$other_last" ]; then
                            preferred="$other_author"
                            matched=1
                        fi
                    fi
                fi
            done
            
            author_map[$author]="$preferred"
            if [ $matched -eq 1 ] && [ "$preferred" != "$author" ]; then
                author_map[$preferred]="$preferred"
            fi
        fi
    done
    
    # Apply consolidation
    while IFS='|' read -r folder author email date change_type file_path commit message; do
        mapped_author="${author_map[$author]:-$author}"
        echo "$folder|$mapped_author|$email|$date|$change_type|$file_path|$commit|$message" >> "$temp_consolidated"
    done < "$temp_file"
    
    cat "$temp_consolidated" > "$temp_file"
    rm -f "$temp_consolidated"
}

# Consolidate users
consolidate_users "$TEMP_FILE"

echo "USER ACTIVITY BREAKDOWN:"
echo "------------------------"

# Get unique users and their stats
cut -d'|' -f2 "$TEMP_FILE" | sort -u | while read author; do
    if [ -z "$author" ]; then continue; fi
    
    total=$(grep "^[^|]*|$author|" "$TEMP_FILE" | wc -l)
    added=$(grep "^[^|]*|$author|[^|]*[^|]*Added" "$TEMP_FILE" | wc -l)
    modified=$(grep "^[^|]*|$author|[^|]*[^|]*Modified" "$TEMP_FILE" | wc -l)
    deleted=$(grep "^[^|]*|$author|[^|]*[^|]*Deleted" "$TEMP_FILE" | wc -l)
    commits=$(grep "^[^|]*|$author|" "$TEMP_FILE" | cut -d'|' -f7 | sort -u | wc -l)
    
    echo "Total:$total:Commits:$commits:Added:$added:Modified:$modified:Deleted:$deleted:Author:$author"
done | sort -t':' -k2 -rn | while IFS=':' read -r _ total _ _ _ added _ modified _ deleted _ _ author; do
    echo "$author"
    echo "  - Total Changes: $total"
    echo "  - Change Types: Added: $added, Modified: $modified, Deleted: $deleted"
    echo "  - Commits: $commits"
    echo ""
done

echo "CHANGE TYPE SUMMARY:"
echo "--------------------"
echo "Added: $(grep -c '|Added$' "$TEMP_FILE" 2>/dev/null || echo 0)"
echo "Modified: $(grep -c '|Modified$' "$TEMP_FILE" 2>/dev/null || echo 0)"
echo "Deleted: $(grep -c '|Deleted$' "$TEMP_FILE" 2>/dev/null || echo 0)"
echo ""

echo "CHANGES BY FOLDER:"
echo "------------------"
cut -d'|' -f1 "$TEMP_FILE" | sort | uniq -c | sort -rn | while read count folder; do
    echo "$folder: $count changes"
done
echo ""

echo "RECENT CHANGES (Last 10):"
echo "-------------------------"
sort -t'|' -k4 -r "$TEMP_FILE" | head -10 | while IFS='|' read -r folder author email date change_type file_path commit message; do
    echo "$date | $author | $change_type | $file_path"
done
echo ""

# Export to CSV if requested
if [ "$OUTPUT_FORMAT" = "csv" ]; then
    {
        echo "Folder,Author,Email,Date,ChangeType,File,Commit,Message"
        cat "$TEMP_FILE"
    } > "$CSV_OUTPUT"
    echo "Report exported to: $CSV_OUTPUT"
    echo ""
fi

echo "Audit Complete"
