#!/bin/bash
#
# sync-flyway-objects.sh
#
# SYNOPSIS
#     Syncs database objects from development to schema-model and generates Flyway migrations.
#
# DESCRIPTION
#     This script automates the Flyway workflow for syncing specific database objects or all changes
#     from the development database to the schema-model folder, and optionally generates versioned
#     migration scripts. It streamlines the process of capturing development changes and creating
#     repeatable migration scripts for deployment.
#
# AUTHOR
#     Andrew Pierce
#
# CREATED
#     February 2026
#
# VERSION
#     2.0
#
# USAGE
#     ./sync-flyway-objects.sh -o "Schema.ObjectName"
#     ./sync-flyway-objects.sh -o "Schema.Object1,Schema.Object2"
#     ./sync-flyway-objects.sh -a
#     ./sync-flyway-objects.sh -o "Schema.ObjectName" -d "custom_description"
#     ./sync-flyway-objects.sh -o "Schema.ObjectName" -n
#     ./sync-flyway-objects.sh -o "Schema.ObjectName" -s
#
# OPTIONS
#     -o, --objects     Comma-separated list of objects in "Schema.ObjectName" format
#     -a, --all         Process all detected changes (cannot be used with -o)
#     -d, --description Custom description for the generated migration script
#     -s, --skip-generate  Skip migration script generation, only update schema-model
#     -n, --dry-run     Preview mode - show changes without modifying anything
#     -h, --help        Show this help message
#
# EXAMPLES
#     ./sync-flyway-objects.sh -o "Operation.Products"
#     ./sync-flyway-objects.sh -o "Operation.Products,Sales.Customers" -d "Add_New_Columns"
#     ./sync-flyway-objects.sh -a
#     ./sync-flyway-objects.sh -a -n
#     ./sync-flyway-objects.sh -o "Operation.Products" -s
#
# WORKFLOW
#     1. Runs 'flyway diff' to compare development database to schema-model
#     2. Parses diff output to extract change IDs
#     3. Filters for requested objects (if -o specified)
#     4. Runs 'flyway diff' from development to migrations (with shadow build environment)
#     5. Runs 'flyway generate' to create versioned migration script
#     6. Runs 'flyway migrate' to apply migrations to shadow
#     7. Runs 'flyway diff' from shadow to schema-model
#     8. Runs 'flyway model' to update schema-model folder from shadow
#
# REQUIREMENTS
#     - Flyway Enterprise Edition
#     - Access to development and shadow databases
#     - Git (optional, for auto-generating descriptions)
#     - Environments 'development' and 'shadow' must be defined in flyway.toml

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Fixed values for source and target
SOURCE="development"
TARGET="shadow"

# Default values
OBJECTS=""
ALL=false
DESCRIPTION=""
SKIP_GENERATE=false
DRY_RUN=false

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show help
show_help() {
    head -50 "$0" | grep -E "^#" | sed 's/^# *//' | tail -n +2
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--objects)
            OBJECTS="$2"
            shift 2
            ;;
        -a|--all)
            ALL=true
            shift
            ;;
        -d|--description)
            DESCRIPTION="$2"
            shift 2
            ;;
        -s|--skip-generate)
            SKIP_GENERATE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ "$ALL" == false && -z "$OBJECTS" ]]; then
    print_color "$RED" "Error: Specify -o/--objects or use -a/--all to process all changes"
    exit 1
fi

if [[ "$ALL" == true && -n "$OBJECTS" ]]; then
    print_color "$RED" "Error: Cannot use -o/--objects with -a/--all"
    exit 1
fi

# Convert comma-separated objects to array
IFS=',' read -ra OBJECT_ARRAY <<< "$OBJECTS"

# Validate object format
if [[ "$ALL" == false ]]; then
    for obj in "${OBJECT_ARRAY[@]}"; do
        obj=$(echo "$obj" | xargs)  # Trim whitespace
        if [[ ! "$obj" =~ ^[a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_\ ]*$ ]]; then
            print_color "$RED" "Error: Invalid object format: $obj. Expected format: Schema.ObjectName"
            exit 1
        fi
    done
fi

