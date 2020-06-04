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
# Used to create specifc files for each Capability Team
# These prefixes are parsed from the files to determine
# cross references (from the Metadata Dependencies API via SFDX)
#  Squad       Prefix
#  =======   |  ======
#  Growth    |
#  Services  | CR_
#  Core      | CRV_
#
#
# This can be refactor -- a lot of duplicated parts :-(
#######################################################


#######################################################
# Functions For Processing
#######################################################

# functions to process ( order matters)
#preAmble 
functions=( checkForDot checkForDataFiles apexPerformParse lwcPerformParse customObjectPerformParse vfPerformParse staticResPerformParse createGraph complete)
			
# Squad Filters
# indexed
# 0 = Services
# 1 = Core
# 2 = Growth
SquadFilters=( "CR_" "CRV_" )
Squads=( "Services" "Core" )
# Used for representing MD API resources
# Squad Filters
# indexed
# 0 = #21DE80 == Custom Object
# 1 = #A9DF1F == Static Resources
# 2 = #EBDEF0 == Apex
# 3 = #CBDE50 == Lightning
Colors=( "#21DE80" \
	"#A9DF1F" \
	"#EBDEF0" \
	"#CBDE50" \
	"#11DEF0")
# color index
cCOIndex=0;
cSRIndex=1;
cApexIndex=2;
cLWCIndex=3;
vfIndex=4;
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
reset=`tput sgr0`

