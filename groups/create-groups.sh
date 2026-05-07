#!/bin/bash
# create-groups.sh
# Creates security groups for Contoso's Zero Trust IAM system
# Each group represents a distinct team with different access requirements
# Usage: ./create-groups.sh
# Requirements: Azure CLI authenticated, User Administrator role in Entra ID

set -e

echo "================================================"
echo "Contoso — Creating security groups"
echo "Started: $(date)"
echo "================================================"

# Check Azure CLI is available
if ! command -v az &>/dev/null; then
  echo "ERROR: Azure CLI not installed" >&2
  exit 1
fi

echo ""
echo "Creating security groups..."
echo ""

# Developers group
# Members: engineers who build and deploy applications
# Access: Contributor on development resource groups
az ad group create \
  --display-name "grp-developers" \
  --mail-nickname "grp-developers" \
  --description "Engineering team — application development and deployment"
echo "✓ grp-developers created"

# Finance group  
# Members: finance team managing budgets and cost reporting
# Access: Cost Management Reader at subscription scope
az ad group create \
  --display-name "grp-finance" \
  --mail-nickname "grp-finance" \
  --description "Finance team — budget management and cost reporting"
echo "✓ grp-finance created"

# Operations group
# Members: infrastructure team managing VMs and Azure resources
# Access: Custom VM Operator role on production resource groups
az ad group create \
  --display-name "grp-operations" \
  --mail-nickname "grp-operations" \
  --description "Operations team — infrastructure management and VM operations"
echo "✓ grp-operations created"

# Contractors group
# Members: external contractors with time-limited access
# Access: Reader only — strictly scoped, reviewed quarterly
az ad group create \
  --display-name "grp-contractors" \
  --mail-nickname "grp-contractors" \
  --description "External contractors — read-only scoped access, quarterly review required"
echo "✓ grp-contractors created"

echo ""
echo "================================================"
echo "Groups created successfully: $(date)"
echo ""
echo "Next steps:"
echo "1. Add members to each group via Entra ID portal"
echo "2. Assign roles using scripts/assign-roles.sh"
echo "3. Schedule quarterly access reviews for grp-contractors"
echo "================================================"
