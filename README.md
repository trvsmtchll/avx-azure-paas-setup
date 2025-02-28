# Aviatrix PaaS - Azure Account Setup 

This script creates an Azure service principal and outputs an .env and the required inputs to onboard an Azure account to Aviatrix PaaS

## Dependencies

Install the tools you need and login to Azure; this takes a minute or two. For windows you may use the ubuntu subsystem.

- **homebrew**  ```/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"```

- **jq**   ```brew install jq```

- **azure cli**  ```brew update && brew install azure-cli```

- ```az login``` This command will open your default browser and load an Azure sign-in page.

## Getting started

1. ```az login``` This command will open your default browser and load an Azure sign-in page.

2. Run a simple test to show your Azure Subscription ID  ```export SUB_ID=`az account show | jq -r '.id'` && echo "My Azure Subscription ID is $SUB_ID"```

3. Run the script ```./avx_paas_sp.sh```

4. The script will write output to file and provide the inputs required to onboard an Azure account to Aviatrix PaaS