#######################################################
# For Operations
#######################################################
curDir=`pwd`
step=0;
dataLocation=$curDir;
#######################################################
# Global values discovered
#######################################################
shellLocation=`dirname ${0}`;
shellscript=`basename ${0}`;
headerLocation="$shellLocation/../res";
skipAll=;
apex_prefix='apex';
lwc_prefix='lwc';
apexGVOUT=apex.svg
lwcGVOUT=lightning.svg
coGVOUT=custom_object.svg
srGVOUT=staticRes.svg
vfGVOUT=vf.svg
dotPresent=1;
authUser=;
apex=;
cobject=;
flows=;
global=;
fields=;
lwc=;
orch=;
csettings=;
staticres=;
vf=;
filterType=;
#######################################################
# For Capability Squads filtering
# no default -- filter for Services ( index == 0)
filterIndex=;
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
		echo "Starting Graph configuration for user: '$USERNAME' "
		if [ -z $filterIndex ];
		then
			printf "\n\t >No filter process for Capability Squads"
		else
			printf "\n\t >Processing for Capability Squad '${Squads[$filterIndex]}'"
		fi
		printf "\n\t >Perform some validations"
		printf "\n\t >Pull Metadata Dependency Data and Parse"
		printf "\n\t >Create Graph\n"
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
    echo "Usage: $shellscript [ -u <username> | -t <filter-type> | -x <data-location> | -a | -c | -d | -f | -g | -i | -l | -o | -r | -s | -v | -z | -h ]"
	printf "\n\t -u <username>"
	printf "\n\t -t <filter-type> , where '<filter-type>' is 's' for service, 'c' for core"
	printf "\n\t -x <data-location> "
	printf "\n\t -a Apex"
	printf "\n\t -c custom object"
	printf "\n\t -d debug"
	printf "\n\t -f flows"
	printf "\n\t -g global set values"
	printf "\n\t -i custom fields"
	printf "\n\t -l lightning/lwc/aura"
	printf "\n\t -o orchestration"
	printf "\n\t -r static resource"
	printf "\n\t -s custom settings"
	printf "\n\t -v visual force"
	printf "\n\t -z [run ALL]"
	printf "\n\t -h the help\n"
    resetCursor;
	exit 0
}
#######################################################
# Help
#
#######################################################
function getCommandLineArgs() {

	while getopts u:t:x:acdfghlorsvz option
	do
		case "${option}"
		in
			u) authUser=${OPTARG};;
			a) apex=1;;
			c) cobject=1;;
			d) set -xv;;
			f) flows=1;;
			g) global=1;;
			i) fields=1;;
			l) lwc=1;;
			o) orch=1;;
			r) staticres=1;;
			s) csettings=1;;
			t) filterType=${OPTARG};;
			v) vf=1;;
			x) dataLocation=${OPTARG};;
			z) apex=1;
				cobject=1;
				flows=1;
				global=1;
				fields=1;
				lwc=1;
				orch=1;
				staticres=1;
				csettings=1;
				vf=1;
				;;				
			h) help;;
		esac
	done
	
	# case insensitive compare
	local orig_nocasematch=$(shopt -p nocasematch)
	shopt -s nocasematch
	if [ ! -z $filterType ]; then
		if [ "$filterType" = "s" ]; 
		then
			filterIndex=0;
		else if [ "$filterType" = "c" ]; 
			then
				filterIndex=1;
			fi
		fi
	fi

	$orig_nocasematch
	
}
#######################################################
# DOT present
#
#######################################################
function checkForDot(){
	
	preAmbleFunction $1 "dot [Validation]"
	#
	# first check for graphviz/dot
 
	type dot >/dev/null 2>&1 || { handleWarning "	$0 lost funcitonality without 'graphviz' for dependency graph - it's not installed or found in PATH."; }
	#printAction "${green}'dot' command found..."
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
# Ensure Data Files are present ( generated by metadata dependency)
#
#######################################################
function checkForDataFiles() {

	if [ ! -d "$dataLocation/data" ];
	then
		handleError "Directory ($dataLocation/data) does not exists -- require 'md_used.sh' to have created the metadata dependencies";
	fi
	# any data here
	if [ -n "$(find $dataLocation/data -prune -empty 2>/dev/null)" ]
	then
		handleError "No data ... empty $dataLocation/data -- ensure there are data files ( generated via 'md_used.sh')";
	fi
	if [ ! -d  "$dataLocation/parsed" ];
	then
		mkdir "$dataLocation/parsed" >/dev/null 2>&1  || { handleError ">>$dataLocation/parsed<< unable to create directory '$dataLocation/parsed'"; }
	fi
	if [ ! -d  "$dataLocation/png" ];
	then
		mkdir "$dataLocation/png" >/dev/null 2>&1  || { handleError ">>$dataLocation/png<< unable to create directory '$dataLocation/png'"; }
	fi

}

#######################################################
#Perform Custom Object Parse
#
#######################################################
function customObjectPerformParse()
{ 
	cd $dataLocation;
	local myfilesize=$(wc -l "./data/custom_objects.txt" | awk '{print $1}')
	
	if [[ (! -z $cobject) && $myfilesize -gt 3 ]]
	then
		preAmbleFunction $1 "Perform Custom Object Parsing"
		cat ./data/custom_objects.txt | grep -v -e 'METADATACOMPONENTID' |grep -v -e ' number of records retrieved'  | grep -v -e '───────────────────'  | sed 's/\.cmp/_cmp/g' | sed 's/\.design/_design/g' | grep -v -e 'Test'  > ./data/co_prelim.txt
		cat "$headerLocation"/header.txt > ./parsed/customObject.txt
		# for inspection
		if [ ! -z $filterIndex ];
		then
			cat ./data/co_prelim.txt | grep "${SquadFilters[$filterIndex]}" >>./parsed/customObject.txt
		else
			cat ./data/co_prelim.txt  >>./parsed/customObject.txt
		fi
		if [ -z $filterIndex ];
		then
			# create the color nodes
			cat ./data/co_prelim.txt | sort | uniq | awk -v mcolor="${Colors[$cCOIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $2" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/co_color_for_nodes.txt
			# inject the nodes
			cat ./data/co_prelim.txt  | sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/co_crv_notst.txt
		else
			# create the color nodes
			cat ./data/co_prelim.txt | grep -oh "\w*${SquadFilters[$filterIndex]}\w*" | sort | uniq | awk -v mcolor="${Colors[$cCOIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $1" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/co_color_for_nodes.txt
			# inject the nodes
			cat ./data/co_prelim.txt  |  grep -E -- "${SquadFilters[$filterIndex]}" | sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/co_crv_notst.txt
		fi
		# cat the parts together
		cat ./data/co_color_for_nodes.txt ./data/co_crv_notst.txt > ./png/co_dot.dot
		#cp co_prelim.txt co_crv_notst.txt ./parsed
		rm -rf ./data/co_color_for_nodes.txt ./data/co_crv_notst.txt   >/dev/null 2>&1
	fi
}
#######################################################
#Perform Apex Parse
#
#######################################################
function apexPerformParse()
{ 
	cd $dataLocation;
	local myfilesize=$(wc -l "./data/apex_classess.txt" | awk '{print $1}')
	if [[ (! -z $apex) && $myfilesize -gt 3 ]]
	then
		preAmbleFunction $1 "Perform Apex Parsing"
		cat ./data/apex_classess.txt | grep -v -e 'METADATACOMPONENTID' |grep -v -e ' number of records retrieved'  | grep -v -e '───────────────────'  | sed 's/\.cmp/_cmp/g' | sed 's/\.design/_design/g' | grep -v -e 'Test'  > ./data/apex_prelim.txt
		cat "$headerLocation"/header.txt > ./parsed/apex.txt
		if [ ! -z $filterIndex ];
		then
			# for inspection
			cat ./data/apex_prelim.txt | grep "${SquadFilters[$filterIndex]}" >> ./parsed/apex.txt
		else
			# for inspection
			cat ./data/apex_prelim.txt >> ./parsed/apex.txt
		fi
		if [ ! -z $filterIndex ];
		then
			# create the color nodes
			cat ./data/apex_prelim.txt | grep -oh "\w*${SquadFilters[$filterIndex]}\w*" | sort | uniq | awk -v mcolor="${Colors[$cApexIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $1" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/apex_color_for_nodes.txt
			# inject the nodes 
			cat ./data/apex_prelim.txt  |  grep -E -- "${SquadFilters[$filterIndex]}" | sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/apex_crv_notst.txt
		else
			# create the color nodes
			cat ./data/apex_prelim.txt |  sort | uniq | awk -v mcolor="${Colors[$cApexIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $2" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/apex_color_for_nodes.txt
			# inject the nodes 
			cat ./data/apex_prelim.txt  |  sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/apex_crv_notst.txt

		fi
		# cat the parts together
		cat ./data/apex_color_for_nodes.txt ./data/apex_crv_notst.txt > ./png/apex_dot.dot
		rm -rf ./data/apex_prelim.txt ./data/apex_crv_notst.txt  >/dev/null 2>&1
	fi
	 
}
#######################################################
#Perform VisualForce Page Parse
#
#######################################################
function vfPerformParse()
{ 
	cd $dataLocation;
	local myfilesize=$(wc -l "./data/vf_pages.txt" | awk '{print $1}')
	if [[ (! -z $vf) && $myfilesize -gt 3 ]]
	then
		preAmbleFunction $1 "Perform VisualForce Parsing"
		cat ./data/vf_pages.txt | grep -v -e 'METADATACOMPONENTID' |grep -v -e ' number of records retrieved'  | grep -v -e '───────────────────'  | sed 's/\.cmp/_cmp/g' | sed 's/\.design/_design/g' | grep -v -e 'Test'  > ./data/vf_prelim.txt
		cat "$headerLocation"/header.txt > ./parsed/vf.txt
		if [ ! -z $filterIndex ];
		then
			# for inspection
			cat ./data/vf_prelim.txt | grep "${SquadFilters[$filterIndex]}" >> ./parsed/vf.txt
		else
			# for inspection
			cat ./data/vf_prelim.txt >> ./parsed/vf.txt
		fi
		if [ ! -z $filterIndex ];
		then
			# create the color nodes
			cat ./data/vf_prelim.txt | grep -oh "\w*${SquadFilters[$filterIndex]}\w*" | sort | uniq | awk -v mcolor="${Colors[$vfIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $1" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/vf_color_for_nodes.txt
			# inject the nodes
			cat ./data/vf_prelim.txt  |  grep -E -- "${SquadFilters[$filterIndex]}" | sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/vf_crv_notst.txt
		else
			# create the color nodes
			cat ./data/vf_prelim.txt |  sort | uniq | awk -v mcolor="${Colors[$vfIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $2" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/vf_color_for_nodes.txt
			# inject the nodes
			cat ./data/vf_prelim.txt  | sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/vf_crv_notst.txt
		
		fi
		# cat the parts together
		cat ./data/vf_color_for_nodes.txt ./data/vf_crv_notst.txt > ./png/vf_dot.dot
		cp ./data/vf_prelim.txt ./data/vf_crv_notst.txt ./parsed
		rm -rf ./data/vf_prelim.txt ./data/vf_crv_notst.txt  >/dev/null 2>&1
	fi
}
#######################################################
#Perform Lightning Parse
#
#######################################################
function lwcPerformParse()
{ 
	cd $dataLocation;
	local myfilesize=$(wc -l "./data/lightning_comp.txt" | awk '{print $1}')

	if [[ (! -z $lwc) && $myfilesize -gt 3 ]]
	then
		preAmbleFunction $1 "Perform Lightning Parsing"
		cat ./data/lightning_comp.txt | grep -v -e 'METADATACOMPONENTID' | grep -v -e ' number of records retrieved'  | grep -v -e '───────────────────' | grep -v -e  '.auradoc' | grep -v -e '.svg' | sed 's/\.evt/_evt/g'|sed 's/\.cmp/_cmp/g'|grep -v -e '.css' | sed 's/\.design/_design/g' | sed 's/\.js/_js/g' | sed 's/\./_/g' | grep -v -e 'Test'  > ./data/lwc_prelim.txt
		# for inspection
		cat "$headerLocation"/header.txt > ./parsed/lwc.txt
		if [ ! -z $filterIndex ];
		then
			# for inspection
			cat ./data/lwc_prelim.txt | grep "${SquadFilters[$filterIndex]}" >> ./parsed/lwc.txt
		else
		# fo	r inspection
			cat ./data/lwc_prelim.txt  >> ./parsed/lwc.txt
		fi
		if [ ! -z $filterIndex ];
		then
			# create the color nodes
			cat ./data/lwc_prelim.txt | grep -oh "\w*${SquadFilters[$filterIndex]}\w*"  | sort | uniq| awk -v mcolor="${Colors[$cLWCIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $1" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/lwc_color_for_nodes.txt
			# inject the nodes
			cat ./data/lwc_prelim.txt  |  grep -E -- "${SquadFilters[$filterIndex]}" | sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/lwc_crv_notst.txt
		else
			# create the color nodes
			cat ./data/lwc_prelim.txt |  sort | uniq| awk -v mcolor="${Colors[$cLWCIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $2" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/lwc_color_for_nodes.txt
			# inject the nodes
			cat ./data/lwc_prelim.txt  |  sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/lwc_crv_notst.txt
				
		fi
		# cat the parts together
		cat ./data/lwc_color_for_nodes.txt ./data/lwc_crv_notst.txt > ./png/lwc_dot.dot
		#cp lwc_prelim.txt lwc_crv_notst.txt ./parsed
		rm -rf ./data/lwc_color_for_nodes.txt ./data/lwc_crv_notst.txt  >/dev/null 2>&1
	fi
}
#######################################################
#Perform Static Resource Parse
#
#######################################################
function staticResPerformParse()
{ 
	cd $dataLocation;
	local myfilesize=$(wc -l "./data/static_res.txt" | awk '{print $1}')
	 
	if [[ (! -z $staticres) && $myfilesize -gt 3 ]]
	then
		preAmbleFunction $1 "Perform Static Resource Parsing"
		cat ./data/static_res.txt | grep -v -e 'METADATACOMPONENTID' | grep -v -e ' number of records retrieved'  | grep -v -e '───────────────────' | grep -v -e  '.auradoc' | grep -v -e '.svg' | sed 's/\.evt/_evt/g'|sed 's/\.cmp/_cmp/g'|grep -v -e '.css' | sed 's/\.design/_design/g' | sed 's/\.js/_js/g' | grep -v -e 'Test'  > ./data/sr_prelim.txt
		# for inspection
		cat "$headerLocation"/header.txt > ./parsed/staticRes.txt
		if [ ! -z $filterIndex ];
		then
			# for inspection
			cat ./data/sr_prelim.txt | grep "${SquadFilters[$filterIndex]}" >> ./parsed/staticRes.txt
		else
			# for inspection
			cat ./data/sr_prelim.txt >> ./parsed/staticRes.txt
		fi
		if [ ! -z $filterIndex ];
		then
			# create the color nodes
			cat ./data/sr_prelim.txt | grep -oh "\w*${SquadFilters[$filterIndex]}\w*"  | sort | uniq| awk -v mcolor="${Colors[$cSRIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $1" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/sr_color_for_nodes.txt
			# inject the nodes
			cat ./data/sr_prelim.txt  |  grep -E -- "${SquadFilters[$filterIndex]}" | sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/sr_crv_notst.txt
		else
			# create the color nodes
			cat ./data/sr_prelim.txt | sort | uniq| awk -v mcolor="${Colors[$cSRIndex]}" 'BEGIN { print "digraph graphname {\n rankdir=RL;\n node[shape=Mrecord, bgcolor=black, fillcolor=lightblue, style=filled];\n " } { print $2" [shape=box,style=filled,color=\"black\",fillcolor=\""mcolor"\"]"}' > ./data/sr_color_for_nodes.txt
			# inject the nodes
			cat ./data/sr_prelim.txt  | sort | uniq |  awk '{print $2"->"$5} END { print "\n}"}' > ./data/sr_crv_notst.txt
			
		fi
		# cat the parts together
		cat ./data/sr_color_for_nodes.txt ./data/sr_crv_notst.txt > ./png/sr_dot.dot
		#cp sr_prelim.txt sr_crv_notst.txt ./parsed
		rm -rf ./data/sr_color_for_nodes.txt ./data/sr_crv_notst.txt>/dev/null 2>&1
	fi
}
#######################################################
#Perform Custom Label Parse
#
#######################################################
#

#######################################################
#Perform Flows Parse
#
#######################################################
#

#######################################################
# Generate DOT file (Graphiviz)
#
#######################################################
function createGraph(){
	# graphviz present
	if [ $dotPresent = '1' ]
	then
		step=$1;
		
		cd  "$dataLocation/png"
		# generate graph
		if [ ! -z $apex ]
		then
			
			preAmbleFunction $step "Creating Graph file: '$apexGVOUT'"
			rm -rf $apexGVOUT
			dot -Tsvg -o$apexGVOUT apex_dot.dot
			((step=step+1));
		fi
		if [ ! -z $lwc ]
		then
			preAmbleFunction $step "Creating Graph file: '$lwcGVOUT'"
			rm -rf $lwcGVOUT
			dot -Tsvg -o$lwcGVOUT lwc_dot.dot
			((step=step+1));
		fi
		if [ ! -z $cobject ]
		then
			
			preAmbleFunction $step "Creating Graph file: '$coGVOUT'"
			rm -rf $coGVOUT
			dot -Tsvg -o$coGVOUT co_dot.dot
			((step=step+1));
		fi
		if [ ! -z $staticres ]
		then
			preAmbleFunction $step "Creating Graph file: '$srGVOUT'"
			rm -rf $srGVOUT
			dot -Tsvg -o$srGVOUT sr_dot.dot
			((step=step+1));
		fi
		if [ ! -z $vf ]
		then
			preAmbleFunction $step "Creating Graph file: '$vfGVOUT'"
			rm -rf $vfGVOUT
			dot -Tsvg -o$vfGVOUT vf_dot.dot
			((step=step+1));
		fi
		cd $curDir
	fi
}
#######################################################
# Cleanup/Complete
#
#######################################################
function complete(){
	resetCursor
	preAmbleFunction $1 "Cleanup [Done]"
	#
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