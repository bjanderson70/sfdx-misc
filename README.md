# Salesforce SFDX Misc

This repo provides tools to assist with transitioning from *Happy Soup* to DX. 

## DX Project Shell Scripts
This document outlines the shells scripts defined to support the DX Project initiative. 
These scripts (bash) provide a means to accelerate and encapsulate common behavior. 
It should be noted, these scripts are very much dependent upon SFDX command line (CLI) behavior 
and will likely change over the evolution of SFDX CLI.

## SFDX CLI
Understanding general functionality of SFDX CLI is needed. This comes into play when 
authorizing access to a non-ScratchOrg or ScratchOrg. Many of the commands expect a 
username/target-name (-u) to reference the Org. For example, a common command to 
see what Orgs (and Scratch Orgs) one has available, __sfdx force:org:list –all__:
![sfdx force org list commeand](/images/1_sfdxForceOrgList.png)

## Manifest
Below are a list of the shell scripts defined for the DX Project. Please note, most of the shel scripts (__.sh__) can be invoked
with help (__-h__) on the command line.

|Script name	| Description |
|------------|------------------------------------------------------------------------|
| analyzeOrg.sh| Utility  analyzes a Salesforce Org |
| buildScratchOrg.sh | Utility builds a Scratch Org with needed packages (i.e. FSC) |
| createProject.sh | Utility creates a VS Code Project; seeded with an unmanaged Package from Sandbox |
| dotGen.sh | Utility to pull metadata dependencies and create a visualization (Graphviz) |
| md_used.sh | Utility to pull down the metadata used in an Org |
| sfdxUrlEncrpt.sh | Utility to encrypt a SFDX URL stored token |
| orgInit.sh | Utility to create and push to Scratch Org (reading the sfdx-project.json file |
| orgInitPackage.sh | Utility to deploy to an Org (reading the sfdx-project.json file |
| packConfig.sh | Utility to set environment variables |
| setScratchOrgJSON.sh | Utility to create a project definition file for a scratch Org |
| csvSheets.sh | Called utility to create CSV files [awk script] |
| filterPackages.sh | Called utility to get installed package names and corresponding package Ids [awk script]|

## Tools Used
In order to limit the dependencies of these shell scripts, all shell scripts (bash) 
utilize the following (tools natively found in Unix environments) aspects:
* awk,
* grep,
* sed,
* cut 
* bash (shell script)

The two non-standard tools utilized are :
* [SFDX CLI](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm)
* [Graphviz (dot)](https://graphviz.gitlab.io/download/)

## Configuration
Each user is required to add the DX bin path to their PATH environment variable. At the 
time of this writing it is not certain where these scripts will reside. 
However, for example, if the DX project resides in the following directory 
(and assuming a git-bash shell installation on Windows), /c/salesforce/workspaceDXProject.
One would add the following to their resource file (either ~/.bashrc or ~/.bash_profile):


![export in bash script](/images/2_configuration.png)

## Standalone Shell Scripts
Below are the list of standalone scripts and their respective functionality. All standalone scripts provide general help (-h) and debug (-d).
### buildScratchOrg.sh

![buildScratchOrg](/images/buildScratchOrg.png)

This script builds a scratch org based on installed source Org. A Scratch Org can contain many features and required packages (i.e. FSC). Instead of guessing how and what to do, this script builds a scratch org for the user. At the time of this writing, data is **NOT** loaded into the Scratch Org – __TBD__.

The script takes a scratch-org user (-s <test*>), if known, otherwise, it creates a scratch org and applies the features and installs required packages into the scratch Org.

#### Command-line Arguments
|Name| Comments |
|----|----------|
|-s <test*>	| If an scratch org has already been created, you can pass that user-id (test-flfhb460d6df@example.com) and it will install into that scratch org. However, any features not enabled may cause a conflict. The scratch Org will expire after 2 days.|
|-u <source_org>	| If there is a source Org (non-scratch Org) which contains installed packages you want in your scratch Org; include it via the -u option. The script will read all the installed packages are attempt to replicate in your scratch org. Note, it ignores the package ID for the Financial Service Cloud to used ensure you are using the latest.|
|-f	| Ensures the latest Financial Service Cloud (FSC) package is installed. You would ONLY need this flag if : <ul><li>Your source org did not contain the FSC package, or </li><li>The common install package file did not include the FSC package name </li></ul>|
|-d	|Runs the script using set -xv|
|-h	|Help|

### General Comments

* The script pulls from a list of packages names (res/installPackages.txt). Note, there has to be an empty (new-line) at the end of this file. If the package id is known (__04t\*__) it would appear first followed by semi-colon (**\:**). If there is a source org specified, the script will use the org as a reference and determine the package id, if not present. For example, the __installPackage.txt__ (below) does not specify the Financial Services Cloud,  as it pulls the latest.

<span> ![buildScratchOrg](/images/installpackages_txt.png)</span>

* The script will check for the latest version of FSC (Financial Services Cloud) and install it. This is done because an FSC extension or feature may be deprecated. Thus, does not depend on the package id of the non-Scratch Org.
* The script does not require a VS Code Project Folder nor __sfdx-project.json__ file as is the case for many of the SFDX CLI commands.
* The script uses a non-scratch org instance (if included -u <source-org>) to determine what packages to be included. It uses the SFDX command (**force\:package\:installed\:list**) along with the file, __installPackages.txt__, to determine what packages are required
* Depending on the number of packages to install, the script may take well over 20 minutes to install. For example, the list found in the example above, the installation took ~20 minutes.
  
### When to Use?
Use this script to initialize a Scratch Org for development. Some development teams require features and packages to be installed in order to test and validate. For example, many financial companies use Financial Service Cloud (FSC) which must be installed before installing dependent components.