print_color "$CYAN" "======================================="
print_color "$CYAN" "Flyway Object Sync Tool"
print_color "$CYAN" "======================================="
echo ""

print_color "$YELLOW" "Objects to sync:"
if [[ "$ALL" == true ]]; then
    print_color "$GRAY" "  - ALL changes (processing every change found in diff)"
else
    for obj in "${OBJECT_ARRAY[@]}"; do
        obj=$(echo "$obj" | xargs)
        print_color "$GRAY" "  - $obj"
    done
fi
echo ""

# Step 1: Run flyway diff (development to schemaModel)
print_color "$GREEN" "Step 1: Running flyway diff..."
DIFF_OUTPUT=$(flyway diff -source=development -target=schemaModel 2>&1) || {
    print_color "$RED" "Error: Flyway diff failed"
    echo "$DIFF_OUTPUT"
    exit 1
}

echo "$DIFF_OUTPUT"
echo ""

# Step 2: Parse diff output to extract change IDs
print_color "$GREEN" "Step 2: Parsing diff output..."

# Declare arrays
declare -a CHANGE_IDS
declare -a CHANGE_TYPES
declare -a OBJECT_TYPES
declare -a SCHEMAS
declare -a OBJECT_NAMES
declare -a FULL_NAMES

# Parse the table output
TABLE_STARTED=false
while IFS= read -r line; do
    # Detect table start
    if [[ "$line" =~ ^\+[-+]+\+ ]] || [[ "$line" =~ ^\|[[:space:]]*Id[[:space:]]*\| ]]; then
        TABLE_STARTED=true
        continue
    fi
    
    # Skip separator lines and empty lines
    if [[ "$line" =~ ^\+[-+]+\+ ]] || [[ -z "${line// }" ]]; then
        continue
    fi
    
    # Parse data lines (format: | Id | Change | Object Type | Schema | Name |)
    if [[ "$TABLE_STARTED" == true ]] && [[ "$line" =~ ^\|[[:space:]]*([^|]+)\|[[:space:]]*([^|]+)\|[[:space:]]*([^|]+)\|[[:space:]]*([^|]+)\|[[:space:]]*([^|]+)\| ]]; then
        change_id=$(echo "${BASH_REMATCH[1]}" | xargs)
        change_type=$(echo "${BASH_REMATCH[2]}" | xargs)
        object_type=$(echo "${BASH_REMATCH[3]}" | xargs)
        schema=$(echo "${BASH_REMATCH[4]}" | xargs)
        object_name=$(echo "${BASH_REMATCH[5]}" | xargs)
        
        # Skip header and "No differences found" messages
        if [[ "$change_id" == "Id" ]] || [[ "$change_id" =~ ^No ]]; then
            continue
        fi
        
        CHANGE_IDS+=("$change_id")
        CHANGE_TYPES+=("$change_type")
        OBJECT_TYPES+=("$object_type")
        SCHEMAS+=("$schema")
        OBJECT_NAMES+=("$object_name")
        FULL_NAMES+=("$schema.$object_name")
    fi
done <<< "$DIFF_OUTPUT"

