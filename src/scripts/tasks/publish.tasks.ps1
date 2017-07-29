#Requires -Module InvokeBuild, BuildHelpers, PSDeploy
requires Dirs
requires -Environment BHBuildSystem, BHBranchName, BHCommitMessage, NugetApiKey

<#
.SYNOPSIS
  InvokeBuild publishing tasks.
.DESCRIPTION
  Build scripts dot-source this script in order to use the task "publish".
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

#---------------------------------------------[Tasks]---------------------------------------------#

Task PublishOnPSGallery {
  Invoke-PSDeploy -DeploymentRoot $Dirs.ProjectRoot -Tags PSGallery -Recurse -Force
  # TODO: Create psdeploy script.
}

