#!/bin/bash
# access-review.sh
# Quarterly access review for Contoso's Zero Trust IAM system
# Generates a report of all group memberships for human review
# Flags accounts that may need attention based on common patterns
# Usage: ./access-review.sh
# Requirements: Azure CLI authenticated, User Administrator role in Entra ID

set -e

echo "================================================"
echo "Contoso — Quarterly access review report"
echo "Generated: $(date)"
echo "Review period: $(date -d '-90 days' '+%Y-%m-%d') to $(date '+%Y-%m-%d')"
echo "================================================"

# Check Azure CLI is available
if ! command -v az &>/dev/null; then
  echo "ERROR: Azure CLI not installed" >&2
  exit 1
fi

echo ""
echo "--- Group membership summary ---"
echo ""

# Review each group
for GROUP in grp-developers grp-finance grp-operations grp-contractors; do

  echo "Group: $GROUP"
  echo "Members:"

  # Get group object ID
  GROUP_ID=$(az ad group show \
    --group "$GROUP" \
    --query id \
    --output tsv 2>/dev/null)

  if [ -z "$GROUP_ID" ]; then
    echo "  WARNING: Group not found — may not be created yet"
    echo ""
    continue
  fi

  # List all members
  MEMBERS=$(az ad group member list \
    --group "$GROUP_ID" \
    --query "[].{Name:displayName, UPN:userPrincipalName, Enabled:accountEnabled}" \
    --output table 2>/dev/null)

  if [ -z "$MEMBERS" ]; then
    echo "  No members found"
  else
    echo "$MEMBERS"
  fi

  # Count members
  MEMBER_COUNT=$(az ad group member list \
    --group "$GROUP_ID" \
    --query "length([])" \
    --output tsv 2>/dev/null)

  echo "Total members: $MEMBER_COUNT"
  echo ""

done

echo "--- Accounts requiring attention ---"
echo ""

# Flag disabled accounts still in groups
echo "Disabled accounts with active group memberships:"
echo "(These should be reviewed — disabled users retaining group membership)"
echo ""

for GROUP in grp-developers grp-finance grp-operations grp-contractors; do

  GROUP_ID=$(az ad group show \
    --group "$GROUP" \
    --query id \
    --output tsv 2>/dev/null)

  if [ -z "$GROUP_ID" ]; then
    continue
  fi

  DISABLED_MEMBERS=$(az ad group member list \
    --group "$GROUP_ID" \
    --query "[?accountEnabled==false].{Name:displayName, UPN:userPrincipalName}" \
    --output table 2>/dev/null)

  if [ -n "$DISABLED_MEMBERS" ]; then
    echo "WARNING — Disabled accounts in $GROUP:"
    echo "$DISABLED_MEMBERS"
    echo ""
  fi

done

# Flag contractor group members
echo "--- Contractor access review (quarterly mandatory) ---"
echo ""
echo "The following contractors require access confirmation:"
echo "Review with line managers — remove access if no longer required"
echo ""

CONTRACTOR_GROUP_ID=$(az ad group show \
  --group "grp-contractors" \
  --query id \
  --output tsv 2>/dev/null)

if [ -n "$CONTRACTOR_GROUP_ID" ]; then
  az ad group member list \
    --group "$CONTRACTOR_GROUP_ID" \
    --query "[].{Name:displayName, UPN:userPrincipalName}" \
    --output table 2>/dev/null
fi

echo ""
echo "================================================"
echo "Review complete: $(date)"
echo ""
echo "Actions required after reviewing this report:"
echo "  □ Confirm each group member still requires their access"
echo "  □ Run offboarding.sh for any departed employees found"
echo "  □ Update group memberships for role changes"
echo "  □ Remove contractor access that is no longer needed"
echo "  □ Document review completion for compliance records"
echo "  □ Schedule next review in 90 days"
echo "================================================"
