<#
.SYNOPSIS
  Get the contents of the build folder and publish it to the PSGallery.
  This script should not be invoked directly.
  It is called from the automation.ps1 script
.NOTES
  Require:
  - PSDeploy module
  - BuildHelpers module
    - Set-BuildEnvironment already invoked in project root path
  - The __ global variable
  - The ENV:NugetApiKey variable setted
#>

param(
  # Script is executed only if this switch is enabled.
  # This, to avoid it is called directly, without automation.ps1 intermediation.
  [Parameter(Mandatory = $false)]
  [switch]
  $CheckSwitch
)

if (!$CheckSwitch) {
  throw "build.ps1 script can't be called directly. Use the automation.ps1 script instead."
}

### =============================================================================
### Script variables init
### =============================================================================
$Script:Build = $Global:__.Paths.Dir.Build

### =============================================================================
### Deploy Script
### =============================================================================

if (
  $ENV:BHBuildSystem -ne 'Unknown' -and 
  $ENV:BHBranchName -eq "master" -and 
  $ENV:BHCommitMessage -match '!deploy'
) {
  Deploy Module {
    By PSGalleryModule {
      FromSource $Script:Build
      To PSGallery
      WithOptions @{
        ApiKey = $ENV:NugetApiKey
      }
    }
  }
}
else {
  "Skipping deployment: To deploy, ensure that...`n" + 
  "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" + 
  "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" + 
  "`t* Your commit message includes !deploy (Current: $ENV:BHCommitMessage)"
}
