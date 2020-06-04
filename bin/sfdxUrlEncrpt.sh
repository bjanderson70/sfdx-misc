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
# functions to process ( order matters)
functions=( preAmble \
			checkForJQ\
			checkForSFDX\
			checkForOpenssl\
			getUsernames\
			getSecretKey\
			performEncryption\
			performDecryption\
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
# global values 
#######################################################
authUser=
skipAll=
secretKey=
step=0
encryptFile=".sf-org-login.txt"
decrypt=

#######################################################
# Functions
#######################################################

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
		echo "Encryption/Decryption of Auth Url"
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
		printf "\t[Step $1] ... $2 ...\n"
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
# Check for SFDX
#
#######################################################
function checkForSFDX(){

	preAmbleFunction $1 "SFDX [Validation]"
 
	type sfdx >/dev/null 2>&1 || { handleError "	$0 requires sfdx but it's not installed or found in PATH."; }
	printAction "${green}'sfdx' command found..."
	resetCursor;
}

#######################################################
# Check for openssl
#
#######################################################
function checkForOpenssl(){

	preAmbleFunction $1 "openssl [Validation]"
	type openssl >/dev/null 2>&1 || { handleError "	$0 requires openssl but it's not installed or found in PATH."; }
	printAction "${green}'openssl' command found..."
	resetCursor;
}
#######################################################
# Check for jq
#
#######################################################
function checkForJQ(){

	preAmbleFunction $1 "JQ [Validation]"
 
	type jq >/dev/null 2>&1 || { handleError "	$0 requires jq but it's not installed or found in PATH."; }
	printAction "${green}'jq' command found..."
	resetCursor;
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
# Utility called when user aborts ( reset )
#
#######################################################
function shutdown() {
  tput cnorm # reset cursor
  rm -f .data$$un .result$$sn >/dev/null 2>&1
  if [ -z $decrypt ]; then
	rm -f  "$encryptFile" >/dev/null 2>&1
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
    echo "Usage: $0 [ -u <username|target-org> | -k <secret-key> | -k <out-key-file> | -d | -v | -h ]"
	printf "\n\t -u <username>"
	printf "\n\t -k <secret-key>"
	printf "\n\t -d decrypt the stored auth url"
	printf "\n\t -o <out-key-file> encrypted the stored auth url [note - .enc is added to end of file"
	printf "\n\t -v turn on debug"
	printf "\n\t -h the help\n"
	printf "\n\t Examples:\n"
	printf "\n\t [Decryption]..."  
	printf "\n\t $0 -k mykey123 -d -o sfout\n"  
	printf "\t\t the above expects a file name 'sfout.enc' -- note, the .enc is appended to incoming file"
	printf "\n\t $0 -k mykey123 -d \n"
	printf "\t\tthe above looks for the default encryption file '$$encryptFile.enc'\n"
	printf "\n"
	printf "\n\t [Encryption]..."  
	printf "\n\t $0 \n"
	printf "\t\tthe above command will be prompted for secret key and shown a list of valud usernames\n"
	printf "\n\t $0 -k mykey123 -u test-sadawq34sadasda"
	printf "\n\t $0 -k mykey123 -u test-sadawq34sadasda -o sfout\n"
	printf "\t\tthe above will write encrypted data to 'sfout.enc' "
    printf "\n"
	resetCursor;
	exit 0
}
#######################################################
# Command line arguments
#
#######################################################
function getCommandLineArgs() {
	while getopts u:k:o:dvh option
	do
		case "${option}"
		in
			u) authUser=${OPTARG};;
			k) secretKey=${OPTARG};;
			o) encryptFile=${OPTARG};;
			d) decrypt=1;;
			v) set -xv;;
			h) help; exit 1;;
		esac
	done
	if [[ ! -z $authUser && ! -z $secretKey  && ! -z $encryptFile ]]; then		
		skipAll=1;
	fi
	if [[ ! -z $decrypt && ! -z $secretKey  && ! -z $encryptFile ]]; then		
		skipAll=1;
	fi
	
}
#######################################################
# Get known user names
#
#######################################################
function getUsernames() {
	if [[  -z $authUser && -z $decrypt ]]; then	
		sfdx force:org:list --json > .data$$un
		jq '.result.nonScratchOrgs | .[].username' .data$$un > .result$$sn
		jq '.result.scratchOrgs | .[].username' .data$$un >> .result$$sn
		step=1
		#run functions
		for unames in `cat .result$$sn`
		do  
			printf "\t $step). $unames\n"
			((step=step+1));
		done
		((step=step-1));
		while true; do
		
				printf "\tWhich Username (1- $step)?:${red}";  
				read -r sel;
				
				if [ "$sel" -gt "$step" ]; then
					echo "${red}";printf "\tPlease select a valid user"; echo "${yellow}";
				else 
					if [ "$sel" -lt "1" ]; then
						echo "${red}";printf "\tPlease make a valid selection"; echo "${yellow}";
					else
						break;
					fi
				fi
		done
		step=1
		for unames in `cat .result$$sn`
		do  
			if [ "$sel" -eq "$step" ]; then
				authUser=$unames
				break;
			fi
			((step=step+1));
		done
	fi

}
#######################################################
# Get secret key
#
#######################################################
function getSecretKey() {

	if [ -z $secretKey ]; then	
		while true; do
	
			printf "${green}\tSecret key (used to encrypt urltoken)?:${red}";  
			read -r sel;
			
			if [ -z $sel ]; then
				echo "${red}";printf "\tPlease provide a valid key"; echo "${yellow}";
			else 
				secretKey="$sel"
				break;
			fi
		done
	fi
	resetCursor
}
#######################################################
# Perform Encryption
#
#######################################################
function performEncryption() {
	if [ -z $decrypt ]; then
		if [ -z $authUser ]; then	
			handleError "	$0 requires a valid username.";
		fi
		if [ -z "$secretKey" ]; then	
			handleError "	$0 requires a valid secret key.";
		fi
		if [ -z "$encryptFile" ]; then	
			handleError "	$0 requires a valid encryption file to store auth url.";
		fi
		 
		local trimAuth=`echo $authUser | sed "s/\"//g"`;
		# pull the auth url
		sfdx force:org:display -u $trimAuth --verbose | grep "Sfdx Auth Url" | awk '{print $4}'> $encryptFile || { handleError "	$0 problem with sfdx command."; }
		# encrypt it (using user's secret key)
		openssl aes-256-cbc -salt -pbkdf2  -k "$secretKey" -in $encryptFile -out "$encryptFile".enc || { handleError "	$0 problem with oppenssl command."; }
		
	fi
}
#######################################################
# Get known user names
#
#######################################################
function performDecryption() {

	if [ ! -z $decrypt ]; then
		if [ -z "$secretKey" ]; then	
			handleError "	$0 requires a valid secret key.";
		fi
		if [ -z "$encryptFile" ]; then	
			handleError "	$0 requires a valid encryption file to store auth url.";
		fi
	fi

	if [ -f "$encryptFile".enc ]; then
		# de-encrypt it (using user's secret key)
		openssl aes-256-cbc -d -salt -pbkdf2 -in "$encryptFile".enc -out "$encryptFile" -k "$secretKey"
	else
		handleError "	Not Found: '$encryptFile' requires a valid encryption file to store auth url.";
	fi
	
}
#######################################################
# Process Completed
#
#######################################################
function complete( ) {
	if [  -z $skipAll ]; then
		preAmbleFunction $1 "Complete"
	fi
	resetCursor;
}
#######################################################
# MAIN
#
# Steps to take for encryption/decryption
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