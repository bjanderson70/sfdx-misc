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
#
# Description:
#
# This script builds a scratch Org installing required features and packages.
# The packages are pulled in from non-scratch org ( if any) and compared
# against the list of packages this customer wants. By default, it will pulled
# the latest FSC package id ( at min. install that package)
#
#######################################################
# Functions For Processing
#######################################################

# functions to process ( order matters)
functions=(preAmble checkForSFDX createScratchOrg getLatestFSCManagedPackage getOrgListOfNonScratchOrg iterateOverIncludeList setPerms)
			
# Keep  list of FSC packages to install ( order is important!)
FSCOrder=('FinancialServicesCloud' 'FinancialServicesExt');

#######################################################
# For UI (curses)
#######################################################

red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
magenta=`tput setaf 5`
cyan=`tput setaf 6`
white=`tput setaf 7`
bold=`tput bold`
curDir=`pwd`
reset=`tput sgr0`

#######################################################
# For Operations
#######################################################
curDir=`pwd`
step=0;
# Specify the timeout in minutes for package installation.
WAIT_TIME=40;
KNOWN_FCS_NAME="FinancialServicesCloud";
SFDX="sfdx";
shellLocation=`dirname ${0}`;
shellScript=`basename ${0}`;
packageToIncludeLocation="$shellLocation/../res/includePackages.txt";
soDefLocation="$shellLocation/../res/default-project-scratch-def.json"
projectFileLocation="$shellLocation/../res/sfdx-project.json"
packageFilter="$shellLocation/filterPackages.sh";
sfdxProject="sfdx-project.json"
scratchOrg=;
scratchOrgName=;
FCSPAckageId=;
tmpfile=;
#######################################################
# Global values discovered
#######################################################
knownFSCManagedPackageURI=" http://industries.force.com/financialservicescloud/";
skipAll=;
authUser=;
soUser=;
# holds the packaes in the non-scratch org
ORG_PACKAGES_JSON=;
fscInstalled=0;
#######################################################
# Functions
#######################################################

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
# Utility print out warning
#
#######################################################
function handleWarning() {
	echo "${yellow}${bold}"
	printf >&2 "\n\tWARNING: $1"" Some Functionality will be lost\n"; 
	dotPresent=0;
	resetCursor;
}
#######################################################
# Utility called when user aborts ( reset )
#
#######################################################
function shutdown() {
  tput cnorm # reset cursor
  cd $curDir
  # remove temp file
  if [ ! -z $tmpfile ];
  then
	rm -f "${tmpfile}"  >/dev/null 2>&1;
  fi

}
#######################################################
# Utility to Print Pre-Amble
#
#######################################################
function preAmble () {

	if [  -z $skipAll ]
	then
		clear;
		echo "${green}${bold}"
		echo ""
		echo "Starting Scratch Org Initialization for user: '$USERNAME' "
		printf "\n\t >Finding Packages in non-scratch org"
		printf "\n\t >Reaching out to FSC installation for LATEST Package Id"
		printf "\n\t >Install Packages into Scratch Org"
		resetCursor;
	else
		printf "\n\tRunning ...." 
	fi
}
#######################################################
# Utility to Print Pre-Amble function
#
#######################################################
function preAmbleFunction() {
	if [  -z $skipAll ]	
	then
		echo "${yellow}"
		printf "\t[Step $1] ... $2 [please wait]...\n"
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
# Utility for help
#
#######################################################
function help() {

    echo "${green}${bold}"
    echo ""
    echo "Usage: $shellScript [ -u <source|username> | -s <scratch-org-user>| -f | -d | -h ]"
	printf "\n\t -s <scratch-org-user>"
	printf "\n\t -u <source|username> [Source of a NON-Scratch-Org, if any]"
	printf "\n\t -f [ensures the FSC package is installed]"
	printf "\n\t -d debug"
	printf "\n\t -h the help\n"
    resetCursor;
	exit 0
}
#######################################################
# Help
#
#######################################################
function getCommandLineArgs() {

	while getopts u:s:fdh option
	do
		case "${option}"
		in
			s) soUser=${OPTARG};;
			u) authUser=${OPTARG};;
			f) fscInstalled=1;;
			d) set -xv;;
			h) help;;
		esac
	done
	
}

