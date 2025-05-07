# Aviatrix Azure IAM Setup Scripts

This repository provides scripts that automate the process of creating and configuring the necessary Azure resources for Aviatrix PaaS to securely interact with your Azure environment. It implements security best practices by using custom roles with least-privilege permissions instead of the built-in Contributor role.

## Scripts Overview

This repository contains two scripts:

1. **`aviatrix-azure-iam-setup.sh`** - Creates a custom IAM role with read/write permissions
2. **`aviatrix-azure-readonly-setup.sh`** - Creates a custom IAM role with read-only permissions

## Full Access Setup

The `aviatrix-azure-iam-setup.sh` script handles the following:

1. Creates a custom IAM role with precisely defined permissions
2. Creates or uses an existing Azure AD application registration
3. Creates and configures a service principal for the application
4. Assigns the custom role to the service principal

## Read-Only Setup

The `aviatrix-azure-readonly-setup.sh` script handles the following:

1. Creates a custom IAM role with read-only permissions
2. Creates or uses an existing Azure AD application registration
3. Creates and configures a service principal for the application
4. Assigns the read-only custom role to the service principal

This script is useful when you need to:
- Create monitoring-only access for Aviatrix PaaS
- Implement a least-privilege approach with separate read/write and read-only accounts
- Create automation workflows that only require read access to Azure resources

## Getting Started

### Prerequisites

- Azure CLI installed (`az` command available)
- Azure account with appropriate permissions:
  - For Azure AD operations: 
    - Global Administrator, Application Administrator, or Cloud Application Administrator role in Azure AD
  - For creating custom roles:
    - Owner or User Access Administrator role on the subscription
- Bash shell environment

### Full Access Usage

```bash
./aviatrix-azure-iam-setup.sh [options]

Options:
  -n, --name NAME       App registration name (required)
  -r, --role NAME       Custom role name (default: Aviatrix-PaaS-Role)
  -c, --create-app      Create new app registration (default: use existing)
  -h, --help            Show this help message
```

### Example - Full Access

```bash
./aviatrix-azure-iam-setup.sh --name Aviatrix-PaaS-App --role Aviatrix-PaaS-Role --create-app
```

### Read-Only Usage

```bash
./aviatrix-azure-readonly-setup.sh [options]

Options:
  -n, --name NAME       App registration name (required)
  -r, --role NAME       Custom role name (default: Aviatrix-PaaS-ReadOnly-Role)
  -c, --create-app      Create new app registration (default: use existing)
  -h, --help            Show this help message
```

### Example - Read-Only

```bash
./aviatrix-azure-readonly-setup.sh --name Aviatrix-PaaS-ReadOnly-App --role Aviatrix-PaaS-ReadOnly-Role --create-app
```

## What These Scripts Create in Azure

### 1. Custom IAM Role

#### Full Access Role

**Technical explanation:**  
The script creates an Azure custom role definition using the Role-Based Access Control (RBAC) system. This role includes a carefully selected set of permissions that allow Aviatrix to manage networking resources, virtual machines, and storage accounts, while explicitly denying certain high-risk actions like role assignment modification.

The full access role definition includes:
```json
{
  "Name": "Aviatrix-PaaS-Role",
  "Description": "Custom role for Aviatrix PaaS",
  "Actions": [
    "Microsoft.Compute/*/read",
    "Microsoft.Storage/*/read",
    "Microsoft.Storage/StorageAccounts/listkeys/action",
    "Microsoft.Compute/availabilitySets/*",
    "Microsoft.Compute/virtualMachines/*",
    "Microsoft.Network/*/read",
    "Microsoft.Network/publicIPAddresses/*",
    "Microsoft.Network/networkInterfaces/*",
    "Microsoft.Network/networkSecurityGroups/*",
    "Microsoft.Network/loadBalancers/*",
    "Microsoft.Network/routeTables/*",
    "Microsoft.Network/virtualNetworks/*",
    "Microsoft.Resources/*/read",
    "Microsoft.Resourcehealth/healthevent/*",
    "Microsoft.Resources/deployments/*",
    "Microsoft.Resources/tags/*",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Network/expressRouteCircuits/*",
    "Microsoft.Network/virtualnetworkgateways/*",
    "Microsoft.Network/connections/*",
    "Microsoft.Resources/marketplace/purchase/action",
    "Microsoft.MarketplaceOrdering/offertypes/publishers/offers/plans/agreements/read",
    "Microsoft.MarketplaceOrdering/offertypes/publishers/offers/plans/agreements/write"
  ],
  "NotActions": [
    "Microsoft.Authorization/roleAssignments/write",
    "Microsoft.Authorization/roleAssignments/delete",
    "Microsoft.SerialConsole/serialPorts/connect/action"
  ],
  "DataActions": [
    "Microsoft.Storage/storageAccounts/fileServices/fileshares/files/*",
    "Microsoft.Storage/storageAccounts/fileServices/readFileBackupSemantics/action",
    "Microsoft.Storage/storageAccounts/fileServices/writeFileBackupSemantics/action"
  ]
}
```

