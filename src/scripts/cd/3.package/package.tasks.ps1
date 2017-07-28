#Requires -Module InvokeBuild, BuildHelpers
requires Files, Dirs, Config, GetPublicFunctionsNames

<#
.SYNOPSIS
  InvokeBuild versioning tasks.
.DESCRIPTION
  Build scripts dot-source this script in order to use the task "create".
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

#-----------------------------------------[LocalHelpers]------------------------------------------#

Task Package UpdateVersion

Task UpdateVersion `
  SetNewVersion `
  UpdateVersionInManifest, `
  UpdateVersionInSrcManifest, `
  CreateGitTag


Task SetNewVersion {
  $buildManifest = $Files.BuildManifestFile
  # Get step version type
  $bumpVersionType = 'Build'
  $functions = $GetPublicFunctionsNames.Invoke()
  $oldFunctions = (Get-Metadata -Path $buildManifest -PropertyName 'FunctionsToExport')
  foreach ($f in $functions) {
    if ($oldFunctions -notcontains $f) {
      $bumpVersionType = 'Minor'
      break
    }
  }
  foreach ($f in $oldFunctions) {
    if ($functions -notcontains $f) {
      $bumpVersionType = 'Major'
      break
    }
  }
  New-Object -TypeName 
  # Get latest version
  $latestVersion = [version] (Get-Metadata -Path $buildManifest -PropertyName 'ModuleVersion')
  $galleryVersion = Get-NextNugetPackageVersion -Name $Config.ModuleName
  if ( $latestVersion -lt $galleryVersion ) {
    $latestVersion = $galleryVersion
  }
  # Set NewVersion variable
  Write-Verbose "  Stepping [$bumpVersionType] version [$latestVersion]"
  $script:NewVersion = [version] (Step-Version $latestVersion -Type $bumpVersionType)
}

Task UpdateVersionInManifest {
  $buildManifest = $Files.BuildManifestFile
  Write-Verbose "  Updating $buildManifest to $NewVersion version"
  Update-Metadata -Path $buildManifest -PropertyName ModuleVersion -Value $NewVersion
}

Task UpdateVersionInSrcManifest {
  Copy-Item $Files.BuildManifest $Files.SrcManifest -Force
}

Task CreateGitTag {
  $originalLocation = Get-Location
  Set-Location $Dirs.ProjecRoot
  & git tag -a $($script:NewVersion.ToString())
  Set-Location $originalLocation
}