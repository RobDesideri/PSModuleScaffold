<#
.SYNOPSIS
  The entry-point script for all automation tasks.
.DESCRIPTION
  Every automation task in this project is runned by this script.
.PARAMETER TaskType
  The task to execute: one from build, deploy or test.
.PARAMETER Interactive
  Execute the selected task in the interactive mode.
.EXAMPLE
  PS C:\> .\automation.ps1 build
  Build the PS module under development
.EXAMPLE
  PS C:\> .\automation.ps1 test
  Execute all non-slow tests on the the builded module artifacts
.EXAMPLE
  PS C:\> .\automation.ps1 test -Interactive
  Run the scripts/test interactively, for test choice.
.EXAMPLE
  PS C:\> .\automation.ps1 deploy
  Publish the builded module artifacts in the PSGallery
.INPUTS
  None.
.OUTPUTS
  None.
.NOTES
  This script exit with 0 or 1 based on succes or not. This is for the CI/CD prosecution.
#>

[cmdletbinding()]
param(
  # Type of job to call
  [Parameter(Mandatory = $true,
    Position = 0,
    HelpMessage = 'Task to execute [test|build|deploy]')]
  [string]
  $TaskType,

  # Parameter passed to the Task
  [Parameter(Mandatory = $false,
    HelpMessage = 'Interactive session switch [True|False]')]
  [switch]
  $Interactive
)

# Load configuration object
.\config.ps1

### =============================================================================
### Variables Init
### =============================================================================

$Scripts = $Global:__.ScriptsFolder
$ProjectRoot = $Global:__.ProjectRoot

### =============================================================================
### Execution
### =============================================================================

switch ($Script:Task) {
  "build" {
    Write-Output "Starting build"

    Write-Output "  Install Dependent Modules"
    Install-Module InvokeBuild, BuildHelpers, PSDepend -Scope CurrentUser

    Write-Output "  Import Dependent Modules"
    Import-Module InvokeBuild, BuildHelpers, PSScriptAnalyzer

    # BuildHelpers cmdlet
    Set-BuildEnvironment

    # Invoke-Build cmdlet
    Write-Output "  InvokeBuild"
    Invoke-Build 'Default' -File "$Scripts\build.ps1" -Result Result

    if ($Result.Error) {
      exit 1
    }
    else {
      exit 0
    }
  }

  "deploy" {
    Write-Output "Starting deploy"
      
    Write-Output "  Install Dependent Modules"
    Install-Module PSDeploy, BuildHelpers -Scope CurrentUser
      
    Write-Output "  Import Dependent Modules"
    Import-Module PSDeploy, BuildHelpers
    
    # BuildHelpers cmdlet
    Set-BuildEnvironment

    # PSDeploy cmdlet
    Invoke-PSDeploy -Path "$Scripts\deploy.ps1" -DeploymentRoot $ProjectRoot
  }

  "test" {
    Write-Output "Starting test"

    Write-Output "  Install Dependent Modules"
    Install-Module Pester, PSScriptAnalyzer -Scope CurrentUser

    Write-Output "  Import Dependent Modules"
    Import-Module Pester, PSScriptAnalyzer -ErrorAction SilentlyContinue

    if (!$Interactive) {
      # Setted for CI/CD pipeline
      & "$Scripts\test.ps1" -CodeToTest 'build' -TestType 'Full' -Tags $Script:Tags -OutPath $Script:TestOutPath
    }
    else {
      & "$Scripts\test.ps1"
    }
    if ($LASTEXITCODE -eq 0) {
      exit 0
    }
    else {
      exit 1
    }
  }
  Default {
    & "$Scripts\test.ps1" -CodeToTest "source" -TestType "unit" -Tags @()
  }
}

