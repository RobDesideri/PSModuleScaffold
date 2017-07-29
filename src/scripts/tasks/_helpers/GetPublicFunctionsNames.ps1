<#
.SYNOPSIS
  Return an array of public functions founded in the src/public path.
.DESCRIPTION
  Dot-source this script in order to share this blockscript in all other tasks.
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

$script:GetPublicFunctionsNames = {
  $functions = Get-ChildItem "$($Dirs.Public)\*.ps1" | 
    Select-Object -ExpandProperty basename
  return $functions
}