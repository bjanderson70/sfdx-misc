# Salesforce SFDX Misc

This repo provides tools to assist with transitioning from *HappySoup* to DX.

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

## Manifest

Script name	| Description
------------|----------------------------------------------------------------------------
:---        | :--- 
analyzeOrg.sh| Utility  analyzes a Salesforce Org
buildScratchOrg.sh | Utility builds a Scratch Org with needed packages (i.e. FSC)
createProject.sh | Utility creates a VS Code Project; seeded with an unmanaged Package from Sandbox
dotGen.sh | Utility to pull metadata dependencies and create a visualization (Graphviz)
md_used.sh | Utility to pull down the metadata used in an Org
sfdxUrlEncrpt.sh | Utility to encrypt a SFDX URL stored token
packConfig.sh | Utility to set environment variables
setScratchOrgJSON.sh | Utility to create a project definition file for a scratch Org
csvSheets.sh | Utility to create CSV files [awk]
filterPackages.sh | Utility to get installed package names and corresponding package Ids [awk]
