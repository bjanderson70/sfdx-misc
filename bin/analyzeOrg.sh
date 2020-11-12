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
# Description: Used to Analyze an Org --
#
#	+ Retrieve Metadata -- uses a predefined 'package.xml'
#	+ Converts to Source
#	+ Generates CSV files for tracking
# 	========================================
#	+ Quick analysis of Objects (custom and standard)
#	+ generate dependencies and graph (via dot)
#
#######################################################


#######################################################
# For UI (curses)
#######################################################
step=1;
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
# functions to process ( order matters)
functions=(preAmble initLocation checkForSFDX checkForScripts retrieveMDAndConvert mdapiConvert csvFiles analyzeOrg packagesInstalled runMetadataDependencies );

shellLocation=`dirname ${0}`;
shellScript=`basename ${0}`;
SFDX="sfdx";
authUser="crv";
curDir=`pwd`;
destDir="force-app"
mdapiDir="mdapi";
mdDir="$destDir/main/default";
mdList="allCRVmetadata.csv";
sheetsDir="$curDir/csvSheets";
prefix="CR_";
skipAll=;
orgAnalysis="orgAnalysis";
resDir="$shellLocation/../res";
runmd=;
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
	printf >&2 "\n\tWARNING: $1"" $2\n"; 
	resetCursor;
}
#######################################################
# Utility called when user aborts ( reset )
#
#######################################################
function shutdown() {
  tput cnorm # reset cursor
}
#######################################################
# Utility to  reset cursor
#
#######################################################
function resetCursor() {	
	echo "${reset}" 
}
#######################################################
# Utility to Print Pre-Amble
#
#######################################################
function preAmble () {

	clear;
	echo "${green}${bold}"
	echo ""
	echo "Starting Analyzes for user: '$USERNAME' "
	printf "\n\tRunning ...."
	#printf "\n\t >Processing for Capability Squad '${Squads[$filterIndex]}'"
	resetCursor;	
}

