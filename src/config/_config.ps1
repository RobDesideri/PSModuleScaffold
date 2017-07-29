#Requires -Module powershell-yaml

<#
.SYNOPSIS
  Retrieve configurations from config.yml file and fill shared variables for scripts.
.DESCRIPTION
  This script can be 'dot-sourced' by another script stored in project root.
  So all config variables are automatically available into your session.
  
  If you would use it by invocation, enable the $PassThrough switch and pass it the $ProjectRoot path.

  The script retrieve configurations from config.yml file and create at least 6 script-scoped
  variable:
    - Dirs        > directories absolute* paths**
    - Files       > files absolute* paths
    - CdBuildCfg  > configuration for build process
    - CdTestCfg   > configuration for test process
    - CdDeployCfg > configuration for deploy process
    - Config      > all configurations*** as hashtable object
    - Deps        > dependencies****

  If CdCfg contains others automation process, it create also these variables as:
      'Cd' + $ProcessName + 'Cfg'

  * Files and Dirs values are rewritted as absolute path before insert in variables.
  ** A ProjectRoot key is automatically added to Dirs paths
  *** Paths in main Config variables are not rewrittes, so they are relative path.
  **** Dependencies are in PSDepend object style. The 'Target' key can contains placeholder as path.
      See deps.yml for informations.
  
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

#------------------------------------------[Parameters]-------------------------------------------#
param(
  # ProjectRoot
  [Parameter(Mandatory = $false,
    Position = 0,
    HelpMessage = 'Path to project root.')]
  [string]
  $ProjectRoot,

  # $PassThrough switch
  [Parameter(Mandatory = $false,
    HelpMessage = 'Return an array of builded configuration variables.')]
  [switch]
  $PassThrough
)

#-------------------------------------------[Functions]-------------------------------------------#

function _GetPath ($RelPath) {
  return $(Join-Path $script:ProjectRoot $RelPath)
}

function _ReplacePlaceholder ($Hashtable) {
  function getPrivateVar ($PublicVarName) {
    return '_' + $PublicVarName.ToLower()
  }
  function getVar ($MatchedVarName) {
    $varName = $MatchedVarName -replace '^\<\% ', ''
    $varName = $varName -replace ' \%\>$', ''
    $varName = $varName -replace '^\$', ''
    if ($varName -match '\.') {
      $hashPath = $varName.Split('.')
      $var = Get-Variable -Name $(getPrivateVar $hashPath[0]) -ValueOnly
      for ($i = 1; $i -lt $hashPath.Count; $i++) {
        $var = $var.Item($hashPath[$i])
      }
    }
    else {
      $var = Get-Variable -Name $(getPrivateVar $varName) -ValueOnly
    }
    return $var
  }
  
  $clone = $Hashtable.Clone()

  foreach ($key in $clone.Keys) {
    $depsType = $clone[$key].Clone()
    foreach ($dtKey in $depsType.Keys) {
      $dep = $depsType[$dtKey].Clone()
      foreach ($depKey in $dep.Keys) {
        if ($depKey -eq 'Target') {
          $value = $dep[$depKey]
          if ($value -match '\<\% .*? \%\>') {
            foreach ($matchKey in $Matches.Keys) {
              $matchValue = $Matches[$matchKey]
              $Hashtable.$key.$dtKey.$depKey = $value.Replace($matchValue, $(getVar $matchValue))
            }
          }
        }
      }
    }
  }
  return $Hashtable
}

#---------------------------------------------[Begin]---------------------------------------------#

$ErrorActionPreference = 'Stop'

$OriginalLocation = Get-Location
Set-Location $PSScriptRoot

if (!$ProjectRoot) {
  $ProjectRoot = Split-Path $MyInvocation.ScriptName -Parent
}

# Deps
Write-Verbose " Installing Powershell-Yaml module..."
Install-Module -Name Powershell-Yaml -Scope CurrentUser
Import-Module Powershell-Yaml -ErrorAction SilentlyContinue

#--------------------------------------------[Process]--------------------------------------------#

# Build private variables

$_config = ConvertFrom-Yaml $(Get-Content .\config.yml -Raw)

$_files = @{}
foreach ($fileKey in $_config.Files.Keys) {
  $_files.Add($fileKey, $(_GetPath $_config.Files[$fileKey]))
}

$_dirs = @{}
foreach ($dirKey in $_config.Dirs.Keys) {
  $_dirs.Add($dirKey, $(_GetPath $_config.Dirs[$dirKey]))
}
$_dirs.Add('ProjectRoot', $ProjectRoot)

$_deps = ConvertFrom-Yaml $(Get-Content .\deps.yml -Raw)
$_deps = _ReplacePlaceholder $_deps

# Create the public shared variables

Set-Variable -Name Config -Option ReadOnly -Value $($_config.Clone()) -Force

Set-Variable -Name Files -Option ReadOnly -Value $($_files.Clone()) -Force

Set-Variable -Name Dirs -Option ReadOnly -Value $($_dirs.Clone()) -Force

foreach ($cKey in $_config.CdCfg.Keys) {
  $val = $_config.CdCfg[$cKey]
  if ($val) {
    Set-Variable -Name "Cd$($cKey)Cfg" -Option ReadOnly -Value $($val.Clone()) -Force
  } 
}

Set-Variable -Name Deps -Option ReadOnly -Value $($_deps.Clone()) -Force

#----------------------------------------------[End]----------------------------------------------#

# Remove private vars
Remove-Variable _config, _files, _dirs, _deps

# Return variables if $PassThrough enabled
if ($PassThrough) {
  Set-Location $OriginalLocation
  return $Config, $Files, $Dirs, $Deps
}
else {
  Set-Location $OriginalLocation
}