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
# Used to create SFDX package from an unmanaged package
#
#
#######################################################


#######################################################
# For UI
#######################################################


# functions to process ( order matters)
functions=( preAmble \
			checkForGit\
			checkForSFDX\
			oAuthWeb \
			createProject\
			sfPackages\
			convertMDToSource\
			createScrathConfiguration\
			createScratchAndTest\
			complete)

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
curDir=`pwd`
reset=`tput sgr0`

#######################################################
# For Operations
#######################################################
sandbox=https://test.salesforce.com/
production=https://login.salesforce.com/
skipAll=;
overwriteDir=;
defaultSourceLoc="force-app";
shellLocation=`dirname ${0}`;
shellScript=`basename ${0}`;
scratchOrgEdition="Developer"
###oAuthList=`sfdx force:auth:list --json 2>/dev/null`;

#######################################################
# Global values discovered
#######################################################
dxproject=
dxprojectScratchName=
dxprojectScratchUTs=
dxprojectUnitTests=
targetOrg=
sfPackages=
orgOAuth=
authUser=
runUnitTests=
packageLoc=`pwd`;
SFDX="sfdx";

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
# Utility called when user aborts ( reset )
#
#######################################################
function shutdown() {
  tput cnorm # reset cursor
  cd $curDir

}
#######################################################
# Utility for help
#
#######################################################
function help() {

    echo "${green}${bold}"
    echo ""
    echo "Usage: $shellScript [ -u <username> | -d <project> | -p <unmanaged-package-name> | -l <root-directory-of-project> | -o | -t | -v | -h ]"
	printf "\n\t -u <username>"
	printf "\n\t -d <project> which contains the unmanaged package"
	printf "\n\t -p <unmange-package-name> Unmanaged Package information ( this had to have been done FIRST!)"
	printf "\n\t -l <root-directory-of-project> The root directory location; location to place project (i.e. <root-directory-of-project>/myproject)"
	printf "\n\t -o overwrite project (if it exists)"
	printf "\n\t -t run unit tests in scratch Org"
	printf "\n\t -v turn on debug"
	printf "\n\t -h the help\n"
    resetCursor;
	exit 0
}

