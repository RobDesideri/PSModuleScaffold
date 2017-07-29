#Requires -Module InvokeBuild

<#
.SYNOPSIS
  Pipelines launcher.
.DESCRIPTION
  Launch the automated $Pipeline through InvokeBuild.
  Every Pipeline is composed by one or more processes (see the script processes.ps1).
.EXAMPLE
  .\pipelines.ps1
  .\pipelines.ps1 Release
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

param(
  # Task to launch
  [Parameter(Mandatory = $false,
    Position = 0)]
  [string]
  $Pipeline = '.'
)

# See https://github.com/nightroman/Invoke-Build/tree/master/Tasks/Direct
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
  Invoke-Build -Task $Pipeline -File $MyInvocation.MyCommand.Path
  return
}

requires Dirs

#---------------------------------------------[Begin]---------------------------------------------#

$OriginalLocation = Get-Location
Set-Location $PSScriptRoot

#--------------------------------------------[Process]--------------------------------------------#

# Check and launch the process
if (
  $ENV:BHBuildSystem -eq 'Unknown' -or 
  $ENV:BHBranchName -ne "master"
) {
  "Skipping deployment: To deploy, ensure that...`n" + 
  "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" + 
  "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n"
}
else {
  Task . Release
  Task Release Build, Test, Package, Deploy
}

#----------------------------------------------[End]----------------------------------------------#

# Restore location
Set-Location $OriginalLocation