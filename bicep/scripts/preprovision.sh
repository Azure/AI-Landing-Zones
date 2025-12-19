#!/bin/sh

# Preprovision script for AI/ML Landing Zone with Template Specs
#
# This script:
# 1. Creates a copy of the infra directory as 'deploy'
# 2. Builds Template Specs from all wrappers or uses existing ones
# 3. Replaces wrapper references with Template Spec references in deploy/main.bicep
# 4. Creates deploy/main.bicep ready for deployment
#
# Environment Variables:
# - AZURE_SUBSCRIPTION_ID: Required. Azure subscription ID (GUID format)
# - AZURE_LOCATION: Required. Azure region (e.g., eastus2, westus3)
# - AZURE_RESOURCE_GROUP: Required. Resource group name
# - AZURE_TS_RG: If set, uses existing Template Specs from this resource group instead of creating new ones
#
# Usage: 
#   ./scripts/preprovision.sh                    # Deploy with new Template Specs (default)
#   AZURE_TS_RG=rg-shared-templates ./scripts/preprovision.sh  # Use existing Template Specs

set -e  # Exit on any error

# Default values - can be overridden by environment variables
BICEP_ROOT="${BICEP_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOCATION="${AZURE_LOCATION:-}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
TEMPLATE_SPEC_RG="${AZURE_TS_RG:-}"

# Color codes for output (compatible with most terminals)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
DARKGRAY='\033[1;30m'
NC='\033[0m' # No Color

# Helper functions for colored output
print_header() {
    echo ""
    printf "${CYAN}[*] AI/ML Landing Zone - Template Spec Preprovision${NC}\n"
    printf "${DARKGRAY}==================================================${NC}\n"
    echo ""
}

print_error() {
    printf "${RED}[X] Error: %s${NC}\n" "$1"
}

print_warning() {
    printf "${YELLOW}[!] %s${NC}\n" "$1"
}

print_info() {
    printf "${YELLOW}[i] %s${NC}\n" "$1"
}

print_success() {
    printf "${GREEN}[+] %s${NC}\n" "$1"
}

print_step() {
    printf "${CYAN}[%s] %s${NC}\n" "$1" "$2"
}

print_substep() {
    printf "${YELLOW}  %s${NC}\n" "$1"
}

print_gray() {
    printf "${GRAY}  %s${NC}\n" "$1"
}

print_white() {
    printf "${WHITE}  %s${NC}\n" "$1"
}

#===============================================================================
# INITIALIZATION & VALIDATION
#===============================================================================

print_header

#===============================================================================
# AUTHENTICATION CHECK
#===============================================================================

print_step "0" "Step 0: Checking Azure authentication..."

# Check Azure CLI authentication
print_gray "Checking Azure CLI authentication..."
if ! az account show > /dev/null 2>&1; then
    echo ""
    print_error "Not authenticated with Azure CLI"
    print_warning "Please authenticate before running this script:"
    print_warning "    1. Run: az login"
    print_warning "    2. Set subscription: az account set --subscription <subscription-id>"
    echo ""
    exit 1
fi

