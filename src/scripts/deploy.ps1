#Requires -Module InvokeBuild, BuildHelpers
requires BuildRoot, Files, Dirs, Config

<#
.SYNOPSIS
  InvokeBuild bundling tasks.
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

#-----------------------------------------[Dotscourcing]------------------------------------------#

# Dot-Source configuration variables
. .\helpers\cfgReader.ps1

# Dot-Source build + test + package + deploy tasks
foreach($_ in Get-ChildItem -File -Path .\cd\* -Include "*.tasks.ps1" -Recurse) {. $_}

#----------------------------------------[ReleasePipeline]----------------------------------------#

Set-BuildEnvironment -Path $Dirs.ProjectRoot -BuildOutput $Dirs.Build

if (
  $ENV:BHBuildSystem -eq 'Unknown' -or 
  $ENV:BHBranchName -ne "master" -or 
  $ENV:BHCommitMessage -notmatch '!deploy'
) {
  "Skipping deployment: To deploy, ensure that...`n" + 
  "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" + 
  "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" + 
  "`t* Your commit message includes !deploy (Current: $ENV:BHCommitMessage)"
}else {
  Task . Build, Test, Package, Deploy
}