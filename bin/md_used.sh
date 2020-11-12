#!/usr/bin/env bash
############################################################################
# Copyright (c) 2020, Salesforce.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   + Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   + Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#
#   + Neither the name of Salesforce nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
############################################################################
#######################################################
#
# Gathers the Metadata Dependencies from the Specific Org --
# Data is used for analyzes (by 'dotGen.sh')
#
#
#######################################################


SFDX="sfdx";
authUser=;
DATA_DIR=data;
curDir=`pwd`;
wDir="$curDir";
# functions to process ( order matters)
functions=( checkForSFDX initLocation mdGather complete)

#######################################################
# For UI (curses)
#######################################################
step=0;
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
magenta=`tput setaf 5`
cyan=`tput setaf 6`
white=`tput setaf 7`
bold=`tput bold`
reset=`tput sgr0`
skipAll=;
shellLocation=`dirname ${0}`;
shellScript=`basename ${0}`;
#######################################################
# Utility called when user aborts ( reset )
#
#######################################################
function shutdown() {
  tput cnorm # reset cursor
  cd $wDir
}
#######################################################
# Utility print out error
#
#######################################################
function handleError() {
	echo "${red}${bold}"
	printf >&2 "\n\tERROR: $1"" Aborted\n"; 
	resetCursor;
	exit -1; 
}
#######################################################
# Utility to Print actions
#
#######################################################
function printAction() {
	
	if [  -z ${skipAll} ]
	then
		echo "${cyan}${bold}"
		printf "\t>>>>>>$1"
		echo "${cyan}${bold}<<<<<<";  
	fi

}
#######################################################
# Utility to  reset cursor
#
#######################################################
function resetCursor() {	
	echo "${reset}" 

}
#######################################################
# Utility called when user aborts ( reset )
#
#######################################################
function shutdown() {
  tput cnorm # reset cursor
}
#######################################################
# Utility to Print Pre-Amble function
#
#######################################################
function preAmbleFunction() {
	echo "${yellow}"
	printf "\t[Step $1] ... $2 ...\n"
}
#######################################################
# Utility for help
#
#######################################################
function help() {

    echo "${green}${bold}"
    echo ""
    echo "Usage: $shellScript [ -u <username|target-org> | -l <data-location> | -d |  -h ]"
	printf "\n\t -u <username|target-org>"
	printf "\n\t -l <data-location> [will create, if not present]"
	printf "\n\t -d debug"
	printf "\n\t -h the help\n"
    resetCursor;
	exit 0
}
#######################################################
# Command Lines
#
#######################################################
function getCommandLineArgs() {
	while getopts u:l:dh option
	do
		case "${option}"
		in
			u) authUser=${OPTARG};;
			l) curDir=${OPTARG};;
			d) set -xv;;
			h) help; exit 1;;
		esac
	done

	if [  -z ${authUser} ];
	then
		handleError "User/Alias/Target-Node required; \n\tUsage: $0 [ -u <username> | -d |  -h ]";
	fi

}
#######################################################
# SFDX present
#
#######################################################
function checkForSFDX(){

	preAmbleFunction $1 "SFDX [Validation]"
 
	type ${SFDX} >/dev/null 2>&1 || { handleError "	$0 requires ${SFDX} but it's not installed or found in PATH."; }
	printAction "${green}'sfdx' command found..."
	resetCursor;
}
#
#######################################################
# initialize location
#######################################################
#
function initLocation() {

	preAmbleFunction $1 "Initializing directory for Analyzes ... results will be placed in '$curDir/$DATA_DIR' ";
	local dir=`dirname $curDir`;
	local mbase=`basename $curDir`;
	
	if [ ! -d "$dir" ];
	then
		mkdir "$dir" >/dev/null 2>&1  || { echo ">>$dir<< unable to create directory '$dir'"; }
	fi
	
	if [ ! -d "$dir/$mbase" ];
	then
		mkdir "$dir/$mbase" >/dev/null 2>&1  || { echo ">>$dir/$mbase<< unable to create directory '$dir/$mbase'"; }
	fi
	curDir="$dir/$mbase";
	# our data directory
	if [ ! -d "$curDir/$DATA_DIR" ];
	then
		mkdir "$curDir/$DATA_DIR" >/dev/null 2>&1  || { echo ">>$curDir/$DATA_DIR<< unable to create directory '$curDir/$DATA_DIR'"; }
	fi
	# our directory  
	cd "$curDir/$DATA_DIR";
	# we have the full path to data
	DATA_DIR=`pwd`;

}