CURRENT_ACCOUNT=$(az account show --query "{name:name, id:id}" -o json 2>/dev/null)
print_success "Azure CLI authenticated"
if [ -n "$CURRENT_ACCOUNT" ]; then
    ACCOUNT_NAME=$(echo "$CURRENT_ACCOUNT" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    ACCOUNT_ID=$(echo "$CURRENT_ACCOUNT" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    printf "${GRAY}  [i] Current account: %s (%s)${NC}\n" "$ACCOUNT_NAME" "$ACCOUNT_ID"
fi

# Check Azure Developer CLI authentication (optional but recommended)
print_gray "Checking Azure Developer CLI authentication..."
if azd auth login --check-status > /dev/null 2>&1; then
    print_success "Azure Developer CLI authenticated"
else
    print_warning "Azure Developer CLI not authenticated (optional)"
    print_gray "[i] You can authenticate with: azd auth login"
fi

echo ""

# Check and prompt for required environment variables
missing_vars=""
if [ -z "$LOCATION" ]; then
    missing_vars="${missing_vars}AZURE_LOCATION "
fi
if [ -z "$RESOURCE_GROUP" ]; then
    missing_vars="${missing_vars}AZURE_RESOURCE_GROUP "
fi
if [ -z "$SUBSCRIPTION_ID" ]; then
    missing_vars="${missing_vars}AZURE_SUBSCRIPTION_ID "
fi

if [ -n "$missing_vars" ]; then
    print_warning "Some required environment variables are missing:"
    for var in $missing_vars; do
        printf "${YELLOW}  - %s${NC}\n" "$var"
    done
    echo ""
    printf "${CYAN}[?] Let's set them interactively...${NC}\n"
    echo ""
    
    # Prompt for AZURE_LOCATION if missing
    if [ -z "$LOCATION" ]; then
        attempts=0
        max_attempts=50
        while [ -z "$LOCATION" ]; do
            attempts=$((attempts + 1))
            if [ $attempts -gt $max_attempts ]; then
                printf "${RED}  [X] Too many attempts. Exiting...${NC}\n"
                exit 1
            fi
            printf "${WHITE}Enter location (Azure region, e.g., eastus2, westus3, centralus): ${NC}"
            read -r LOCATION
            LOCATION=$(echo "$LOCATION" | xargs)  # Trim whitespace
            if [ -z "$LOCATION" ]; then
                printf "${RED}  [!] Location cannot be empty. Please enter a valid Azure region.${NC}\n"
            fi
        done
        
        printf "${GREEN}  [+] Setting AZURE_LOCATION = '%s'${NC}\n" "$LOCATION"
        if azd env set AZURE_LOCATION "$LOCATION" >/dev/null 2>&1; then
            export AZURE_LOCATION="$LOCATION"
            printf "${GREEN}  [+] Successfully set AZURE_LOCATION${NC}\n"
        else
            printf "${RED}  [X] Failed to set AZURE_LOCATION using azd${NC}\n"
            printf "${YELLOW}  [i] Setting as environment variable for this session only${NC}\n"
            export AZURE_LOCATION="$LOCATION"
        fi
    fi
    
    # Prompt for AZURE_RESOURCE_GROUP if missing
    if [ -z "$RESOURCE_GROUP" ]; then
        attempts=0
        max_attempts=50
        while [ -z "$RESOURCE_GROUP" ]; do
            attempts=$((attempts + 1))
            if [ $attempts -gt $max_attempts ]; then
                printf "${RED}  [X] Too many attempts. Exiting...${NC}\n"
                exit 1
            fi
            printf "${WHITE}Enter resourceGroup name (e.g., rg-myproject, rg-aiml-dev): ${NC}"
            read -r RESOURCE_GROUP
            RESOURCE_GROUP=$(echo "$RESOURCE_GROUP" | xargs)  # Trim whitespace
            if [ -z "$RESOURCE_GROUP" ]; then
                printf "${RED}  [!] ResourceGroup name cannot be empty. Please enter a valid name.${NC}\n"
            fi
        done
        
        printf "${GREEN}  [+] Setting AZURE_RESOURCE_GROUP = '%s'${NC}\n" "$RESOURCE_GROUP"
        if azd env set AZURE_RESOURCE_GROUP "$RESOURCE_GROUP" >/dev/null 2>&1; then
            export AZURE_RESOURCE_GROUP="$RESOURCE_GROUP"
            printf "${GREEN}  [+] Successfully set AZURE_RESOURCE_GROUP${NC}\n"
        else
            printf "${RED}  [X] Failed to set AZURE_RESOURCE_GROUP using azd${NC}\n"
            printf "${YELLOW}  [i] Setting as environment variable for this session only${NC}\n"
            export AZURE_RESOURCE_GROUP="$RESOURCE_GROUP"
        fi
    fi
    
    # Prompt for AZURE_SUBSCRIPTION_ID if missing
    if [ -z "$SUBSCRIPTION_ID" ]; then
        attempts=0
        max_attempts=50
        while [ -z "$SUBSCRIPTION_ID" ]; do
            attempts=$((attempts + 1))
            if [ $attempts -gt $max_attempts ]; then
                printf "${RED}  [X] Too many attempts. Exiting...${NC}\n"
                exit 1
            fi
            printf "${WHITE}Enter subscription ID (Azure subscription GUID): ${NC}"
            read -r SUBSCRIPTION_ID
            SUBSCRIPTION_ID=$(echo "$SUBSCRIPTION_ID" | xargs)  # Trim whitespace
            if [ -z "$SUBSCRIPTION_ID" ]; then
                printf "${RED}  [!] Subscription ID cannot be empty. Please enter a valid Azure subscription GUID.${NC}\n"
            # Validate GUID format
            elif ! echo "$SUBSCRIPTION_ID" | grep -qE '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'; then
                printf "${RED}  [!] Invalid subscription ID format. Please enter a valid GUID format (e.g., 12345678-1234-1234-1234-123456789012).${NC}\n"
                SUBSCRIPTION_ID=""
            fi
        done
        
        printf "${GREEN}  [+] Setting AZURE_SUBSCRIPTION_ID = '%s'${NC}\n" "$SUBSCRIPTION_ID"
        if azd env set AZURE_SUBSCRIPTION_ID "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
            export AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
            printf "${GREEN}  [+] Successfully set AZURE_SUBSCRIPTION_ID${NC}\n"
        else
            printf "${RED}  [X] Failed to set AZURE_SUBSCRIPTION_ID using azd${NC}\n"
            printf "${YELLOW}  [i] Setting as environment variable for this session only${NC}\n"
            export AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
        fi
    fi
    
    echo ""
fi

# Determine behavior based on AZURE_TS_RG
if [ -n "$TEMPLATE_SPEC_RG" ]; then
    USE_EXISTING_TEMPLATE_SPECS="true"
else
    USE_EXISTING_TEMPLATE_SPECS="false"
    TEMPLATE_SPEC_RG="$RESOURCE_GROUP"
fi

print_info "Configuration:"
print_white "Subscription ID: $SUBSCRIPTION_ID"
print_white "Location: $LOCATION"  
print_white "Resource Group: $RESOURCE_GROUP"
print_white "Template Spec RG: $TEMPLATE_SPEC_RG"
print_white "Use Existing Template Specs: $USE_EXISTING_TEMPLATE_SPECS"
echo ""

#===============================================================================
# STEP 1: SETUP & DIRECTORY PREPARATION
#===============================================================================

# Define paths
infra_dir="$BICEP_ROOT/infra"
deploy_dir="$BICEP_ROOT/deploy"
deploy_wrappers_dir="$deploy_dir/wrappers"

# Step 1: Copy infra directory to deploy
print_step "1" "Step 1: Creating deploy directory..."
if [ -d "$deploy_dir" ]; then
    rm -rf "$deploy_dir"
    print_gray "Removed existing deploy directory"
fi

cp -r "$infra_dir" "$deploy_dir"
print_success "Copied infra → deploy"

#===============================================================================
# STEP 2: AZURE AUTHENTICATION & RESOURCE GROUP SETUP
#===============================================================================

# Step 2: Set Azure subscription
echo ""
print_step "2" "Step 2: Azure setup..."
if [ -n "$SUBSCRIPTION_ID" ] && [ "$SUBSCRIPTION_ID" != "" ]; then
    az account set --subscription "$SUBSCRIPTION_ID" > /dev/null
    print_success "Set subscription: $SUBSCRIPTION_ID"
fi

# Ensure resource groups exist
print_gray "Checking resource groups..."

# Check if main resource group exists
rg_exists=$(az group show --name "$RESOURCE_GROUP" --only-show-errors --query name --output tsv 2>/dev/null || echo "")

if [ -z "$rg_exists" ]; then
    print_substep "Creating resource group: $RESOURCE_GROUP"
    if az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --only-show-errors > /dev/null 2>&1; then
        print_success "Created resource group: $RESOURCE_GROUP"
    else
        print_error "Failed to create resource group: $RESOURCE_GROUP"
        echo ""
        print_warning "Possible solutions:"
        print_white "1. Ensure you have 'Contributor' or 'Owner' role on the subscription"
        print_white "2. Ask your Azure administrator to create the resource group"
        print_white "3. Use an existing resource group you have access to"
        print_white "4. Check if you're signed into the correct Azure account: az account show"
        echo ""
        exit 1
    fi
else
    print_success "Resource group already exists: $RESOURCE_GROUP"
fi

# Check Template Spec resource group if different (only create if not using existing)
if [ "$TEMPLATE_SPEC_RG" != "$RESOURCE_GROUP" ] && [ "$USE_EXISTING_TEMPLATE_SPECS" = "false" ]; then
    ts_rg_exists=$(az group show --name "$TEMPLATE_SPEC_RG" --only-show-errors --query name --output tsv 2>/dev/null || echo "")
    
    if [ -z "$ts_rg_exists" ]; then
        print_substep "Creating Template Spec resource group: $TEMPLATE_SPEC_RG"
        if az group create --name "$TEMPLATE_SPEC_RG" --location "$LOCATION" --only-show-errors > /dev/null 2>&1; then
            print_success "Created Template Spec resource group: $TEMPLATE_SPEC_RG"
        else
            print_error "Failed to create Template Spec resource group: $TEMPLATE_SPEC_RG"
            echo ""
            print_warning "Possible solutions:"
            print_white "1. Ensure you have 'Contributor' or 'Owner' role on the subscription"
            print_white "2. Ask your Azure administrator to create the resource group"
            print_white "3. Set AZURE_TS_RG to an existing resource group you have access to"
            print_white "4. Remove AZURE_TS_RG to use the same RG as the main deployment"
            echo ""
            exit 1
        fi
    else
        print_success "Template Spec resource group already exists: $TEMPLATE_SPEC_RG"
    fi
fi

#===============================================================================
# STEP 3: TEMPLATE SPEC CREATION & PUBLISHING (PARALLEL)
#===============================================================================

# Create temporary files for parallel processing
temp_mapping_file=$(mktemp)
temp_job_dir=$(mktemp -d)
trap 'rm -f "$temp_mapping_file"; rm -rf "$temp_job_dir"' EXIT

# Step 3: Template Specs processing
echo ""
if [ "$USE_EXISTING_TEMPLATE_SPECS" = "true" ]; then
    print_step "3" "Step 3: Getting existing Template Spec IDs (parallel)..."
else
    print_step "3" "Step 3: Building Template Specs (parallel)..."
fi

# Determine max parallel jobs (default: min of processor count or 10)
if command -v nproc > /dev/null 2>&1; then
    max_parallel_jobs=$(nproc)
elif command -v sysctl > /dev/null 2>&1; then
    max_parallel_jobs=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
else
    max_parallel_jobs=4
fi
max_parallel_jobs=$((max_parallel_jobs > 10 ? 10 : max_parallel_jobs))

# Allow override via environment variable
if [ -n "$AZURE_PARALLEL_JOBS" ]; then
    max_parallel_jobs="$AZURE_PARALLEL_JOBS"
fi

# Count wrapper files
wrapper_count=$(find "$deploy_wrappers_dir" -name "*.bicep" -type f | wc -l)
print_info "Processing $wrapper_count wrappers with up to $max_parallel_jobs parallel jobs"
echo ""

# Extract environment name once (used by all jobs)
env_prefix=$(echo "$RESOURCE_GROUP" | sed -n 's/^rg-\(.*\)$/\1/p')
if [ -z "$env_prefix" ]; then
    env_prefix="main"
fi

# Function to process a single wrapper (executed in background)
process_wrapper() {
    wrapper_file="$1"
    job_id="$2"
    result_file="$temp_job_dir/result_$job_id"
    
    wrapper_name=$(basename "$wrapper_file" .bicep)
    
    # Truncate long wrapper names
    if [ ${#wrapper_name} -gt 40 ]; then
        short_wrapper_name=$(echo "$wrapper_name" | awk -F. '{
            if (NF >= 3) {
                result = ""
                for(i=1; i<NF; i++) {
                    result = result substr($i, 1, 1) "."
                }
                result = result $NF
                print result
            } else {
                print substr($0, 1, 40)
            }
        }')
    else
        short_wrapper_name="$wrapper_name"
    fi
    
    ts_name="ts-$env_prefix-wrp-$short_wrapper_name"
    version="current"
    
    # Build bicep to JSON only if we're creating new Template Specs
    json_path=""
    if [ "$USE_EXISTING_TEMPLATE_SPECS" != "true" ]; then
        json_path="${wrapper_file%.*}.json"
        
        if command -v bicep > /dev/null 2>&1; then
            bicep build "$wrapper_file" --outfile "$json_path" > /dev/null 2>&1
        else
            az bicep build --file "$wrapper_file" --outfile "$json_path" > /dev/null 2>&1
        fi
        
        if [ ! -f "$json_path" ]; then
            echo "FAILED|$wrapper_name|Failed to build Bicep" > "$result_file"
            return 1
        fi
    fi
    
    # Check for existing Template Spec or create new one
    ts_id=""
    action=""
    
    if [ "$USE_EXISTING_TEMPLATE_SPECS" = "true" ]; then
        # Use existing Template Specs
        ts_id=$(az ts show -g "$TEMPLATE_SPEC_RG" -n "$ts_name" -v "$version" --query id -o tsv 2>/dev/null || \
                az ts show -g "$TEMPLATE_SPEC_RG" -n "$ts_name" --query id -o tsv 2>/dev/null || echo "")
        
        if [ -n "$ts_id" ]; then
            action="Found"
            echo "SUCCESS|$wrapper_name|$ts_id|$ts_name|$action" > "$result_file"
        else
            echo "FAILED|$wrapper_name|Template Spec not found" > "$result_file"
            return 1
        fi
    else
        # Check if Template Spec exists
        existing_ts=$(az ts list -g "$TEMPLATE_SPEC_RG" --query "[?name=='$ts_name'].name" -o tsv 2>/dev/null || echo "")
        
        if [ -n "$existing_ts" ]; then
            # Reuse existing
            ts_id=$(az ts show -g "$TEMPLATE_SPEC_RG" -n "$ts_name" -v "$version" --query id -o tsv 2>/dev/null || \
                    az ts show -g "$TEMPLATE_SPEC_RG" -n "$ts_name" --query id -o tsv 2>/dev/null || echo "")
            action="Reused"
        else
            # Create new template spec
            if az ts create -g "$TEMPLATE_SPEC_RG" -n "$ts_name" -v "$version" -l "$LOCATION" \
                    --template-file "$json_path" --display-name "Wrapper: $wrapper_name" \
                    --description "Auto-generated Template Spec for $wrapper_name wrapper" \
                    --only-show-errors > /dev/null 2>&1; then
                
                ts_id=$(az ts show -g "$TEMPLATE_SPEC_RG" -n "$ts_name" -v "$version" --query id -o tsv 2>/dev/null || echo "")
                action="Created"
            fi
        fi
        
        if [ -n "$ts_id" ]; then
            echo "SUCCESS|$wrapper_name|$ts_id|$ts_name|$action" > "$result_file"
        else
            echo "FAILED|$wrapper_name|Failed to create/get Template Spec" > "$result_file"
            return 1
        fi
    fi
    
    # Clean up JSON file
    [ -f "$json_path" ] && rm -f "$json_path"
    
    return 0
}

# Export variables and functions for background jobs
export TEMPLATE_SPEC_RG LOCATION USE_EXISTING_TEMPLATE_SPECS temp_job_dir env_prefix
export -f process_wrapper

# SPAWN PHASE: Launch parallel jobs
pids=()
job_id=0
start_time=$(date +%s)

for wrapper_file in "$deploy_wrappers_dir"/*.bicep; do
    [ ! -f "$wrapper_file" ] && continue
    
    # Start background job
    process_wrapper "$wrapper_file" "$job_id" &
    pids+=($!)
    job_id=$((job_id + 1))
    
    # THROTTLE: Wait if too many jobs running
    while [ $(jobs -r | wc -l) -ge $max_parallel_jobs ]; do
        sleep 0.1
    done
done

print_success "[⚡] All $job_id jobs spawned, monitoring completion..."
echo ""

# MONITOR PHASE: Wait for all jobs and collect results
completed=0
failed=0
created=0
reused=0
found=0

for pid in "${pids[@]}"; do
    wait "$pid"
    completed=$((completed + 1))
    progress_percent=$((completed * 100 / job_id))
    
    # Find and process result file for this job
    result_files=$(find "$temp_job_dir" -name "result_*" -type f 2>/dev/null)
    for result_file in $result_files; do
        if [ -f "$result_file" ]; then
            result=$(cat "$result_file")
            rm -f "$result_file"
            
            status=$(echo "$result" | cut -d'|' -f1)
            wrapper_name=$(echo "$result" | cut -d'|' -f2)
            
            if [ "$status" = "SUCCESS" ]; then
                ts_id=$(echo "$result" | cut -d'|' -f3)
                ts_name=$(echo "$result" | cut -d'|' -f4)
                action=$(echo "$result" | cut -d'|' -f5)
                
                # Store in mapping file
                echo "$(basename "$wrapper_name").bicep|$ts_id" >> "$temp_mapping_file"
                
                # Track actions
                case "$action" in
                    "Created") created=$((created + 1)); symbol="✓" ;;
                    "Reused") reused=$((reused + 1)); symbol="↻" ;;
                    "Found") found=$((found + 1)); symbol="→" ;;
                    *) symbol="+" ;;
                esac
                
                printf "${GREEN}  [%s] (%d/%d | %d%%) %s${NC}\n" "$symbol" "$completed" "$job_id" "$progress_percent" "$wrapper_name"
            else
                failed=$((failed + 1))
                error_msg=$(echo "$result" | cut -d'|' -f3)
                printf "${RED}  [✗] (%d/%d | %d%%) %s - %s${NC}\n" "$completed" "$job_id" "$progress_percent" "$wrapper_name" "$error_msg"
            fi
        fi
    done
done

# Calculate duration and speedup
end_time=$(date +%s)
duration=$((end_time - start_time))
estimated_sequential=$((job_id * 8))
if [ $duration -gt 0 ]; then
    speedup=$(awk "BEGIN {printf \"%.1f\", $estimated_sequential / $duration}")
else
    speedup="1.0"
fi

# Summary
echo ""
print_success "[✓] Template Specs processing completed in ${duration}s!"
print_info "    Success: $((completed - failed)) | Failed: $failed"
[ $created -gt 0 ] && print_white "    Created: $created"
[ $reused -gt 0 ] && print_white "    Reused: $reused"
[ $found -gt 0 ] && print_white "    Found: $found"
if [ $(echo "$speedup > 1" | bc -l 2>/dev/null || echo "0") -eq 1 ]; then
    printf "${YELLOW}  [⚡] Speedup: ${speedup}x faster than sequential processing!${NC}\n"
fi

#===============================================================================
# STEP 4: BICEP TEMPLATE TRANSFORMATION
#===============================================================================

# Step 4: Update main.bicep with Template Spec references (in-place)
echo ""
print_step "4" "Step 4: Updating main.bicep references..."

main_bicep_path="$deploy_dir/main.bicep"

if [ -f "$main_bicep_path" ] && [ -s "$temp_mapping_file" ]; then
    replacement_count=0
    
    # Create a temporary file for the updated content
    temp_bicep_file=$(mktemp)
    trap 'rm -f "$temp_bicep_file" "$temp_mapping_file"' EXIT
    
    # Copy original content to temp file
    cp "$main_bicep_path" "$temp_bicep_file"
    
    # Process each template spec mapping
    while IFS='|' read -r wrapper_file ts_id; do
        [ -z "$wrapper_file" ] || [ -z "$ts_id" ] && continue
        
        wrapper_path="wrappers/$wrapper_file"
        
        # Convert ARM Resource ID to Bicep Template Spec format
        if echo "$ts_id" | grep -q "/subscriptions/.*/resourceGroups/.*/providers/Microsoft.Resources/templateSpecs/.*/versions/.*"; then
            subscription=$(echo "$ts_id" | sed 's|.*/subscriptions/\([^/]*\)/.*|\1|')
            resource_group=$(echo "$ts_id" | sed 's|.*/resourceGroups/\([^/]*\)/.*|\1|')
            template_spec_name=$(echo "$ts_id" | sed 's|.*/templateSpecs/\([^/]*\)/.*|\1|')
            version=$(echo "$ts_id" | sed 's|.*/versions/\([^/]*\).*|\1|')
            ts_reference="ts:$subscription/$resource_group/$template_spec_name:$version"
            
            # Replace in the temp file
            if grep -q "'$wrapper_path'" "$temp_bicep_file"; then
                sed "s|'$wrapper_path'|'$ts_reference'|g" "$temp_bicep_file" > "${temp_bicep_file}.new"
                mv "${temp_bicep_file}.new" "$temp_bicep_file"
                replacement_count=$((replacement_count + 1))
                
                print_success "  [+] Replaced:"
                print_white "    $wrapper_path"
                print_gray "    -> $ts_reference"
            fi
        else
            print_warning "  [!] Skipping $wrapper_file - invalid Template Spec ID format: $ts_id"
        fi
    done < "$temp_mapping_file"
    
    # Save the updated content back to main.bicep
    cp "$temp_bicep_file" "$main_bicep_path"
    rm -f "$temp_bicep_file"
    
    echo ""
    print_success "  [+] Updated deploy/main.bicep ($replacement_count references replaced)"
fi

#===============================================================================
# COMPLETION SUMMARY
#===============================================================================

# Count template specs created (if any)
template_spec_count=$(wc -l < "$temp_mapping_file" 2>/dev/null || echo "0")

echo ""
print_success "[OK] Preprovision complete!"
if [ "$USE_EXISTING_TEMPLATE_SPECS" = "true" ]; then
    print_white "  Using existing Template Specs from: $TEMPLATE_SPEC_RG"
else
    print_white "  Template Specs created: $template_spec_count"
fi
print_white "  Template Spec references updated in main.bicep"
print_white "  Deploy directory ready: ./bicep/deploy/"
echo ""