#Requires -Module powershell-yaml

<#
.SYNOPSIS
  Retrieve configurations from config.yml file and fill shared variables for scripts.
.DESCRIPTION
  Retrieve configurations from config.yml file and create at least 6 script-scoped variable:
    - Dirs        > directories absolute* paths**
    - Files       > files absolute* paths
    - CdBuildCfg  > configuration for build process
    - CdTestCfg   > configuration for test process
    - CdDeployCfg > configuration for deploy process
    - Config      > all configurations*** as hashtable object

  If CdCfg contains others automation process, it create also these variables as:
      'Cd' + $ProcessName + 'Cfg'

  * Files and Dirs values are rewritted as absolute path before insert in variables.
  ** A ProjectRoot key is automatically added to Dirs paths
  *** Paths in main Config variables are not rewrittes, so they are relative path.
  
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

#-----------------------------------------[LocalHelpers]------------------------------------------#

function _GetPath ($RelPath) {
  return $(Join-Path $PSScriptRoot $RelPath)
}

#----------------------------------------[PrivateVariables]---------------------------------------#

$_config = ConvertFrom-Yaml $(Get-Content "$PSScriptRoot\config.yml" -Raw)

$_files = @{}
foreach ($fileKey in $_config.Files.Keys) {
  $_files.Add($fileKey, $(_GetPath $_config.Files[$fileKey]))
}

$_dirs = @{}
foreach ($dirKey in $_config.Dirs.Keys) {
  $_dirs.Add($dirKey, $(_GetPath $_config.Dirs[$dirKey]))
}
$_dirs.Add('ProjectRoot', $PSScriptRoot)

#----------------------------------------[SharedVariables]----------------------------------------#

# Config
Set-Variable -Name Config -Scope Script -Option ReadOnly -Value $_config -Force

# Files
Set-Variable -Name Files -Scope Script -Option ReadOnly -Value $_files -Force

# Dirs
Set-Variable -Name Dirs -Scope Script -Option ReadOnly -Value $_dirs -Force

# CdBuildCfg, CdTestCfg, CdDeployCfg, ...
foreach ($cKey in $_config.CdCfg) {
  $val = $_config.CdCfg[$cKey]
  Set-Variable -Name "Cd$($cKey)Cfg" -Scope Script -Option ReadOnly -Value $val -Force
}