#### Read-Only Role

**Technical explanation:**  
The read-only script creates a more restrictive Azure custom role that only includes read permissions. This role allows Aviatrix to view resources but not modify them, providing an additional layer of security for monitoring-only scenarios.

The read-only role definition includes:
```json
{
  "Name": "Aviatrix-PaaS-ReadOnly-Role",
  "Description": "Custom read-only role for Aviatrix PaaS",
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
  ]
}
```

**Non-technical explanation:**  
Think of the custom roles as security badges that give specific access permissions:
- The full access role is like an all-access badge that allows both viewing and changing resources
- The read-only role is like a visitor badge that only allows viewing resources but not changing them

Both badges only grant access to resources and actions that are necessary for Aviatrix to function, and explicitly block access to sensitive areas.

### 2. Azure AD Application (Optional)

**Technical explanation:**  
An Azure AD application registration serves as an identity for applications or services to authenticate against Azure AD. Both scripts can either create a new application or use an existing one, and generate a client secret with a 2-year validity period for authentication.

**Non-technical explanation:**  
The application registration is like an ID card for Aviatrix in Azure. It helps Azure recognize and authenticate Aviatrix when it tries to access your resources. The secret key is like a password that Aviatrix uses to prove its identity.

### 3. Service Principal

**Technical explanation:**  
A service principal is an identity created for use with applications, services, and automation tools. The scripts create a service principal associated with the application registration to enable non-interactive authentication to Azure resources.

**Non-technical explanation:**  
The service principal is the actual account that Aviatrix will use to work with your Azure resources. It's like an authorized user account that's specifically for the Aviatrix system rather than a human user.

### 4. Role Assignment

**Technical explanation:**  
The scripts assign the custom role to the service principal at the subscription scope, granting the service principal the exact permissions defined in the role, scoped to the entire subscription.

**Non-technical explanation:**  
This step connects the security badge (role) to the Aviatrix account (service principal). This ensures that when Aviatrix accesses your Azure environment, it has exactly the right level of access - no more, no less.

## Why Custom Roles Are Better Than Contributor Role

### Security Benefits

**Technical audience:**
- **Least privilege principle:** The custom roles implement the principle of least privilege by granting only the specific permissions required by Aviatrix.
- **Reduced attack surface:** Limiting permissions reduces the potential damage if credentials are ever compromised.
- **Explicit denial of sensitive operations:** The custom roles explicitly deny access to security-critical operations like role management.
- **Fine-grained control:** Permissions can be adjusted precisely as requirements change, rather than relying on broad pre-defined roles.

**Non-technical audience:**
- **Reduced risk:** Using a custom role is like giving someone a key to specific rooms in your building instead of a master key. If the key is lost or stolen, the risk is limited to only those rooms.
- **Better security posture:** Your organization's security team will appreciate the careful approach to permissions, which aligns with industry best practices.
- **Clear boundaries:** The custom roles make it clear exactly what Aviatrix can and cannot do in your environment.

### Operational Benefits

**Technical audience:**
- **Change tracking:** Custom role definitions can be version-controlled and tracked in your infrastructure-as-code repository.
- **Compliance:** Easier to demonstrate compliance with regulatory requirements for access control.
- **Auditability:** Clear definition of permissions makes security audits more straightforward.
- **Reduced privilege creep:** Permissions are explicitly defined rather than inherited from a broad role that might gain new permissions over time.

**Non-technical audience:**
- **Transparency:** It's easier to understand and explain exactly what access has been granted.
- **Better governance:** The approach follows best practices for cloud governance and security.
- **Peace of mind:** You can be confident that Aviatrix has exactly the access it needs, without unnecessary privileges.

## Output

Upon successful completion, the scripts output the following information:

- Subscription ID
- Tenant ID
- Application ID
- Application Secret (if a new app was created)
- Custom Role name

These values can be used to configure Aviatrix PaaS to connect with your Azure environment.

## Troubleshooting

- If you encounter errors about permissions, ensure your Azure account has sufficient privileges (typically Global Administrator or Owner role)
- If the service principal creation fails, wait a few minutes and try again as there can be propagation delays in Azure AD
- Check the Azure Portal to verify the resources were created correctly
- Review Azure Activity Logs for any error details

## Security Considerations

- Store the application secret securely; it cannot be retrieved again after creation
- Consider implementing a process for rotating the secret periodically
- Use Azure Key Vault or another secure secret management solution for storing credentials
- Review the custom role permissions periodically to ensure they remain appropriate
- For production environments, consider using the read-only role for monitoring workloads and the full access role only when changes are needed