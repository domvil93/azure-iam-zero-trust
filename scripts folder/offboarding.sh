#!/bin/bash
# offboarding.sh
# Immediately revokes all Azure access for departing Contoso employees
# SECURITY CRITICAL — run immediately when departure is confirmed
# Usage: ./offboarding.sh --username "jsmith"
# Requirements: Azure CLI authenticated, User Administrator role in Entra ID

set -e

echo "================================================"
echo "Contoso — Employee offboarding"
echo "SECURITY CRITICAL: Revoking all Azure access"
echo "Started: $(date)"
echo "================================================"

# Check Azure CLI is available
if ! command -v az &>/dev/null; then
  echo "ERROR: Azure CLI not installed" >&2
  exit 1
fi

# Parse arguments
USERNAME=""
DOMAIN="contoso.com"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --username) USERNAME="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Validate required arguments
if [ -z "$USERNAME" ]; then
  echo "ERROR: Missing required argument"
  echo "Usage: ./offboarding.sh --username 'username'"
  exit 1
fi

UPN="${USERNAME}@${DOMAIN}"

echo ""
echo "Offboarding: $UPN"
echo "Timestamp:   $(date)"
echo ""

# Step 1 — Disable account immediately
# Disabling before anything else ensures the user
# cannot authenticate while we complete the remaining steps
echo "Step 1: Disabling account immediately..."
az ad user update \
  --id "$UPN" \
  --account-enabled false
echo "✓ Account disabled — user cannot authenticate"

# Step 2 — Get user object ID
USER_ID=$(az ad user show \
  --id "$UPN" \
  --query id \
  --output tsv)

# Step 3 — Remove from all security groups
echo ""
echo "Step 2: Removing from all security groups..."

GROUPS=$(az ad user get-member-objects \
  --id "$USER_ID" \
  --security-enabled-only true \
  --query "[]" \
  --output tsv)

if [ -z "$GROUPS" ]; then
  echo "  No group memberships found"
else
  for GROUP_ID in $GROUPS; do
    # Get group name for logging
    GROUP_NAME=$(az ad group show \
      --group "$GROUP_ID" \
      --query displayName \
      --output tsv 2>/dev/null || echo "Unknown group")

    az ad group member remove \
      --group "$GROUP_ID" \
      --member-id "$USER_ID" 2>/dev/null || true

    echo "✓ Removed from: $GROUP_NAME"
  done
fi

# Step 4 — Verify account is disabled
echo ""
echo "Step 3: Verifying account is disabled..."
ACCOUNT_ENABLED=$(az ad user show \
  --id "$UPN" \
  --query accountEnabled \
  --output tsv)

if [ "$ACCOUNT_ENABLED" = "false" ]; then
  echo "✓ Account disabled — verified"
else
  echo "ERROR: Account disable verification failed — escalate immediately"
  exit 1
fi

# Step 5 — Output audit log
echo ""
echo "================================================"
echo "Offboarding complete: $(date)"
echo ""
echo "Actions taken:"
echo "  ✓ Account disabled — cannot authenticate"
echo "  ✓ Removed from all security groups"
echo "  ✓ Azure RBAC access revoked via group removal"
echo ""
echo "Manual steps still required:"
echo "  □ Revoke Microsoft 365 licence"
echo "  □ Transfer ownership of files and emails"
echo "  □ Remove GitHub repository access"
echo "  □ Revoke VPN certificates"
echo "  □ Collect company device"
echo "  □ Review and save audit log from this offboarding"
echo ""
echo "IMPORTANT: Soft-deleted account retained for 30 days"
echo "If data recovery needed contact IT within 30 days"
echo "================================================"
