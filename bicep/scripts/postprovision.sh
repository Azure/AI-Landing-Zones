#!/bin/sh

# Post-provision cleanup script for AI/ML Landing Zone
#
# This script removes the deploy directory created during preprovision.
#
# Usage: ./scripts/postprovision.sh

set -e  # Exit on any error

# Default values - can be overridden by environment variables
BICEP_ROOT="${BICEP_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
TEMPLATE_SPEC_RG="${AZURE_TS_RG:-}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"

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
    printf "${CYAN}[*] AI/ML Landing Zone - Post-Provision Cleanup${NC}\n"
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

# Validate environment variables
missing_vars=""
if [ -z "$RESOURCE_GROUP" ]; then
    missing_vars="${missing_vars}AZURE_RESOURCE_GROUP "
fi

if [ -n "$missing_vars" ]; then
    print_error "Missing required environment variables:"
    for var in $missing_vars; do
        printf "${RED}  - %s${NC}\n" "$var"
    done
    echo ""
    print_warning "To set them, choose one option:"
    echo ""
    printf "${CYAN}  Option 1 - Using azd (if using Azure Developer CLI):${NC}\n"
    for var in $missing_vars; do
        printf "${WHITE}    azd env set %s <value>${NC}\n" "$var"
    done
    echo ""
    printf "${CYAN}  Option 2 - Using shell environment variables:${NC}\n"
    for var in $missing_vars; do
        printf "${WHITE}    export %s=\"your-value\"${NC}\n" "$var"
    done
    echo ""
    exit 1
fi

print_header

# Set default Template Spec RG if not specified
if [ -z "$TEMPLATE_SPEC_RG" ]; then
    TEMPLATE_SPEC_RG="$RESOURCE_GROUP"
fi

print_info "Configuration:"
print_white "Resource Group: $RESOURCE_GROUP"
print_white "Template Spec RG: $TEMPLATE_SPEC_RG"
echo ""

#===============================================================================
# AZURE AUTHENTICATION SETUP
#===============================================================================

# Set Azure subscription if specified
if [ -n "$SUBSCRIPTION_ID" ] && [ "$SUBSCRIPTION_ID" != "" ]; then
    az account set --subscription "$SUBSCRIPTION_ID" > /dev/null
    print_success "Set subscription: $SUBSCRIPTION_ID"
fi

# Define paths
deploy_dir="$BICEP_ROOT/deploy"

#===============================================================================
# STEP 1: TEMPLATE SPEC CLEANUP
#===============================================================================

# Step 1: Clean up Template Specs
print_step "1" "Step 1: Cleaning up Template Specs..."

# Only delete Template Specs if they are in the same RG as the deployment
# Don't delete from dedicated Template Spec RGs as they may be shared
if [ "$TEMPLATE_SPEC_RG" = "$RESOURCE_GROUP" ]; then
    # Extract environment name from ResourceGroup (assumes rg-<envname> pattern, fallback to 'main')
    env_prefix=$(echo "$RESOURCE_GROUP" | sed -n 's/^rg-\(.*\)$/\1/p')
    if [ -z "$env_prefix" ]; then
        env_prefix="main"
    fi
    
    ts_pattern="ts-$env_prefix-wrp-*"
    
    print_gray "[?] Looking for Template Specs with pattern: $ts_pattern"
    
    # Get all Template Specs matching our pattern
    template_specs=$(az ts list -g "$TEMPLATE_SPEC_RG" --query "[?starts_with(name, 'ts-$env_prefix-wrp-')].name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$template_specs" ]; then
        # Count template specs
        ts_count=$(echo "$template_specs" | wc -l)
        print_info "Found $ts_count Template Specs to remove"
        
        # Process each template spec
        echo "$template_specs" | while IFS= read -r ts_name; do
            ts_name=$(echo "$ts_name" | tr -d '\r\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [ -n "$ts_name" ]; then
                printf "${GRAY}    [X] Removing: %s${NC}\n" "$ts_name"
                if az ts delete -g "$TEMPLATE_SPEC_RG" -n "$ts_name" --yes --only-show-errors > /dev/null 2>&1; then
                    printf "${GREEN}    [+] Removed: %s${NC}\n" "$ts_name"
                else
                    printf "${YELLOW}    [!] Failed to remove: %s${NC}\n" "$ts_name"
                fi
            fi
        done
    else
        print_gray "No Template Specs found matching pattern: $ts_pattern"
    fi
else
    print_gray "Template Specs are in dedicated RG ($TEMPLATE_SPEC_RG), skipping cleanup"
    print_gray "(Dedicated Template Spec RGs may be shared and should not be auto-cleaned)"
fi

echo ""

#===============================================================================
# STEP 2: REMOVE TEMPORARY TAGS
#===============================================================================

print_step "2" "Step 2: Removing temporary Resource Group tags..."
print_info "Removing temporary Resource Group tags..."

rg_id="$(az group show --name "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null || echo "")"
if [ -n "$rg_id" ]; then
    if az tag update --resource-id "$rg_id" --operation Delete --tags SecurityControl > /dev/null 2>&1; then
        print_success "Removed tags from Resource Group: $RESOURCE_GROUP"
    else
        print_warning "Failed to remove tags from Resource Group: $RESOURCE_GROUP"
    fi
else
    print_warning "Failed to resolve resource ID for Resource Group: $RESOURCE_GROUP"
fi

if [ -n "$TEMPLATE_SPEC_RG" ] && [ "$TEMPLATE_SPEC_RG" != "$RESOURCE_GROUP" ]; then
    ts_rg_id="$(az group show --name "$TEMPLATE_SPEC_RG" --query id -o tsv 2>/dev/null || echo "")"
    if [ -n "$ts_rg_id" ]; then
        if az tag update --resource-id "$ts_rg_id" --operation Delete --tags SecurityControl > /dev/null 2>&1; then
            print_success "Removed tags from Template Spec Resource Group: $TEMPLATE_SPEC_RG"
        else
            print_warning "Failed to remove tags from Template Spec Resource Group: $TEMPLATE_SPEC_RG"
        fi
    else
        print_warning "Failed to resolve resource ID for Template Spec Resource Group: $TEMPLATE_SPEC_RG"
    fi
fi

echo ""

#===============================================================================
# STEP 3: DIRECTORY CLEANUP
#===============================================================================

# Step 3: Clean up deploy directory
print_step "3" "Step 3: Cleaning up deploy directory..."
if [ -d "$deploy_dir" ]; then
    rm -rf "$deploy_dir"
    print_success "Removed deploy directory: ./deploy/"
else
    print_gray "No deploy directory found to remove"
fi

#===============================================================================
# COMPLETION SUMMARY
#===============================================================================

echo ""
print_success "[OK] Cleanup complete!"
echo ""
