<#
.SYNOPSIS
  Set the global variable '__' containing all project configuration settings.
.DESCRIPTION
  This script MUST be called from any other script that require project configuration. It build a 
  global variable, named __ containing all configurations settings, subdivided into:
  - [string]ModuleName
  - [hashtable]Paths
  - [hashtable]File
  - [array]DirsToCompile
  - [array]DirsToCopy
  - [hashtable]VendorFolder
.EXAMPLE
  PS C:\> .\config.ps1
  Load the __ object into current PS session.
.INPUTS
  None.
.OUTPUTS
  None.
.NOTES
  None.
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