#######################################################
# Utility to Print Pre-Amble function
#
#######################################################
function preAmbleFunction() {
	if [  -z ${skipAll} ]	
	then
		echo "${yellow}"
		printf "\t[Step $1] ... $2 ...\n"
	fi
}
#######################################################
# Utility for help
#
#######################################################
function help() {

    echo "${green}${bold}"
    echo ""
    echo "Usage: $shellScript [ -u <username|target-org> | -l <directory-location-write-data> | -r | -d |  -h ]"
	printf "\n\t -u <username>"
	printf "\n\t -l <directory-location-write-data> [defaults to current directory]"
	printf "\n\t -r run the metadata dependencies"
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
	while getopts u:l:p:drh option
	do
		case "${option}"
		in
			u) authUser=${OPTARG};;
			l) curDir=${OPTARG};;
			r) runmd=1;;
			p) prefix=${OPTARG};;
			d) set -xv;;
			h) help;;
		esac
	done
	# require auth user
	if [  -z ${authUser} ];
	then
		handleError "User/Alias/Target-Node required; \n\tUsage: $shellScript [ -u <username> | -l <directory-location-write-data> [defaults to current dir] | -d |  -h ]";
	fi

}
#######################################################
# Scripts present
#
#######################################################
function checkForScripts() {
	preAmbleFunction $1 "scripts 'md_used.sh' and 'dotGen.sh' [Validation]"
	#
	# first check for dotGen.sh
 
	type dotGen.sh >/dev/null 2>&1 || { handleWarning "	$shellScript CANNOT find 'dotGen.sh' - it's not installed or found in PATH."; }
	#
	# first check for md_used.sh
 
	type md_used.sh >/dev/null 2>&1 || { handleWarning "	$shellScript CANNOT find 'md_used.sh' - it's not installed or found in PATH."; }

	resetCursor;

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
#
#######################################################
# get all Packages Installed
#######################################################

function packagesInstalled(){
	local textFile="$curDir/packages-installed.txt"
	preAmbleFunction  $1 "Packages Installed ... [$textFile] "
	
	${SFDX} force:package:installed:list -u "$authUser" > "$textFile"
}
#
#
#######################################################
# get metadata dependencies
#######################################################

function runMetadataDependencies(){
	# run metadata dependencies and dot generator
	if [ ! -z ${runmd} ];
	then
	  # get metadata
	  md_used.sh -u "$authUser" -l "$curDir" 
	  # create dot files ( visualization); the other arguments indicate which dot type to create (i.e. -z == ALL, -a == apex, -c == custom-object, ...)
	  dotGen.sh  -u "$authUser" -x "$curDir" -z
	fi
}
#
#######################################################
# simple analyze Org
#######################################################

function analyzeOrg() { 
	local textFile="$curDir/SObjects-counts.txt"
	preAmbleFunction  $1 "Analyze custom/standard object from Org [data store in $textFile]... "
	local allCustomSObjects=$(${SFDX} force:schema:sobject:list -c custom -u ${authUser} | wc -l);
	local allStandardSObjects=$(${SFDX} force:schema:sobject:list -c standard -u ${authUser} | wc -l);
	local allSObjects=$((allStandardSObjects + allCustomSObjects));

	echo "Number of Standard SObjects: $allStandardSObjects" > ${textFile}
	echo "Number of Custom SObjects  : $allCustomSObjects" >> ${textFile}
	echo "Number of ALL SObjects     : $allSObjects" >> ${textFile}
	
}
#
#######################################################
# initialize location
#######################################################
#
function initLocation() {
 
	preAmbleFunction $1 "Initializing directory for Analyzes ... results will be placed in '$curDir/$orgAnalysis' ";
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
	# our analyses directory
	if [ ! -d "$curDir/$orgAnalysis" ];
	then
		mkdir "$curDir/$orgAnalysis" >/dev/null 2>&1  || { echo ">>$curDir/$orgAnalysis<< unable to create directory '$curDir/$orgAnalysis'"; }
	fi
	# our directory  
	cd "$curDir/$orgAnalysis";
	# we have the full path
	curDir=`pwd`;
	# our default directory to hold source
	if [ ! -d "$curDir/force-app" ];
	then
		mkdir "$curDir/force-app" >/dev/null 2>&1  || { echo ">>$curDir/force-app<< unable to create directory '$curDir/force-app'"; }
		mkdir "$curDir/force-app/main" >/dev/null 2>&1  || { echo ">>$curDir/force-app/main<< unable to create directory '$curDir/force-app/main'"; }			
	fi
	if [ ! -d "$curDir/force-app/main" ];
	then
		mkdir "$curDir/force-app/main" >/dev/null 2>&1  || { echo ">>$curDir/force-app/main<< unable to create directory '$curDir/force-app/main'"; }
		mkdir "$curDir/force-app/main/default" >/dev/null 2>&1  || { echo ">>$curDir/force-app/main/default<< unable to create directory '$curDir/force-app/main/default'"; }			
	fi
	if [ ! -d "$curDir/force-app/main/default" ];
	then
		mkdir "$curDir/force-app/main/default" >/dev/null 2>&1  || { echo ">>$curDir/force-app/main/default<< unable to create directory '$curDir/force-app/main/default'"; }			
	fi
	#
	# These files are used to pull data from the org
	# and to tell SFDX that is a place you can place the results ( from a mdapi convert);
	# otherwise, it indicates it is NOT a valid SFDX directory
	#
	if [ ! -f "$curDir/package.xml" ];
	then
		cp "$resDir/package.xml" "$curDir";
	fi
	if [ ! -f "$curDir/sfdx-project.json" ];
	then
		cp "$resDir/sfdx-project.json" "$curDir";
	fi

}
#
#######################################################
# retrieve metadata (using package.xml)
#######################################################
#
function retrieveMDAndConvert() {

	preAmbleFunction $1 "Retrieving metadata from Org [pushing to $curDir], please wait "
	
	# our md apii directory
	if [ ! -d "$curDir/$mdapiDir" ];
	then
			mkdir $curDir/$mdapiDir >/dev/null 2>&1  || { echo ">>$curDir/$mdapiDir<< unable to create directory '$curDir/$mdapiDir'"; }
	fi
	
	# makes sfdx happy
	cd $curDir
	if [ ! -f "./package.xml" ];
	then
		handleError "could not find $curDir/package.xml -- problem occured in initialization";
	fi
	# get md from org
	${SFDX} force:mdapi:retrieve -s -r "$mdapiDir" -u "$authUser" -w 45 -k "./package.xml"
	# check last comamand to see if it finished; if not there is a continuation to check

	if [ $? -gt 0 ];
	then
		${SFDX} force:mdapi:retrieve:report -u "$authUser" >/dev/null 2>&1 
	fi
	# cd to mdapi
	cd "$mdapiDir"
	# unzip
	unzip -o unpackaged.zip >/dev/null 2>&1 || { handleError "file is not present in $curDir/$mdapiDir/unpackaged.zip."; }
	cd ..
}
#
#######################################################
# create csv files from metadata categories
#######################################################
#
function csvFiles(){ 
	# if all ok, let's create the spreadsheet to start tracking
	if [ $? -eq 0 ];
	then
		# any data here
		if [ -n "$(find $curDir/$mdDir -prune -empty 2>/dev/null)" ]
		then
			handleError "empty $curDir/$mdDir -- ensure the mdapi convert had run successfully";
		fi
		
		sheetsDir="$curDir/csvSheets";
		# our csv  directory
		if [ ! -d "$sheetsDir" ];
		then
			mkdir $sheetsDir >/dev/null 2>&1  || { handleError ">>$sheetsDir<< unable to create directory '$sheetsDir'"; }
		fi
		preAmbleFunction $1 "Creating CSV files and segregating into files ('$sheetsDir')... "
		# if the all csv file is present we assume they have already run the analysis
		if [ ! -f "$sheetsDir/$mdList" ];
		then
	
			cd "$curDir/$mdDir"
			local tmp="$mdList-tmp";
			# this brings back ALL files
			find . -type f | grep -v "$mdList" | awk -F"/" '{printf "%s%s%s%s%s%s\n",$3,($5=="")?"":"/",$4, ($5=="")?"":$5, ",",$2}' >> "${tmp}"
			cat "${tmp}" | awk -f "${shellLocation}/csvSheets.sh"
			rm "${tmp}"
			mv *.txt *.csv "${sheetsDir}"
			cd "$curDir"
		else
			handleWarning "Will not overwrite " "$sheetsDir/$mdList"
		fi
	fi
}
#
#######################################################
#  metadata  converted to source
#######################################################
#
function mdapiConvert() { 
	 
	preAmbleFunction $1 "MDAPI Conversion [$curDir]... please wait"
	# our force-app directory
	if [ ! -d "$curDir/$destDir" ]
	then
			mkdir "$curDir/$destDir" >/dev/null 2>&1  || { echo ">>$curDir/$destDir<< unable to create directory '$curDir/$destDir'"; }
	fi
	cd $curDir
	# convert
	${SFDX} force:mdapi:convert -r "$mdapiDir" -d "$destDir"  >/dev/null 2>&1 || { echo ">>$destDir<< issue converting package - this HAS TO BE a Project"; }
}
#
#######################################################
#  pull data base on some 'known' prefix (TBD)
#######################################################
#
function createSectionsFor(){ 
	# if all ok, let's create the spreadsheet to start tracking
	if [ $? -eq 0 ];
	then
		preAmbleFunction $1 "Create Sections... "
		cd "$curDir/$mdDir"
		find . -type f  | grep "$prefix" | awk -F"/" '{printf "%s%s%s%s%s%s\n",$3,($5=="")?"":"/",$4, ($5=="")?"":$5, ",",$2}' > cr_soup
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