function getCommandLineArgs() {

	while getopts u:d:p:l:vhot option
	do
		case "${option}"
		in
			u) authUser=${OPTARG};;
			d) dxproject=${OPTARG};
				dxprojectScratchName="$dxproject""-ScratchOrg";
				dxprojectScratchUTs="$dxproject""-SUT";
				dxprojectUnitTests="$dxproject""-UnitTestsOut";
				;;
			p) sfPackages=${OPTARG};;
			l) curDir=${OPTARG};;
			o) overwriteDir=1;;
			v) set -xv;;
			t) runUnitTests=1;;
			h) help; exit 1;;
		esac
	done
	if [ "$curDir" == "." ];
	then
		curDir=`pwd`;
	elif  [ "$curDir" == ".." ];
	then
		curDir=$curDir/..;
	fi
	if [[ ! -z $authUser && ! -z $dxproject && ! -z $sfPackages ]]; then
		skipAll=1;
	fi
	if [[ ! -z $sfPackages && ! -z $packageLoc ]]; then
		packageLoc="$curDir/$sfPackages";
	fi
	 
}
#######################################################
# Utility to revert cursor back to previous
#
#######################################################
function cursorBack() {
  echo -en "\033[$1D"
}
#######################################################
# Utility to spin (wait)
#
#######################################################
function spinner() {
	if [  -z "$skipAll" ]
	then
	  # make sure we use non-unicode character type locale 
	  # (that way it works for any locale as long as the font supports the characters)
	  local LC_CTYPE=C

	  local pid=$1 # Process Id of the previous running command

	  local spin='-\|/'
	  local charwidth=1

	  local i=0
	  tput civis # cursor invisible
	  while kill -0 $pid 2>/dev/null; do
		local i=$(((i + $charwidth) % ${#spin}))
		printf "%s" "${spin:$i:$charwidth}"

		cursorBack 1
		sleep .1
	  done
	  tput cnorm
	  wait $pid # capture exit code
	  return $?
	fi
}
#######################################################
# Utility to parse JSON
#
#######################################################
function jsonValue() {
	KEY=$1
	num=$2
	list=$3
	
	if [ -z "$list" ];
	then
		local func_result=`echo "$oAuthList" | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p`;
	else
		local func_result=`echo "${!list}" | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p`;
	fi
	# act as a return value
	echo "$func_result"
}
#######################################################
# Utility to Print Pre-Amble function
#
#######################################################
function preAmbleFunction() {
	if [  -z $skipAll ]	
	then
		echo "${yellow}"
		printf "\t[Step $1] ... $2 ...\n"
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
		echo "Starting SFDX configuration for user: '$USERNAME' -- Going from an Unmanaged Package to Unlocked Package (2GP)"
		printf "\n\t >Perform some validations"
		printf "\n\t >Authenticate and create SFDX Project"
		printf "\n\t >Retrieve the Unmanaged Package information ( this had to have been done FIRST!)"
		printf "\n\t >Convert the Unmanaged Package metadata information into source\n"
		resetCursor;
	else
		printf "\n\tRunning for user: '$USERNAME', Package '$sfPackages' ..." 
	fi
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
# Utility to  reset cursor
#
#######################################################
function resetCursor() {
	
	if [  -z "$skipAll" ]
	then
		echo "${reset}" 
	fi
}
#######################################################
# GIT present
#
#######################################################
function checkForGit(){
	
	preAmbleFunction $1 "GIT [Validation]"
	#
	# first check for git
 
	type git >/dev/null 2>&1 || { handleError "	$0 requires git but it's not installed or found in PATH."; }
	printAction "${green}'git' command found..."
	resetCursor;
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
#######################################################
# OAuth into Org where unmanaged package is found
#
#######################################################
function oAuthWeb() {

	if [ -z "$authUser" ]
	then
		preAmbleFunction $1 "OAuth Web Access (The Org where Unmanaged Package was created)"
		while true; do
	
			printf "\t[P]roduction,[S]andbox, [N]one (p/s/y)?:${red}";  
			read -r orgType;
			if [ -z "$orgType" ]
			then
				break;
			fi
			case $orgType in
				[Nn]* ) ;;
				[Pp]* ) orgOAuth=$production;break;;
				[Ss]* ) orgOAuth=$sandbox;break;;
				* ) echo "${red}";printf "\tPlease answer 'p', 's' or 'n'."; echo "${yellow}";;
			esac
		done
		if [ -z "$orgOAuth" ]
		then
			printAction "No OAuth Org defined"
		else
			printAction "${green}Logging in via browser..."
			local result=`${SFDX} force:auth:web:login -r $orgOAuth --json`;
			printAction "OAuth Org $orgAuth defined"
			authUser="$(jsonValue username 1 result)"
			# need the alias 
			COMMAND=`echo "${SFDX} force:auth:list | grep $authUser | awk '{print \\$1}'"`
			#
			result=`eval ${COMMAND}`
			# use alias
			if [ ! -z $result ];
			then
				authUser=$result
			fi
		fi
	fi

}
#######################################################
# Create our SFDX Project to cleanup up the 
# unmanaged Org data (unhappy soup)
#
#######################################################

function createProject() {
	
	if [ -z "$dxproject" ]
	then
		preAmbleFunction $1 "New Project used to create Unlocked Package "

		while true; do
			echo "${yellow}"
			printf "\tProject Name?:${red}";  
			read -r project;
			 
			if [[ -d "$project" && ! -z $overwriteDir ]]
			then
				printf "\t${bold}${cyan}Error:Directory ${red}$project${cyan} exists. Pick another name.\n" ;
				resetCursor;
				continue;
			fi
			printf "\t${yellow}>>>>>Is this correct ${green}[$project]${yellow} (y/n)?${red}"
			read -r  yn
			echo "${yellow}"
			case $yn in
				[Nn]* ) ;;
				[Yy]* ) break;;
				* ) echo "${red}";printf "\tPlease answer 'y' or 'n'."; echo "${yellow}";;
			esac
			
		done
		printAction "Please wait while we create a new Project... ${green}'$project'"
		resetCursor;
		dxproject=$project;
		
	fi
	# do we overwrite
	if [[ -z $overwriteDir && -d "$dxproject" ]];
	then
		handleError "Project exists ($dxproject). Need to specify -o on command line to overwrite existing project."
	fi
	#set -xv
	cd "$curDir"
	${SFDX} force:project:create -n "$dxproject" -x >/dev/null 2>&1  || { handleError ">>$dxproject<< unable to create project"; }
	#ensure we have a package location
	packageLoc="$curDir/$dxproject";
	
}

#######################################################
# get the target Org
#
#######################################################
function targetOrg( ) {
 
	preAmbleFunction $1 "Target Org"
 
	while true; do
		printf "\tTarget Org (if known)?:${red}"; 
		read -r target;
		echo "${yellow}"
		if [ -z $target ]
		then
			break;
		fi
		printf "\t${yellow}>>>>>Is this correct ${green}[$target]${yellow} (y/n)?"
		read -r  yn
		echo "${yellow}"
		case $yn in
			[Nn]* ) ;;
			[Yy]* ) break;;
			* ) echo "${red}";printf "\tPlease answer 'y' or 'n'."; echo "${yellow}";;
		esac
	
	done
	if [ -z $target ]
	then
		printAction "No Target Org defined"
	else
		printAction "Target Org:${green}'$target'"
	fi
	
	targetOrg=$target;
}

