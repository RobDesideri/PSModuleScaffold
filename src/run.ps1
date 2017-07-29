<#
.SYNOPSIS
  The entry-point script for all automation tasks.
.DESCRIPTION
  Every automation task in this project is runned by this script.
.PARAMETER Automation
  The task to execute: one from build, deploy or test.
.PARAMETER Interactive
  Execute the selected task in the interactive mode.
.EXAMPLE
  PS C:\> .\run.ps1 build process
  Build the PS module.
.EXAMPLE
  PS C:\> .\run.ps1 test -process
  Execute all non-slow tests on the the builded module artifacts.
.EXAMPLE
  PS C:\> .\run.ps1 deploy -process
  Publish the builded module artifacts in the PSGallery
.EXAMPLE
  PS C:\> .\run.ps1 release -pipeline
  Execute all tasks and processes from build to deploy.
.EXAMPLE
  PS C:\> .\run.ps1 unit -test
  Execute all unit tests.
.EXAMPLE
  PS C:\> .\run.ps1 acceptance -test
  Execute all acceptance tests.
.EXAMPLE
  PS C:\> .\run.ps1 static -test
  Execute all static tests.
.EXAMPLE
  PS C:\> .\run.ps1 project -test
  Execute all project tests.
.EXAMPLE
  PS C:\> .\run.ps1 regression -test
  Execute all regression tests.
.EXAMPLE
  PS C:\> .\run.ps1 help -test
  Execute all help tests.
.INPUTS
  None.
.OUTPUTS
  None.
.NOTES
  This script exit with 0 or 1 based on succes or not. This is for the CI/CD prosecution.
#>

#------------------------------------------[Parameters]-------------------------------------------#

param(
  # Name of the process as string
  [Parameter(Mandatory = $true,
    Position = 0,
    HelpMessage = 'Name of the automation to start.')]
  [string]
  $AutomationName,

  # Name of the process as string
  [Parameter(Mandatory = $true,
    ParameterSetName = 'ProcessAutomation',
    HelpMessage = 'The "process" automation type.')]
  [switch]
  $Process,
  
  # Name of the process as string
  [Parameter(Mandatory = $true,
    ParameterSetName = 'PipelineAutomation',
    HelpMessage = 'The "pipeline" automation type.')]
  [switch]
  $Pipeline,
    
  # Name of the process as string
  [Parameter(Mandatory = $true,
    ParameterSetName = 'TestAutomation',
    HelpMessage = 'The "test" automation type.')]
  [switch]
  $Test,

  # Test tags to execute.
  [Parameter(Mandatory = $false,
    ParameterSetName = 'TestAutomation',
    HelpMessage = 'Test tags to filter-in.')]
  [string[]]
  $Tags,
  
  # Test scenarios to execute.
  [Parameter(Mandatory = $false,
  ParameterSetName = 'TestAutomation',
    HelpMessage = 'Acceptance scenarios to test.')]
  [string[]]
  $Scenarios
)

#--------------------------------------------[Settings]-------------------------------------------#

$ErrorActionPreference = 'Stop'

#---------------------------------------------[Deps]----------------------------------------------#

Write-Verbose " Installing PSDepend module..."
Install-Module -Name PSDepend -Scope CurrentUser
Import-Module PSDepend -ErrorAction SilentlyContinue

#-------------------------------------------[Functions]-------------------------------------------#

# WORKAROUND: see https://github.com/RamblingCookieMonster/PSDepend/issues/35
function psdependIssueWorkaround () {
  return $script:Deps.ScriptDeps.Clone()
}

function _prepareInvoke () {
  Write-Verbose " Installing all dependencies required from scripts..."
  Invoke-PSDepend -InputObject $(psdependIssueWorkaround) -Install -Import -Tags $script:ProcessToStart -Force
  Write-Information "  Starting $script:ProcessToStart process..."
}

#---------------------------------------------[Begin]---------------------------------------------#

$OriginalLocation = Get-Location
Set-Location $PSScriptRoot

# Get configuration variables
. .\config\_config.ps1

Invoke-PSDepend -InputObject $(psdependIssueWorkaround) -Install -Import -Tags Project -Force

#--------------------------------------------[Process]--------------------------------------------#

switch ($PSCmdlet.ParameterSetName) {
  'ProcessAutomation' { 
    _prepareInvoke
    .\scripts\processes.ps1 $AutomationName
  }

  'PipelineAutomation' {
    _prepareInvoke
    .\scripts\pipelines.ps1 $AutomationName
  }

  'TestAutomation' { 
    _prepareInvoke
    $TestType = $ProcessToStart -replace 'test', ''
    .\scripts\test.ps1 $TestType $Tags
  }

  Default {
    throw "The process $ProcessToStart is not implemented in $($Config.ModuleName) project."
  }
}

#----------------------------------------------[End]----------------------------------------------#

# Restore location
Set-Location $OriginalLocation