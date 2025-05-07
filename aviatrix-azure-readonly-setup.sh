#!/bin/bash

# Aviatrix Azure IAM Read-Only Setup Script
# This script handles:
# 1. Creating a custom read-only IAM role with Aviatrix required permissions
# 2. Creating an Azure AD application (optional)
# 3. Creating a service principal for the application
# 4. Assigning the custom role to the service principal

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo -e "${BLUE}Aviatrix Azure IAM Read-Only Setup Script${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME       App registration name (required)"
    echo "  -r, --role NAME       Custom role name (default: Aviatrix-PaaS-ReadOnly-Role)"
    echo "  -c, --create-app      Create new app registration (default: use existing)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --name Aviatrix-PaaS-ReadOnly-App --role Aviatrix-PaaS-ReadOnly-Role --create-app"
    echo ""
    exit 1
}

# Default values
APP_NAME=""
ROLE_NAME="Aviatrix-PaaS-ReadOnly-Role"
CREATE_APP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n|--name)
            APP_NAME="$2"
            shift 2
            ;;
        -r|--role)
            ROLE_NAME="$2"
            shift 2
            ;;
        -c|--create-app)
            CREATE_APP=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$APP_NAME" ]; then
    echo -e "${RED}Error: Application name is required${NC}"
    usage
fi

# Check if az cli is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if user is logged in to Azure
echo -e "${BLUE}Checking Azure CLI login status...${NC}"
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null)
if [ -z "$SUBSCRIPTION_ID" ]; then
    echo -e "${YELLOW}You are not logged in to Azure. Please login:${NC}"
    az login
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    if [ -z "$SUBSCRIPTION_ID" ]; then
        echo -e "${RED}Error: Failed to get subscription ID. Please check your Azure login.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Using subscription: ${SUBSCRIPTION_ID}${NC}"
TENANT_ID=$(az account show --query tenantId -o tsv)
echo -e "${GREEN}Using tenant: ${TENANT_ID}${NC}"

# Check permissions
echo -e "${BLUE}Checking permissions...${NC}"

# Get current user's object ID
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null)
if [ -z "$USER_OBJECT_ID" ]; then
    echo -e "${RED}Error: Could not determine your Azure AD identity.${NC}"
    exit 1
fi

# Check if using Service Principal for login
IS_SERVICE_PRINCIPAL=$(az ad signed-in-user show --query userType -o tsv 2>/dev/null)
if [ "$IS_SERVICE_PRINCIPAL" == "ServicePrincipal" ]; then
    echo -e "${YELLOW}Warning: You are logged in as a Service Principal.${NC}"
    echo -e "${YELLOW}To create service principals, you need an identity with the following permissions:${NC}"
    echo -e "  - Global Administrator role in Azure AD"
    echo -e "  - Application Administrator role in Azure AD"
    echo -e "  - Cloud Application Administrator role in Azure AD"
    read -p "Continue anyway? Only 'yes' will proceed: " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        echo -e "${RED}Operation cancelled.${NC}"
        exit 1
    fi
else
    # Check directory permissions by trying to list app registrations
    APP_LIST_TEST=$(az ad app list --query "[].appId" -o tsv 2>/dev/null)
    APP_LIST_ERROR=$?
    if [ $APP_LIST_ERROR -ne 0 ]; then
        echo -e "${RED}Error: Your account does not have permission to list application registrations.${NC}"
        echo -e "${RED}To create service principals, you need one of the following roles in Azure AD:${NC}"
        echo -e "  - Global Administrator"
        echo -e "  - Application Administrator"
        echo -e "  - Cloud Application Administrator"
        exit 1
    fi
    
    # Check subscription permissions by trying to list role definitions
    ROLE_LIST_TEST=$(az role definition list --custom-role-only true --query "[].name" -o tsv 2>/dev/null)
    ROLE_LIST_ERROR=$?
    if [ $ROLE_LIST_ERROR -ne 0 ]; then
        echo -e "${RED}Error: Your account does not have permission to manage role definitions.${NC}"
        echo -e "${RED}To create custom roles, you need:${NC}"
        echo -e "  - Owner or User Access Administrator role on the subscription"
        exit 1
    fi
    
    echo -e "${GREEN}Permissions check passed.${NC}"
fi

# Step 1: Create custom role
echo -e "\n${BLUE}Step 1: Creating custom read-only role '${ROLE_NAME}'...${NC}"
ROLE_DESCRIPTION="Custom read-only role for Aviatrix PaaS"

# Create role definition JSON with only read permissions
ROLE_DEF_FILE="/tmp/aviatrix-readonly-role-definition.json"
cat > "$ROLE_DEF_FILE" << EOF
{
  "Name": "$ROLE_NAME",
  "Description": "$ROLE_DESCRIPTION",
  "Actions": [
    "Microsoft.Compute/*/read",
    "Microsoft.Storage/*/read",
    "Microsoft.Network/*/read",
    "Microsoft.Resources/*/read",
    "Microsoft.Resourcehealth/healthevent/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Network/expressRouteCircuits/read",
    "Microsoft.Network/virtualnetworkgateways/read",
    "Microsoft.Network/connections/read",
    "Microsoft.MarketplaceOrdering/offertypes/publishers/offers/plans/agreements/read"
  ],
  "NotActions": [],
  "DataActions": [
    "Microsoft.Storage/storageAccounts/fileServices/fileshares/files/read"
  ],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/$SUBSCRIPTION_ID"
  ]
}
EOF