#######################################################
# get the Unmanaged Package (if any)
#
#######################################################
function sfPackages( ) {
 
	if [ -z "$sfPackages" ]
	then
		preAmbleFunction $1 "Salesforce Unmanaged Package (Only one package)"

		while true; do
			printf "\tProvide Name of Package (if any)?:${red}"; 
			read -r sfpacks;
			echo "${yellow}"
			if [ -z "$sfpacks" ]
			then
				break;
			fi
			printf "\t${yellow}>>>>>Is this correct ${green}[$sfpacks]${yellow} (y/n)?"
			read -r  yn
			echo "${yellow}"
			case $yn in
				[Nn]* ) ;;
				[Yy]* ) break;;
				* ) echo "${red}";printf "\tPlease answer 'y' or 'n'."; echo "${yellow}";;
			esac
		
		done
		if [ -z "$sfpacks" ]
		then
			printAction "No SF Packages defined"
		else
			printAction "SF Packages :${green}'$sfpacks'"
		fi
	
		sfPackages=$sfpacks;
	fi
}

#######################################################
# Process to pull unmanaged package and convert to source
#
#######################################################
function convertMDToSource(){
	preAmbleFunction $1 "Get metadata, unpack and convert to Source"
	cd "$dxproject"
	projLoc=`pwd`;
	if [ ! -d "$projLoc/mdapi" ];
	then
		mkdir mdapi >/dev/null 2>&1  || { handleError ">>mdapi<< unable to create directory 'mdapi'"; }
	else
	    rm -rf mdapi
	fi
	 
	if [ ! -z "$sfPackages" ]
	then  
		proj="'""$sfPackages""'"
		if [  -z "$skipAll" ]
		then
			echo "${green}${bold}"
			echo ""
			printf "\tPulling and Converting package $prog [Metadata to Source], please wait...."
		fi
		COMMAND=`echo ${SFDX} force:mdapi:retrieve -p "$proj" -s -r mdapi -u "$authUser" `
		#
		eval ${COMMAND} >/dev/null 2>&1  || { handleError ">>$authUser<< is this a valid user; may need to authenticate again."; }
		#spinner $!
		cd mdapi
		unzip -o unpackaged.zip >/dev/null 2>&1 || { handleError "file is not present in $projLoc/mdapi/unpackaged.zip."; }
		cd ..
		# convert
		${SFDX} force:mdapi:convert -r mdapi -d force-app  >/dev/null 2>&1  || { handleError ">>mdapi<< issue with retrieved unpackaged.zip."; }
		printAction "\n\tProject Source can be found in `pwd`";
		
		resetCursor;
	fi
}
#######################################################
# Create Scratch Org Config
#
#######################################################
function createScrathConfiguration() {

	# create our scratch org json file
	$shellLocation/setScratchOrgJSON.sh "$dxprojectScratchName" "$scratchOrgEdition" "$shellLocation" "$packageLoc"
}
#######################################################
# Run Unit Tests in Scratch Org
#
#######################################################
function createScratchAndTest() {

	if [ ! -z $runUnitTests ];
	then
		preAmbleFunction $1 "Get scratch Org, and run unit tests"
		#echo "==>  $packageLoc"
		cd $packageLoc
		printAction "\n\Creating scratch Org, pushing to Scratch Org and running unit tests with code-coverage (output found here $dxprojectUnitTests.json)";
		
		${SFDX} force:org:create -s -f config/project-scratch-def.json -a "$dxprojectScratchName"  >/dev/null 2>&1  || { handleError ">>project-scratch-def.json<< unable to create scratch Org. $0"; }
		${SFDX} force:source:push -u "$dxprojectScratchName" -w 30  >/dev/null 2>&1  || { handleError ">>push<< issue with pushing source to scratch Org $dxprojectScratchName (too many scratch Orgs?. $0"; }
		printAction "Running Unit Tests... output found in '$dxprojectUnitTests.json'"
		${SFDX} force:apex:test:run -y -c -r human --json -u "$dxprojectScratchName"  > "$dxprojectUnitTests.json"  >/dev/null 2>&1  || { handleError ">>run unit test<< issue with running unit tests in scratch Org $dxprojectScratchName ?. $0"; }
	fi
}

#######################################################
# Process Completed
#
#######################################################
function complete( ) {
	preAmbleFunction $1 "Complete"

	
	echo "${green}${bold}"
	echo ""
	printAction "Completed Preliminary configuration for user: '$USERNAME'"
	printAction "Project Directory found here: '$packageLoc'"
	
	resetCursor;
	
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
	  
	$functionsToCall $step $dxproject
	((step=step+1));
done