if [[ ${#CHANGE_IDS[@]} -eq 0 ]]; then
    print_color "$YELLOW" "No differences found between $SOURCE and schemaModel"
    exit 0
fi

print_color "$YELLOW" "Found ${#CHANGE_IDS[@]} changes:"
for i in "${!CHANGE_IDS[@]}"; do
    print_color "$GRAY" "  - ${FULL_NAMES[$i]} [${OBJECT_TYPES[$i]}] - ${CHANGE_TYPES[$i]}"
done
echo ""

# Step 3: Filter changes based on requested objects
print_color "$GREEN" "Step 3: Filtering for requested objects..."

declare -a MATCHED_INDICES
declare -a MATCHED_CHANGE_IDS

if [[ "$ALL" == true ]]; then
    for i in "${!CHANGE_IDS[@]}"; do
        MATCHED_INDICES+=("$i")
        MATCHED_CHANGE_IDS+=("${CHANGE_IDS[$i]}")
    done
    print_color "$GREEN" "  ✓ Processing all ${#MATCHED_INDICES[@]} change(s)"
else
    for obj in "${OBJECT_ARRAY[@]}"; do
        obj=$(echo "$obj" | xargs)
        found=false
        for i in "${!FULL_NAMES[@]}"; do
            if [[ "${FULL_NAMES[$i]}" == "$obj" ]]; then
                MATCHED_INDICES+=("$i")
                MATCHED_CHANGE_IDS+=("${CHANGE_IDS[$i]}")
                print_color "$GREEN" "  ✓ Matched: $obj"
                found=true
                break
            fi
        done
        if [[ "$found" == false ]]; then
            print_color "$YELLOW" "  ✗ No match found for: $obj"
        fi
    done
fi

if [[ ${#MATCHED_INDICES[@]} -eq 0 ]]; then
    print_color "$RED" "Error: No changes found for the specified objects"
    exit 1
fi

echo ""
print_color "$YELLOW" "Objects to process:"
for i in "${MATCHED_INDICES[@]}"; do
    print_color "$GRAY" "  - ${FULL_NAMES[$i]} [${CHANGE_IDS[$i]}]"
done
echo ""

# Build comma-separated list of change IDs
CHANGE_ID_LIST=$(IFS=','; echo "${MATCHED_CHANGE_IDS[*]}")

# Generate description if not provided
if [[ -z "$DESCRIPTION" ]]; then
    print_color "$GRAY" "Generating migration description..."
    
    # Get git branch name
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown-branch")
    
    # Get git user name or system user
    USER_NAME=$(git config user.name 2>/dev/null || echo "$USER")
    
    # Build object summary
    OBJECT_SUMMARY=""
    for i in "${MATCHED_INDICES[@]}"; do
        if [[ -n "$OBJECT_SUMMARY" ]]; then
            OBJECT_SUMMARY="${OBJECT_SUMMARY}_"
        fi
        OBJECT_SUMMARY="${OBJECT_SUMMARY}${CHANGE_TYPES[$i]}_${SCHEMAS[$i]}_${OBJECT_NAMES[$i]}"
    done
    
    # Format: BranchName_Operation_Object(s)_UserName
    DESCRIPTION="${BRANCH_NAME}_${OBJECT_SUMMARY}_${USER_NAME}"
    
    # Replace spaces and periods with underscores
    DESCRIPTION=$(echo "$DESCRIPTION" | tr ' .' '_')
    
    print_color "$GRAY" "  Description: $DESCRIPTION"
    echo ""
fi

# Dry run mode
if [[ "$DRY_RUN" == true ]]; then
    print_color "$YELLOW" "DRY RUN MODE - No changes will be made"
    echo ""
    
    # Show what would be updated in schema model
    print_color "$CYAN" "Schema Model Changes Preview:"
    print_color "$CYAN" "-----------------------------"
    
    if [[ "$ALL" == true ]]; then
        DIFF_TEXT_OUTPUT=$(flyway diffText "-diff.source=development" "-diff.target=schemaModel" 2>&1) || true
    else
        DIFF_TEXT_OUTPUT=$(flyway diffText "-diff.source=development" "-diff.target=schemaModel" "-diffText.changes=$CHANGE_ID_LIST" 2>&1) || true
    fi
    
    if [[ -n "$DIFF_TEXT_OUTPUT" ]]; then
        echo "$DIFF_TEXT_OUTPUT"
    else
        print_color "$GRAY" "No schema model changes detected for selected objects"
    fi
    echo ""
    
    if [[ "$SKIP_GENERATE" == false ]]; then
        # Run diff from development to target for generate preview
        print_color "$CYAN" "Migration Script Preview:"
        print_color "$CYAN" "-------------------------"
        
        # Run diff from development to target (shadow) to get correct change IDs for generate
        print_color "$GRAY" "  Running diff from development to $TARGET..."
        GEN_DIFF_OUTPUT=$(flyway diff "-diff.source=development" "-diff.target=$TARGET" 2>&1)
        GEN_DIFF_EXIT=$?
        
        if [[ $GEN_DIFF_EXIT -ne 0 ]]; then
            print_color "$YELLOW" "Warning: flyway diff (development -> $TARGET) failed"
            echo "$GEN_DIFF_OUTPUT"
            print_color "$YELLOW" "Skipping generate preview due to diff error"
        else
            # Parse the diff output to get change IDs for matched objects
            declare -a GEN_CHANGE_IDS
            declare -a GEN_FULL_NAMES
            
            GEN_TABLE_STARTED=false
            while IFS= read -r line; do
                if [[ "$line" =~ ^\+[-+]+\+ ]] || [[ "$line" =~ ^\|[[:space:]]*Id[[:space:]]*\| ]]; then
                    GEN_TABLE_STARTED=true
                    continue
                fi
                if [[ "$line" =~ ^\+[-+]+\+ ]] || [[ -z "${line// }" ]]; then
                    continue
                fi
                if [[ "$GEN_TABLE_STARTED" == true ]] && [[ "$line" =~ ^\|[[:space:]]*([^|]+)\|[[:space:]]*([^|]+)\|[[:space:]]*([^|]+)\|[[:space:]]*([^|]+)\|[[:space:]]*([^|]+)\| ]]; then
                    g_change_id=$(echo "${BASH_REMATCH[1]}" | xargs)
                    g_schema=$(echo "${BASH_REMATCH[4]}" | xargs)
                    g_object_name=$(echo "${BASH_REMATCH[5]}" | xargs)
                    if [[ "$g_change_id" != "Id" ]] && [[ ! "$g_change_id" =~ ^No ]]; then
                        GEN_CHANGE_IDS+=("$g_change_id")
                        GEN_FULL_NAMES+=("$g_schema.$g_object_name")
                    fi
                fi
            done <<< "$GEN_DIFF_OUTPUT"
            
            # Match the objects from the original list to get correct change IDs
            declare -a GEN_MATCHED_IDS
            for i in "${MATCHED_INDICES[@]}"; do
                target_name="${FULL_NAMES[$i]}"
                for j in "${!GEN_FULL_NAMES[@]}"; do
                    if [[ "${GEN_FULL_NAMES[$j]}" == "$target_name" ]]; then
                        GEN_MATCHED_IDS+=("${GEN_CHANGE_IDS[$j]}")
                        break
                    fi
                done
            done
            GEN_CHANGE_ID_LIST=$(IFS=','; echo "${GEN_MATCHED_IDS[*]}")
            
            # Create temp directory for generate preview
            TEMP_DIR=$(mktemp -d)
            
            # Generate to temp location
            if [[ "$ALL" == true ]] || [[ ${#GEN_MATCHED_IDS[@]} -eq 0 ]]; then
                flyway generate "-redgateCompare.sqlserver.options.behavior.includeDependencies=false" "-generate.location=$TEMP_DIR" "-generate.description=$DESCRIPTION" 2>&1 > /dev/null || true
            else
                flyway generate "-generate.changes=$GEN_CHANGE_ID_LIST" "-redgateCompare.sqlserver.options.behavior.includeDependencies=false" "-generate.location=$TEMP_DIR" "-generate.description=$DESCRIPTION" 2>&1 > /dev/null || true
            fi
            
            # Find and display the generated file
            if ls "$TEMP_DIR"/*.sql 1> /dev/null 2>&1; then
                for file in "$TEMP_DIR"/*.sql; do
                    print_color "$GREEN" "--- $(basename "$file") ---"
                    cat "$file"
                done
            else
                print_color "$GRAY" "No migration script generated"
            fi
            
            # Clean up temp directory
            rm -rf "$TEMP_DIR"
        fi
    fi
    
    exit 0
fi

# Step 4: Generate migration script (if not skipped)
if [[ "$SKIP_GENERATE" == false ]]; then
    print_color "$GREEN" "Step 4: Generating migration script..."
    
    # Run diff from development with build environment
    print_color "$GRAY" "  Running diff from development with build environment..."
    GEN_DIFF_OUTPUT=$(flyway diff "-diff.source=development" "-diff.target=migrations" "-diff.buildEnvironment=$TARGET" 2>&1) || {
        print_color "$RED" "Error: flyway diff (development -> migrations) failed"
        echo "$GEN_DIFF_OUTPUT"
        exit 1
    }
    
    if [[ "$ALL" == true ]]; then
        GENERATE_CMD="flyway generate \"-redgateCompare.sqlserver.options.behavior.includeDependencies=false\" \"-generate.description=$DESCRIPTION\""
    else
        GENERATE_CMD="flyway generate \"-generate.changes=$CHANGE_ID_LIST\" \"-redgateCompare.sqlserver.options.behavior.includeDependencies=false\" \"-generate.description=$DESCRIPTION\""
    fi
    print_color "$GRAY" "Executing: $GENERATE_CMD"
    
    GENERATE_OUTPUT=$(eval "$GENERATE_CMD" 2>&1) || {
        print_color "$RED" "Error: Flyway generate failed"
        echo "$GENERATE_OUTPUT"
        exit 1
    }
    
    echo "$GENERATE_OUTPUT"
    print_color "$GREEN" "✓ Migration generated successfully"
    echo ""
    
    # Step 5: Migrate to shadow
    print_color "$GREEN" "Step 5: Migrating to $TARGET..."
    MIGRATE_CMD="flyway migrate \"-environment=$TARGET\""
    print_color "$GRAY" "Executing: $MIGRATE_CMD"
    
    MIGRATE_OUTPUT=$(eval "$MIGRATE_CMD" 2>&1) || {
        print_color "$RED" "Error: Flyway migrate failed"
        echo "$MIGRATE_OUTPUT"
        exit 1
    }
    
    echo "$MIGRATE_OUTPUT"
    print_color "$GREEN" "✓ Migration applied to $TARGET successfully"
    echo ""
    
    # Step 6: Update schema model from shadow
    print_color "$GREEN" "Step 6: Updating schema model from $TARGET..."
    
    # Run diff from shadow to schemaModel
    print_color "$GRAY" "  Running diff from $TARGET to schemaModel..."
    MODEL_DIFF_OUTPUT=$(flyway diff "-diff.source=$TARGET" "-diff.target=schemaModel" 2>&1) || {
        print_color "$RED" "Error: flyway diff ($TARGET -> schemaModel) failed"
        echo "$MODEL_DIFF_OUTPUT"
        exit 1
    }
    
    if [[ "$ALL" == true ]]; then
        MODEL_CMD="flyway model \"-redgateCompare.sqlserver.options.behavior.includeDependencies=false\""
    else
        MODEL_CMD="flyway model \"-model.changes=$CHANGE_ID_LIST\" \"-redgateCompare.sqlserver.options.behavior.includeDependencies=false\""
    fi
    print_color "$GRAY" "Executing: $MODEL_CMD"
    
    MODEL_OUTPUT=$(eval "$MODEL_CMD" 2>&1) || {
        print_color "$RED" "Error: Flyway model failed"
        echo "$MODEL_OUTPUT"
        exit 1
    }
    
    echo "$MODEL_OUTPUT"
    print_color "$GREEN" "✓ Schema model updated successfully"
    echo ""
else
    # If skipping generate, just update schema model from development
    print_color "$YELLOW" "Step 4: Skipping migration generation"
    echo ""
    
    print_color "$GREEN" "Step 5: Updating schema model from development..."
    
    if [[ "$ALL" == true ]]; then
        MODEL_CMD="flyway model \"-redgateCompare.sqlserver.options.behavior.includeDependencies=false\""
    else
        MODEL_CMD="flyway model \"-model.changes=$CHANGE_ID_LIST\" \"-redgateCompare.sqlserver.options.behavior.includeDependencies=false\""
    fi
    print_color "$GRAY" "Executing: $MODEL_CMD"
    
    MODEL_OUTPUT=$(eval "$MODEL_CMD" 2>&1) || {
        print_color "$RED" "Error: Flyway model failed"
        echo "$MODEL_OUTPUT"
        exit 1
    }
    
    echo "$MODEL_OUTPUT"
    print_color "$GREEN" "✓ Schema model updated successfully"
    echo ""
fi

print_color "$CYAN" "======================================="
print_color "$GREEN" "Sync Complete!"
print_color "$CYAN" "======================================="
echo ""
print_color "$CYAN" "Summary:"
print_color "$GRAY" "  Objects processed: ${#MATCHED_INDICES[@]}"
for i in "${MATCHED_INDICES[@]}"; do
    print_color "$GRAY" "    - ${FULL_NAMES[$i]}"
done
echo ""
