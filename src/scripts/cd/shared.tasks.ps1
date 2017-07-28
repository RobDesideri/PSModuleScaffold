#Requires -Module InvokeBuild
requires Dirs

<#
.SYNOPSIS
  Shared resources for InvokeBuild tasks.
.DESCRIPTION
  Release scripts dot-source this script in order to share these resources in all other tasks.
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

#---------------------------------------[SharedScriptBlocks]--------------------------------------#

$script:GetPublicFunctionsNames = {
  $functions = Get-ChildItem "$($Dirs.Public)\*.ps1" | 
    Select-Object -ExpandProperty basename
  return $functions
}