# Create the role
az role definition create --role-definition "$ROLE_DEF_FILE"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create custom read-only role.${NC}"
    exit 1
fi
echo -e "${GREEN}Custom read-only role created successfully.${NC}"

# Step 2: Handle App Registration
if [ "$CREATE_APP" = true ]; then
    # Create new app registration
    echo -e "\n${BLUE}Step 2: Creating new app registration '${APP_NAME}'...${NC}"
    
    # Check if app already exists
    EXISTING_APP=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
    if [ -n "$EXISTING_APP" ]; then
        echo -e "${YELLOW}Warning: App with name '$APP_NAME' already exists.${NC}"
        read -p "Do you want to use the existing app? (y/n): " USE_EXISTING
        if [[ $USE_EXISTING == "y" || $USE_EXISTING == "Y" ]]; then
            APP_ID=$EXISTING_APP
        else
            echo -e "${RED}Operation cancelled.${NC}"
            exit 1
        fi
    else
        # Create new app
        APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
        if [ -z "$APP_ID" ]; then
            echo -e "${RED}Error: Failed to create app registration.${NC}"
            exit 1
        fi
        
        # Create app password (secret)
        END_DATE=$(date -v+2y "+%Y-%m-%dT%H:%M:%SZ") 2>/dev/null
        if [ $? -ne 0 ]; then
            # Try linux date format if MacOS date fails
            END_DATE=$(date -d "+2 years" "+%Y-%m-%dT%H:%M:%SZ")
        fi
        
        echo -e "${YELLOW}Creating app secret valid until $END_DATE${NC}"
        APP_SECRET=$(az ad app credential reset --id "$APP_ID" --end-date "$END_DATE" --query password -o tsv)
        if [ -z "$APP_SECRET" ]; then
            echo -e "${RED}Error: Failed to create app secret.${NC}"
            exit 1
        fi
        echo -e "${GREEN}App secret created successfully.${NC}"
    fi
else
    # Use existing app
    echo -e "\n${BLUE}Step 2: Using existing app registration '${APP_NAME}'...${NC}"
    APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
    if [ -z "$APP_ID" ]; then
        echo -e "${RED}Error: App with name '$APP_NAME' not found.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Using App ID: ${APP_ID}${NC}"

# Step 3: Create service principal
echo -e "\n${BLUE}Step 3: Creating/getting service principal...${NC}"
# Check if service principal exists
SP_ID=$(az ad sp list --filter "appId eq '${APP_ID}'" --query "[0].id" -o tsv)
if [ -z "$SP_ID" ]; then
    echo -e "${YELLOW}Service principal does not exist, creating it...${NC}"
    SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
    if [ -z "$SP_ID" ]; then
        echo -e "${RED}Error: Failed to create service principal.${NC}"
        exit 1
    fi
    # Wait for SP propagation
    echo -e "${YELLOW}Waiting for service principal to propagate...${NC}"
    sleep 30
fi

echo -e "${GREEN}Using Service Principal ID: ${SP_ID}${NC}"

# Step 4: Assign role to service principal
echo -e "\n${BLUE}Step 4: Assigning custom read-only role to service principal...${NC}"
# Check if role assignment already exists
EXISTING_ROLE=$(az role assignment list --assignee "$SP_ID" --role "$ROLE_NAME" --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[0].id" -o tsv)
if [ -n "$EXISTING_ROLE" ]; then
    echo -e "${YELLOW}Role assignment already exists.${NC}"
else
    az role assignment create --assignee "$SP_ID" --role "$ROLE_NAME" --scope "/subscriptions/$SUBSCRIPTION_ID"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to assign role to service principal.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Role assigned successfully.${NC}"
fi

# Output results
echo -e "\n${GREEN}=== READ-ONLY SETUP COMPLETED SUCCESSFULLY ===${NC}"
echo -e "${BLUE}Subscription ID:${NC} $SUBSCRIPTION_ID"
echo -e "${BLUE}Tenant ID:${NC} $TENANT_ID"
echo -e "${BLUE}Application ID:${NC} $APP_ID"
if [ "$CREATE_APP" = true ] && [ -n "$APP_SECRET" ]; then
    echo -e "${BLUE}Application Secret:${NC} $APP_SECRET"
    echo -e "${YELLOW}IMPORTANT: Save this secret - it cannot be retrieved later!${NC}"
fi
echo -e "${BLUE}Custom Read-Only Role:${NC} $ROLE_NAME"
echo ""
echo -e "${GREEN}These values can be used to configure Aviatrix PaaS read-only access to Azure.${NC}"