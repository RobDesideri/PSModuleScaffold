#Requires -Module PSDeploy

<#
.SYNOPSIS
  PSDeploy deploy script.
.DESCRIPTION
  Pass this script as parameter to Invoke-PSDepend to deploy module to PowerShellGallery.
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

Deploy Module {
  By PSGalleryModule {
    FromSource $ENV:BHBuildOutput
    To PSGallery
    WithOptions @{
      ApiKey = $ENV:NugetApiKey
    }
    Tagged PSGallery
  }
}