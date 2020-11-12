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
############################################################################
# Used to set the 'project-scratch-def.json' file
#
############################################################################

defName='Unknown-Scratch-Org-Name'
defEdition='Enterprise'

name=${1:-$defName} 
edition=${2:-$defEdition} 
shellLoc=$3;
packLoc=$4;

#
# Help
#
function Help()
{
    
    echo
    echo "Requires 4 command line arguments to update 'project-scratch-def.json'..."
    echo
    echo "     Command line Order:"
    echo "      1) Name of Scratch Org"
    echo "      2) Scratch Org Edition (i.e. Developer, Enterprise ...)"
    echo "      3) Shell Location"
    echo "      4) Package Location to update 'project-scratch-def.json'"
    exit;
}
#
# Command Line Help
#
# Get the options
while getopts ":h:d" option; do
   case $option in
      h) # display Help
         Help;;
   esac
done
 
#
# Error if arguments not set
#
if [ "$#" -lt 2 ]; then
    Help
fi

#
# May not pass in ALL arguments
#
if [ "$#" -eq 2 ]; then
  name=${defName}
  edition=${defEdition}
  shellLoc=$1
  packLoc=$2
fi


if [ -z "${name}" ]
  then
    name=${defName};
fi
if [ -z "${edition}" ]
  then
    edition=${defEdition} 
fi

if [ -z ${shellLoc} ]
  then
    echo "Error: Invalid Shell Location";
    Help
fi
if [ -z ${packLoc} ]
  then
	echo "Error: Invalid Package Location";
  Help
fi

COMMAND=`echo sed -e '/orgName/s/SCR_DXPROJECT/\$name/' -e '/edition/s/EDITION_TYPE/$edition/' $shellLoc/../res/project-scratch-def.json`
# run it
eval ${COMMAND} > $packLoc/config/project-scratch-def.json