#######################################################
# SFDX present
#
#######################################################
function checkForSFDX(){
	
	preAmbleFunction $1 "${SFDX} [Validation]"
	#
	# first check for ${SFDX}
 
	type ${SFDX} >/dev/null 2>&1 || { handleWarning "	$shellScript CANNOT find '${SFDX}' - it's not installed or found in PATH."; }

	resetCursor;
}
#######################################################
# Utility to Print actions
#
#######################################################
function printAction() {
	
	if [  -z "$skipAll" ]
	then
		echo "${cyan}${bold}"
		printf "\t>>>>>>$1"
		echo "${cyan}${bold}<<<<<<";  
	fi

}
#######################################################
# Highlite output ( or reset)
#
#######################################################
function highliteSFDXOutput() {
	if [ -z $1 ];
	then
		resetCursor;
	else
		resetCursor;
		echo "${cyan}${bold}";
	fi
}
#######################################################
# Create Scratch Org
#
#######################################################
function createScratchOrg() {
    
	# do we need to creaet scratch org
    if [ -z $soUser ]; then
        preAmbleFunction $1 "Creating Scratch org..."
        # get username
        soUser=`${SFDX} force:org:create -s -f $soDefLocation -d 2 --json |  grep username | awk '{ print $2}' | sed 's/"//g'`
	fi
	# if we created a scratch org, ensure it is done
	if [[ -z $soUser || $? == 1 ]]; then
		handleError "Check Scratch Org Definition File - Unable to create Scratch Org from definition [$soDefLocation]"
	else
		# all good
		preAmbleFunction $1 "Scratch org (user=$soUser)."
	fi
}
#######################################################
# Packages in Non-Scratch Org
#
#######################################################
function getOrgListOfNonScratchOrg(){

	local lpwd=`pwd`;
	# do we have a non-scratch org
	if [ ! -z $authUser ];
	then
		preAmbleFunction $1 "Getting Packages Installed in Non-Scratch-Org"
		# we need to fool SFDX as it expects a sfdx-project.json.
		# if one is not present; temporarily create one, and then remove it.
		# Otherwise, the command does not run!
		if [ ! -f "$lpwd/$sfdxProject" ];
		then
			cp "${projectFileLocation}" .
		fi
		# get a list of packages from the non-scratch org
		ORG_PACKAGES_JSON=`${SFDX} force:package:installed:list -u $authUser --json` 	
		# make sure command ran
		if [[  $? == 1 ]]; then
			handleError "Issue getting package information - Command must be run from a valid project directory (sfdx-project.json does not exist)"
		fi

	else
		# no non-scratch org
		ORG_PACKAGES_JSON="";
	fi
}
#######################################################
# Get Latest FSC Package Id
#
#######################################################
function getLatestFSCManagedPackage(){
	preAmbleFunction $1 "Getting Latest FSC Package Id"
	# filter out the redirect to get the package id
	FCSPAckageId=`curl --location $knownFSCManagedPackageURI 2>/dev/null | grep "window.location.href"| grep 04t | cut -d '=' -f 3 | sed "s/['|;]*//g"`;
	if [ -z $FCSPAckageId ]; then
		handleError "Unable to get the latest FSC Package Id"
	else
		printAction "Found latest FSC Package Id - $FCSPAckageId"
	fi
}
#######################################################
# Compare to included packages
#
#######################################################
function processIncludedPackages() {
	# $1 == package name
	# $2 == package id
	# ( NOTE: the above MAY NOT be passed in)
 
	# file present
	if [ -f "${packageToIncludeLocation}" ];
	then

		while IFS= read -r line
		do 
			pkgId=`echo $line | tr -d ' "' | awk  'BEGIN{FS=":" } {print $1}' | sed 's/^ *//g'`;
			 name=`echo $line | tr -d ' "' | awk  'BEGIN{FS=":"; } { $1=""; print $0;}' | sed 's/^ *//g'`;

			# match names ( strip of all spaces and quotes)
			if [[ -z $1 || "$name" == "$1" ]];
			then				
				# remove spaces
				name=`echo $name  | sed -e 's/\s\+/-/g'`;
				 
				# do we already KNOW the package Id
				if [[ -z $2 && ! -z $pkgId ]];
				then
					echo "$pkgId:$name" >> "${tmpfile}"
				elif [ ! -z $2 ];
				then
					# save package id and name
					echo "$2:$name" >> "${tmpfile}"
				fi
				# if nothing was passed in we know that we want to ignore
				# data from a non-scratch org and process what is in the 
				# included packages
				if [ ! -z $1 ];
				then
					break;
				fi
			fi
		done < $packageToIncludeLocation;
	fi
}
#######################################################
# Process Packages ( if any)
# Here we are finding the package name and ids we pulled
# from the non-scrtach org. This then calls 'processIncludedPackages'
# to check for ones we wanted -- and save in 'tmpfile'
#######################################################
function processPackages() {
	tmpfile=".pack$$ages.txt"
	# create an empty file
	touch "${tmpfile}"
	 
	# do we have any preinstalled packages?
	if [ ! -z $1  ];
	then
		# iterate over the found packages ( they are not in order, just save to file)
		while read line ; do
			local pgkId=`echo $line | awk  'BEGIN{FS=":" } {print $1}' | sed 's/^ *//g'`
			local pgkName=`echo $line |  awk  'BEGIN{FS=":" } {print $2}'| tr -d ' "'| sed 's/^ *//g'`
			processIncludedPackages "$pgkName" "$pgkId"
		done < $1;
		rm "${1}"  >/dev/null 2>&1;
	else
		# not using a non-scratch org ; used the known installed packages file
		processIncludedPackages
	fi
}
#######################################################
# Install Package
#
#######################################################
function installPackage(){
	# $1 == step count
	# $2 == package name
	# $3 = package id
	
	preAmbleFunction $1 "Installing package $2 ($3) for $soUser"
	highliteSFDXOutput 1;
	# install package into scratch org ( compile at package layer)
	${SFDX} force:package:install -a package --package "$3" --wait $WAIT_TIME  --publishwait $WAIT_TIME  -u "$soUser" 
	highliteSFDXOutput;
}
#######################################################
# Iterate over known packages
#
#######################################################
function iterateOverIncludeList() {
	preAmbleFunction $1 "Installing Packages into Scratch-Org"
	local lstep=$1;
	local count=0;
	local packSize=`echo "${ORG_PACKAGES_JSON}" | wc -l`;
	local mPackages=;
 
	# any data to process from the non-scratch org ??
	if [ "$packSize" -gt "2" ];
	then
		mPackages=".foundpack$$ages.txt"
		echo "$ORG_PACKAGES_JSON" | awk -f $packageFilter > "${mPackages}"
	fi
	# process packages ( if any)
	processPackages $mPackages;
	
	# holds array of added package IDs
	local hasDone=();
	if [ -f "${tmpfile}" ];
	then 
		count=`cat ${tmpfile}|wc -l`;
	fi

	# this file gets created when we have data from the non-scratch org
	if [ "$count" -gt "0" ];
	then 

		# here we use the needed order for the FSC ( cannot assume the list in is correct $packageToIncludeLocation)
		for fscOrder in ${FSCOrder[@]};
		do
		   # read in the file that holds the order we require the packages to be installed
		   while IFS= read -r line
				do 
					pkgId=`echo $line | awk  'BEGIN{FS=":" } {print $1}'`
					pgkName=`echo $line |  awk  'BEGIN{FS=":" } {print $2}'`
					# here we substitute the latest FSC Package Id ( otherwise, we could get deprecated comments)
					if [[ "${pgkName}" = "${fscOrder}" && "${fscOrder}" = "${KNOWN_FCS_NAME}" && ! -z $FCSPAckageId ]];
					then
						pkgId=$FCSPAckageId
						# mark that we are going to installed ( no need to do twice!)
						fscInstalled=2;
					fi
 
					# valid package id and match name or is it a NON Financial package (i.e. FSC)
					#if [[ "${pkgId}" != "" &&  ("${fscOrder}" == "${pgkName}" || "${pgkName}" != "Financial"*) ]];
					if [[ "${pkgId}" != "" ]];
					then
						# have we installed this package ??
						if [[ ! " ${hasDone[@]} " =~ " ${pgkName} " ]]; 
						then
							((lstep=lstep+1));
							installPackage "$lstep" "$pgkName" "$pkgId";
							# keep track of what was installed (or attempted)
							hasDone+=($pgkName);
						fi
						#}
					fi
				done < "${tmpfile}"
		done
		rm "${tmpfile}" >/dev/null 2>&1;
	fi
	# can ensure at min. the FSC component is installed
	if [[ "${fscInstalled}" -eq "1" && ! -z $FCSPAckageId ]];
	then
	    # at min. we load the FSC package
	    ((lstep=lstep+1));
	    installPackage "$lstep" "${KNOWN_FCS_NAME}" "$FCSPAckageId"
	fi
	
}
#######################################################
# Set Permissions
#######################################################
function setPerms() {
    preAmbleFunction $1 "Setting Permissions in Scratch-Org"
    if [[ "${fscInstalled}" -ne "0" && ! -z $FCSPAckageId ]];
    then
        sfdx force:user:permset:assign -n FinancialServicesCloudStandard
    fi

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
#
for functionsToCall in "${functions[@]}"
do  	  
	$functionsToCall $step;
	((step=step+1));
done
