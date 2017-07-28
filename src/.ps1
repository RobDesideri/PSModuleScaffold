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

param(
  # TODO: parameters data
  $ProcessToStart,
  $Tags
)

#--------------------------------------------[Settings]--------------------------------------------#

$ErrorActionPreference = 'Stop'
$OriginalLocation = Get-Location
Set-Location $PSScriptRoot

#---------------------------------------------[Deps]----------------------------------------------#

Write-Verbose " Installing PSDepend module..."
Install-Module -Name PSDepend -Scope CurrentUser
Import-Module PSDepend -ErrorAction SilentlyContinue

Write-Verbose " Installing Powershell-Yaml module..."
Invoke-PSDepend -Install -Import -InputObject @{
  'powershell-yaml' = 'latest'
}

#----------------------------------------------[Deps]----------------------------------------------#

Install-Module powershell-yaml
Import-Module powershell-yaml -ErrorAction SilentlyContinue

#-----------------------------------------[Initialisation]-----------------------------------------#
$Config = ConvertFrom-Yaml -Yaml $(Get-Content -Path .\config.yml -Raw)
$Files = $Config.ProjectStructure.Files
$Dirs = $Config.ProjectStructure.Dirs

#----------------------------------------------[Main]----------------------------------------------#

switch -regex ($ProcessToStart) {
  'deploy' { 
    Write-Verbose " Installing all dependencies required from scripts..."
    Invoke-PSDepend -Path .\scripts -Recurse -Install -Import -Tags Deploy
    Write-Information "  Starting deploy process..."
    .\scripts\deploy.ps1
   }

   'build' {
    Write-Verbose " Installing all dependencies required from scripts..."
    Invoke-PSDepend -Path .\scripts -Recurse -Install -Import -Tags Build
    Write-Information "  Starting buld process..."
    .\scripts\build.ps1
   }

   '.*test$' { 
    Write-Verbose " Installing all dependencies required from scripts..."
    Invoke-PSDepend -Path .\scripts -Recurse -Install -Import -Tags Test
    Write-Information "  Starting test process..."
    $TestType = $ProcessToStart -replace 'test', ''
    .\scripts\test.ps1 $TestType $Tags
   }

  Default {
    Write-Information "  Starting buld process..."
  }
}
