#!/bin/sh
#############################################################################################################################
# Author - Travis Mitchell Feb 26th 2025
#
# Automates the Azure configuration to onboard account to PaaS, paste the output into the PaaS console in < 1m
#
# Derived from https://github.com/trvsmtchll/multicloud-clippy/blob/master/step1-azure-tf-bootstrap/avx_tf_sp.sh
#  
# This script is designed for mac
#
#############################################################################################################################
export DATE=`date '+%Y%m%d%hh%s'`
export LOG_DIR=$HOME/avx-azure-arm
mkdir -p ${LOG_DIR}

##################################
# Set up logfile
##################################
LOG_FILE=${LOG_DIR}/${DATE}_avx_az_arm.log

echo "###################################################################################"
echo "Aviatrix PaaS Onboarding config started at `date`" 
echo "###################################################################################"
echo "Please Wait ..."

if ! [ -x "$(command -v az)" ]; then
  echo 'Error: Azure CLI is not installed.. Try brew install azure-cli' >&2 >> $LOG_FILE
  exit 1
fi

if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed.. Try brew install jq' > $LOG_FILE >&2
  exit 1
fi

echo "Azure CLI and jq installed" 

echo "###################################################################################"
echo "Setting up Azure Aviatrix Service Princpal with Contributor role"
echo "###################################################################################"

read -p "Enter Aviatrix Service Princpal Name (This is a user friendly name for you): "  appname
#appname="avx_bootstrap_tf_sp5" # pass in as a variable if you want
echo "Aviatrix Azure Terraform SP is $appname"
echo "This can be found in Azure Portal - Home > Your Subscription > Access control (IAM) > Check Access > $appname"


## Subscription id
SUB_ID=`az account show | jq -r '.id'`
echo "Subscription ID:         $SUB_ID" 

## Azure SP creation
az ad sp create-for-rbac -n $appname --role contributor --scopes /subscriptions/$SUB_ID >> avx_tf_sp_$DATE.json

## Set up ENV VARS 
ARM_CLIENT_ID=`cat avx_tf_sp_$DATE.json | jq -r '.appId'`
ARM_CLIENT_SECRET=`cat avx_tf_sp_$DATE.json | jq -r '.password'`
ARM_SUBSCRIPTION_ID=$SUB_ID
ARM_TENANT_ID=`cat avx_tf_sp_$DATE.json | jq -r '.tenant'`

echo "###################################################################################"
echo "Creating bootstrap avx_tf_sp.env file KEEP THIS FILE AND avx_tf_sp_$DATE.json SAFE!!!!"
echo ""
echo ""
echo "Check your environment       - \$ env | grep ARM"
echo ""
echo "This script sources your envionment on first run in this shell"
echo ""
echo "###################################################################################"

## Write to file
echo "# Aviatrix PaaS SP created on $DATE" > avx_tf_sp.env 
echo "Subscription ID $ARM_SUBSCRIPTION_ID" >> avx_tf_sp.env
echo "Directory ID    $ARM_TENANT_ID" >> avx_tf_sp.env
echo "Application ID  $ARM_CLIENT_ID" >> avx_tf_sp.env
echo "Client Secret   $ARM_CLIENT_SECRET" >> avx_tf_sp.env
echo ""
echo "Paste these into PaaS to onboard your Azure account."
echo ""

## Cat the output
cat avx_tf_sp.env

