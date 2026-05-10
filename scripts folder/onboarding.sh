#!/bin/bash
# onboarding.sh
# Automates Azure access provisioning for new Contoso employees
# Handles: user creation, group assignment, role verification
# Does NOT handle: device setup, VPN, GitHub, M365 licensing
# Usage: ./onboarding.sh --name "John Smith" --username "jsmith" --role "developer"
# Requirements: Azure CLI authenticated, User Administrator role in Entra ID

set -e

echo "================================================"
echo "Contoso — Employee onboarding"
echo "Started: $(date)"
echo "================================================"

# Check Azure CLI is available
if ! command -v az &>/dev/null; then
  echo "ERROR: Azure CLI not installed" >&2
  exit 1
fi

# Parse arguments
NAME=""
USERNAME=""
ROLE=""
DOMAIN="contoso.com"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --name)     NAME="$2";     shift ;;
    --username) USERNAME="$2"; shift ;;
    --role)     ROLE="$2";     shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Validate required arguments
if [ -z "$NAME" ] || [ -z "$USERNAME" ] || [ -z "$ROLE" ]; then
  echo "ERROR: Missing required arguments"
  echo "Usage: ./onboarding.sh --name 'Full Name' --username 'username' --role 'developer|finance|operations'"
  exit 1
fi

# Map role to security group
case $ROLE in
  developer)  GROUP="grp-developers"  ;;
  finance)    GROUP="grp-finance"     ;;
  operations) GROUP="grp-operations"  ;;
  *)
    echo "ERROR: Invalid role '$ROLE'"
    echo "Valid roles: developer, finance, operations"
    exit 1
    ;;
esac

UPN="${USERNAME}@${DOMAIN}"

echo ""
echo "Onboarding: $NAME"
echo "Username:   $UPN"
echo "Role:       $ROLE"
echo "Group:      $GROUP"
echo ""

# Step 1 — Create user account
echo "Step 1: Creating user account..."
TEMP_PASSWORD="Contoso@$(date +%Y)!"

az ad user create \
  --display-name "$NAME" \
  --user-principal-name "$UPN" \
  --password "$TEMP_PASSWORD" \
  --force-change-password-next-sign-in true
echo "✓ User account created: $UPN"
echo "  Temporary password: $TEMP_PASSWORD"
echo "  User must change password on first login"

# Step 2 — Add to security group
echo ""
echo "Step 2: Adding to security group..."

# Get group object ID
GROUP_ID=$(az ad group show \
  --group "$GROUP" \
  --query id \
  --output tsv)

# Get user object ID
USER_ID=$(az ad user show \
  --id "$UPN" \
  --query id \
  --output tsv)

az ad group member add \
  --group "$GROUP_ID" \
  --member-id "$USER_ID"
echo "✓ Added to $GROUP"
echo "  Azure RBAC access inherited automatically via group membership"

# Step 3 — Verify group membership
echo ""
echo "Step 3: Verifying group membership..."
MEMBER_CHECK=$(az ad group member check \
  --group "$GROUP_ID" \
  --member-id "$USER_ID" \
  --query value \
  --output tsv)

if [ "$MEMBER_CHECK" = "true" ]; then
  echo "✓ Group membership verified"
else
  echo "ERROR: Group membership verification failed"
  exit 1
fi

# Step 4 — Output summary
echo ""
echo "================================================"
echo "Onboarding complete: $(date)"
echo ""
echo "Summary:"
echo "  User:      $NAME ($UPN)"
echo "  Group:     $GROUP"
echo "  Access:    Inherited via group membership"
echo ""
echo "Manual steps still required:"
echo "  □ Send welcome email with temporary password: $TEMP_PASSWORD"
echo "  □ Assign Microsoft 365 licence in Entra admin centre"
echo "  □ Configure device and VPN access"
echo "  □ Grant GitHub repository access"
echo "  □ Schedule 90-day access review if contractor"
echo "================================================"
