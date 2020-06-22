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
# This script INSTALLS the packages ( listed in sfdx-project)
# run this script with -h for more information
#
#      orgInitPackage -h
#
#       (this script uses funcs.sh)
#######################################################

dirName=`dirname $0`;

# functions to process ( order matters)
functions=(checkForSFDX runFromRoot createScratchOrg installPackages setPermissions runApexTests complete openOrg)			
#######################################################
# soure common functions
#
#######################################################
function sourceFunctions() {
    if [[ -f "funcs.sh" ]]; then
        source funcs.sh
    else
        if [[ -f "$dirName/funcs.sh" ]]; then
            source "$dirName/funcs.sh"
        fi
    fi
}

#######################################################
# MAIN
#
# Steps to take 
#
#######################################################
# source our common functions
sourceFunctions

#reset console
trap shutdown EXIT
# cli arguments first
getCommandLineArgs "$@"
print "Running ..."
#run functions
for functionsToCall in "${functions[@]}"
do  	  
	$functionsToCall
done
