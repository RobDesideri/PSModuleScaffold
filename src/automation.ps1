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

### =============================================================================
### Private functions
### =============================================================================
function Load__ () {
  <#
.SYNOPSIS
  Set the global variable '__' containing all project configuration settings.
.DESCRIPTION
  It build a global variable, named __ containing all configurations settings, divided into:
  - [string]ModuleName
  - [hashtable]Paths
  - [hashtable]File
  - [array]DirsToCompile
  - [array]DirsToCopy
  - [hashtable]VendorFolder
.EXAMPLE
  Load__
  Load the __ object into current PS session.
#>

  # Remove __ variable if already present
  Remove-Variable -Name __ -Scope Global -Force -ErrorAction SilentlyContinue

  # Adding the configurations...
  $tmp__ = @{}

  #   > Module Name
  $tmp__.Add("ModuleName", '<%= $PLASTER_PARAM_ModuleName %>')

  #   > Paths
  $tmp__.Add("Paths", @{})
  $tmp__.Paths.Add("Dir", @{})
  $tmp__.Paths.Add("File", @{})
  $tmp__.Paths.Dir.Add("ProjectRoot", "$PSScriptRoot")
  $tmp__.Paths.Dir.Add("Src", (Join-Path $tmp__.Paths.Dir.ProjectRoot "src"))
  $tmp__.Paths.Dir.Add("Output", (Join-Path $tmp__.Paths.Dir.ProjectRoot "out"))
  $tmp__.Paths.Dir.Add("Docs", (Join-Path $tmp__.Paths.Dir.ProjectRoot "docs"))
  $tmp__.Paths.Dir.Add("Test", (Join-Path $tmp__.Paths.Dir.ProjectRoot "test"))
  $tmp__.Paths.Dir.Add("Scripts", (Join-Path $tmp__.Paths.Dir.ProjectRoot "scripts"))
  $tmp__.Paths.Dir.Add("Build", (Join-Path $tmp__.Paths.Dir.Output $tmp__.ModuleName))
  $tmp__.Paths.Dir.Add("Vendor", (Join-Path $tmp__.Paths.Dir.Src $tmp__.ModuleName))
  $tmp__.Paths.File.Add("SrcDeps", (Join-Path $tmp__.Paths.Dir.Src '\deps.psd1'))
  $tmp__.Paths.File.Add("SrcModule", (Join-Path $tmp__.Paths.Dir.Src $($tmp__.ModuleName + '.psd1')))
  $tmp__.Paths.File.Add("SrcManifest", (Join-Path $tmp__.Paths.Dir.Src $($tmp__.ModuleName + '.psm1')))
  $tmp__.Paths.File.Add("BuildModule", (Join-Path $tmp__.Paths.Dir.Build $($tmp__.ModuleName + '.psd1')))
  $tmp__.Paths.File.Add("BuildManifest", (Join-Path $tmp__.Paths.Dir.Build $($tmp__.ModuleName + '.psm1')))
  $tmp__.Paths.File.Add("BuildVersion", (Join-Path $tmp__.Paths.Dir.Build $('version' + '.xml')))

  #   > SrcDirsToCompile
  $tmp__.Add("SrcDirsToCompile", @( 'private', 'public', 'class' ))

  #   > SrcDirsToCopy
  $tmp__.Add("SrcDirsToCopy", @( 'data', 'vendor' ))

  Set-Variable -Name __ -Description "Global variables for share data in project script." -Value ($tmp__.Clone()) -Option ReadOnly -Scope Global -Force
}

### =============================================================================
### Variables Init
### =============================================================================
# Load configuration object
Load__
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

