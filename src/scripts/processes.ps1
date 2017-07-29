#Requires -Module InvokeBuild

<#
.SYNOPSIS
  Processes launcher.
.DESCRIPTION
  Launch the $Process through InvokeBuild.
  Every process is composed by one or more InvokeBuild tasks.
.EXAMPLE
  .\processes.ps1 Build
  .\processes.ps1 Test
  .\processes.ps1 Package
  .\processes.ps1 Deploy
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
  $Process = 'build'
)

if ($MyInvocation.InvocationName -eq '&') {
  $invocationType = 'operator'
}
elseif ($MyInvocation.InvocationName -eq '.') {
  $invocationType = 'dotsource'
}
elseif ((Resolve-Path -Path `
      $MyInvocation.InvocationName).ProviderPath -eq `
    $MyInvocation.MyCommand.Path) {
  $invocationType = 'path'
}

# If dotsource then this script is used only as tasks container
if ($invocationType -ne 'dotsource') {
  # Auto-invocation, see https://github.com/nightroman/Invoke-Build/tree/master/Tasks/Direct
  if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    Invoke-Build -Task $Process -File $MyInvocation.MyCommand.Path
    return
  }
}

requires Dirs

#---------------------------------------------[Begin]---------------------------------------------#

$OriginalLocation = Get-Location
Set-Location $PSScriptRoot

#--------------------------------------------[Process]--------------------------------------------#

# Set build ENV variables
Set-BuildEnvironment -Path $Dirs.ProjectRoot -BuildOutput $Dirs.Build -Force

# Dot-Source all helpers and tasks
# See https://github.com/nightroman/Invoke-Build/tree/master/Tasks/Import
foreach (
  $_ in $(
    Get-ChildItem -File -Path .\* -Recurse |
      Where-Object {$_.FullName -match '_helpers\\.*\.ps1$|\.tasks\.ps1$'}
  )
) {. $_.FullName}


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
  Task Build CleanBuild, CopyStaticSrcToBuild, BundlePSM1Module, CreatePSD1Manifest
  Task Test ImportModule, AllTests
  Task Package UpdateVersion
  Task Deploy PublishOnPSGallery
}

#----------------------------------------------[End]----------------------------------------------#

# Restore location
Set-Location $OriginalLocation