#!/usr/bin/env awk
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
# creating separate CSV files ... If you want to create XLS files
# will need perl, python or some other tool. I cannot guarantee
# that will be available.
#
# Generate CSV files based on data files
#######################################################
BEGIN{ FS=",";
	
  Headers = "Name,Metadata Category, Development Team, Package";
  Working="";
  File="allCRVmetadata.csv"; 
  Counts="MetadataCounts";
  # getting ALL the metadata categories for tracking and creating individual CSV files
  CommandToRun = "find . -type f  | grep -v -e allCRVmetadata |  grep -v -e '.txt|.csv'| cut -d '/' -f2 | uniq";
  # run the command and and create array of metadata keys for tracking
  while (( CommandToRun |& getline ShellOutput ) > 0)  
    {                                               
	  Created[ShellOutput]=0;
    }
  close(CommandToRun); 
  # place headers in ALL csv file
  print Headers > File;
}
{
	# iterating now...
	# we check to see if this metadata category has ben created
	#
    if ( Created[$2] == 0 ){
		# first time, create a separate CSV file
		print Headers > $2".csv";
		Working=$2;
	}
	# count number of entries
	Created[Working] += 1;
	#exclude csv and txt files
	if ( $0 !~ /.txt|.csv/ ) {
		# append data to csv files
		print $0",TBD,Happy Soup" >> $2".csv" ;
		# append of list of ALL metadata
		print $0",TBD,Happy Soup" >> File;
		Working=$2;
	}
}
END {
    # tally the counts for each category
	for (key in Created) { 
		printf ("%5s : %s\n",Created[key],key) > Counts".txt"
	}
}