#######################################################
# Metadata Gather
#
#######################################################
function mdGather() { 
	# get metadata dependencies
	printAction "Gathering Metdadata [may take a while]..."
	
	printAction "\tGathering Apex Classes...";
	# apex
	 ${SFDX} force:data:soql:query -u "$authUser" -r human  --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'ApexClass'" > "${DATA_DIR}/apex_classess.txt"
	printAction "\tGathering Custom Labels..."
	#custom label
	 ${SFDX} force:data:soql:query -u "$authUser"  -r human --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType ='CustomLabel'" > "${DATA_DIR}/custom_label.txt"
	printAction "\tGathering Lightning Components..."
	# lightning components
	 ${SFDX} force:data:soql:query -u "$authUser" -r human --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'AuraDefinitionBundle'" > "${DATA_DIR}/lightning_comp.txt"
	printAction "\tGathering Static Resources..."
	# static resources
	 ${SFDX} force:data:soql:query -u "$authUser" -r human  --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'StaticResource'" > "${DATA_DIR}/static_res.txt"
	printAction "\tGathering Visual Force Pages..."
	# vf pages
	${SFDX} force:data:soql:query -u "$authUser" -r human  --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'ApexPage'" > "${DATA_DIR}/vf_pages.txt"
	printAction "\tGathering Custom Settings..."
	# custom settings fields used
	# ${SFDX} force:data:soql:query -u "$authUser" -r human --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentName  = 'On'" > "${DATA_DIR}/custom_settings_field_used.txt"
	printAction "\tGathering Flows..."
	# flow use
	 ${SFDX} force:data:soql:query -u "$authUser" -r human --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'Flow'" > "${DATA_DIR}/flows_used.txt"
	printAction "\tGathering Custom Fields..."
	# custom fields used
	 ${SFDX} force:data:soql:query -u "$authUser" -r human --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'CustomField'" > "${DATA_DIR}/custom_fields.txt"
	printAction "\tGathering Custom Objects..."
	# custom objects used
	 ${SFDX} force:data:soql:query -u "$authUser" -r human --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'CustomObject'" > "${DATA_DIR}/custom_objects.txt"
	printAction "\tGathering Global Value Sets..."
	# global value sets used
	${SFDX} force:data:soql:query -u "$authUser" -r human --usetoolingapi --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'GlobalValueSet'" > "${DATA_DIR}/global_value_sets.txt"
	printAction "\tGathering Orchestration Context..."
	# orchestration context used
	${SFDX} force:data:soql:query --usetoolingapi -u "$authUser" -r human  --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'OrchestrationContext'" > "${DATA_DIR}/orchestration_used.txt"
	printAction "\tGathering Reports..."
	# report  used
	${SFDX} force:data:soql:query --usetoolingapi -u "$authUser" -r human  --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'Report'" > "${DATA_DIR}/reports.txt"
	printAction "\tGathering Report Types..."
	# report type used
	${SFDX} force:data:soql:query --usetoolingapi -u "$authUser" -r human  --query "SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency Where RefMetadataComponentType = 'ReportType'" > "${DATA_DIR}/report_types.txt"
}

#######################################################
# MAIN
#
# Steps to take 
#
#######################################################
#reset console
trap shutdown EXIT
# cli arguments first
getCommandLineArgs "$@"
#run functions
for functionsToCall in "${functions[@]}"
do  
	$functionsToCall $step
	((step=step+1));
done