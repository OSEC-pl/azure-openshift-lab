#!/bin/bash

# Deploy OpenShift on Azure.
# Requires the az and jq commands.

AZ_LOCATION=eastus
AZ_RG_OPENSHIFT=openshiftrg
AZ_RG_KEYVAULT=keyvaultrg
AZ_KEYVAULT=ae119606f058407bb916
AZ_SSH_PRIVKEY=~/.ssh/azure_openshift_rsa
AZ_SSH_SECRET=keysecret
AZ_SP=openshiftsp
AZ_GROUP_OPENSHIFT=myOpenShiftCluster
AZ_OPENSHIFT_TEMPLATE=https://raw.githubusercontent.com/Microsoft/openshift-origin/master/azuredeploy.json

#AZ_SP_PASS=

check_binary() {
	which $1 &>/dev/null
	if [ $? -ne 0 ] ; then
		echo $1 binary not found in PATH. Please install it before proceeding.
		exit 10
	fi
}

az_account_state_check() {
	local result 
	result=$(az account show | jq -r .state)

	if [ "$result" != "Enabled" ] ; then
		echo Account state: $result
		echo Please log in to your Azure account before running this script.
		exit 15 
	fi
	#az login --use-device-code
}

az_provision() {
	local json_output
	local cmd

	cmd="az $@"
	# TODO: if verbose mode display echo $cmd
	echo Running: $cmd
	json_output=$($cmd)
	result=$(echo $json_output | jq -r .properties.provisioningState)
	#echo $result

	if [ "$result" != "Succeeded" ] ; then
		echo Problem running command: $cmd
		echo $json_output
		exit 20
	fi
}

check_binary az
check_binary jq

az_account_state_check

az_provision group create --name ${AZ_RG_OPENSHIFT} --location ${AZ_LOCATION}
az_provision group create --name ${AZ_RG_KEYVAULT} --location ${AZ_LOCATION} 

az_provision keyvault create --name ${AZ_KEYVAULT} --resource-group ${AZ_RG_KEYVAULT} \
	--enabled-for-template-deployment true \
	--location ${AZ_LOCATION}

if [ ! -f ${AZ_SSH_PRIVKEY} ] ; then
	ssh-keygen -f ${AZ_SSH_PRIVKEY} -t rsa -N ''
fi

az keyvault secret set --vault-name ${AZ_KEYVAULT} --name ${AZ_SSH_SECRET} --file ${AZ_SSH_PRIVKEY}

# get appId from this:
#az ad sp create-for-rbac --name ${AZ_SP} \
#          --role Contributor --password ${AZ_SP_PASS} \
#          --scopes $(az group show --name ${AZ_RG_OPENSHIFT} --query id)

#az group deployment create -g ${AZ_RG_OPENSHIFT} --name ${AZ_GROUP_OPENSHIFT} \
#      --template-uri ${AZ_OPENSHIFT_TEMPLATE}
#      --parameters @./azuredeploy.parameters.json

#  ssh -p 2200 clusteradmin@myopenshiftmaster.cloudapp.azure.com

# az group delete --name myResourceGroup

