#!/bin/bash

# Script Audit Tool - Simplified Version
# Analyze git history for specific folders and report user activity

set -e

# Defaults
FOLDERS="${1:-Scripts,migrations,Quests}"
OUTPUT_FILE="${2:-audit-report.txt}"

# Ensure we're in a git repository
if [ ! -d .git ]; then
    echo "Error: Not in a git repository."
    exit 1
fi

echo "Script Audit Tool - Git History Analysis"
echo "========================================"
echo "Analyzing folders: $FOLDERS"
echo ""

# Temp file for raw data
TEMP_DATA=$(mktemp)
trap "rm -f $TEMP_DATA" EXIT

# Process folders
IFS=',' read -ra FOLDER_ARRAY <<< "$FOLDERS"

for folder in "${FOLDER_ARRAY[@]}"; do
    folder=$(echo "$folder" | xargs)
    [ -d "$folder" ] || { echo "Warning: $folder not found"; continue; }
    
    echo "Scanning folder: $folder"
    git log --name-status --pretty=format:"%an|%ae|%ad|%s" --date=short -- "$folder" 2>/dev/null | \
    awk -v folder="$folder" '
        BEGIN { RS=""; FS="\n" }
        NF > 0 {
            split($1, info, "|")
            author = info[1]
            email = info[2]
            date = info[3]
            msg = info[4]
            
            for (i = 2; i <= NF; i++) {
                if ($i ~ /^[AMD]\t/) {
                    change = substr($i, 1, 1)
                    file = substr($i, 3)
                    printf "%s|%s|%s|%s|%s\n", folder, author, change, date, file
                }
            }
        }
    ' >> "$TEMP_DATA"
done

echo ""
echo "========================================"
echo "AUDIT SUMMARY"
echo "========================================"
echo ""

# Statistics
total=$(wc -l < "$TEMP_DATA" 2>/dev/null || echo 0)
unique_users=$(cut -d'|' -f2 "$TEMP_DATA" 2>/dev/null | sort -u | wc -l)

echo "Total Changes Found: $total"
echo "Number of Unique Users: $unique_users"
echo ""

echo "USER ACTIVITY BREAKDOWN:"
echo "------------------------"

awk -F'|' '
{
    author = $2
    change = $3
    user_changes[author]++
    user_change_type[author][change]++
}
END {
    n = asorti(user_changes, sorted_users, "@ind_str_asc")
    for (i = n; i >= 1; i--) {
        user = sorted_users[i]
        count = user_changes[user]
        
        printf "%s\n", user
        printf "  - Total Changes: %d\n", count
        
        breakdown = ""
        if ("A" in user_change_type[user]) {
            breakdown = breakdown (breakdown ? ", " : "") "Added: " user_change_type[user]["A"]
        }
        if ("M" in user_change_type[user]) {
            breakdown = breakdown (breakdown ? ", " : "") "Modified: " user_change_type[user]["M"]
        }
        if ("D" in user_change_type[user]) {
            breakdown = breakdown (breakdown ? ", " : "") "Deleted: " user_change_type[user]["D"]
        }
        printf "  - Change Types: %s\n", breakdown
        printf "\n"
    }
}
' "$TEMP_DATA"

echo "CHANGE TYPE SUMMARY:"
echo "--------------------"

awk -F'|' '
{
    change = $3
    change_count[change]++
}
END {
    if ("A" in change_count) print "Added: " change_count["A"]
    if ("M" in change_count) print "Modified: " change_count["M"]
    if ("D" in change_count) print "Deleted: " change_count["D"]
}
' "$TEMP_DATA"

echo ""
echo "CHANGES BY FOLDER:"
echo "------------------"

awk -F'|' '{print $1}' "$TEMP_DATA" | sort | uniq -c | sort -rn | \
while read count folder; do
    echo "$folder: $count changes"
done

echo ""
echo "RECENT CHANGES (Last 10):"
echo "-------------------------"

awk -F'|' '{print $4 " | " $2 " | " $3 " | " $5}' "$TEMP_DATA" | \
awk '{
    type_map["A"] = "Added"
    type_map["M"] = "Modified"
    type_map["D"] = "Deleted"
    change_type = $6
    $6 = type_map[change_type]
    print
}' | sort -r | head -10

echo ""
echo "Audit Complete"
