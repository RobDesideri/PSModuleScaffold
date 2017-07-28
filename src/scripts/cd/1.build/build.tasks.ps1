#Requires -Module InvokeBuild
requires BuildRoot, Files, Dirs, Config

<#
.SYNOPSIS
  InvokeBuild bundling tasks.
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

#---------------------------------------------[Tasks]---------------------------------------------#

Task Build CleanBuild, CopyStaticSrcToBuild, BundlePSM1Module, CreatePSD1Manifest

Task CleanBuild {
  $dir = $Dirs.Build
  Write-Verbose " Removing $dir directory..."
  $null = Remove-Item $dir -Recurse -ErrorAction Ignore
  $null = New-Item  -Type Directory -Path $dir
}

Task CopyStaticSrcToBuild {
  $buildsDir = $Dirs.Builds
  Write-Verbose " Create '$buildsDir' directory..."
  New-Item -Type Directory -Path $buildsDir -ErrorAction Ignore | Out-Null
  Write-Verbose " Copy assets into '$buildsDir' directory..."
  Get-ChildItem $Dirs.Src -Directory | 
    Where-Object name -In $CdBuildCfg.SrcDirsToCopy | 
    Copy-Item -Destination $buildsDir -Recurse -Force -PassThru | 
    ForEach-Object { 
      Write-Verbose $(" Create [.{0}]" -f $_.fullname.replace($Dirs.ProjectRoot, ''))
    }
}

Task BundlePSM1Module {
  [System.Text.StringBuilder]$stringBuilder = [System.Text.StringBuilder]::new()    
  foreach ($folder in $CdBuildCfg.SrcDirsToBoundle ) {
    [void]$stringBuilder.AppendLine( "<# `n # $($Config.ModuleName) module`n#>" )
    if (Test-Path "$src\$folder") {
      $fileList = Get-ChildItem "$src\$folder\*.ps1"
      foreach ($file in $fileList) {
        $shortName = $file.fullname.replace($BuildRoot, '')
        Write-Verbose " Importing '.$shortName' file..."
        [void]$stringBuilder.AppendLine( "# Source file:  $shortName" ) 
        [void]$stringBuilder.AppendLine( [System.IO.File]::ReadAllText($file.fullname) )
      }
    }
  }
  Write-Verbose "  Creating module '$buildModule'"
  Set-Content -Path $buildModule -Value $stringBuilder.ToString() 
} `
-Partial `
-Inputs (Get-Item "$($Dirs.Src)\*\*.ps1") `
-Outputs $Files.BuildModule

Task CreatePSD1Manifest {
  $srcManifest = $Files.SrcManifestFile 
  $buildManifest = $Files.BuildManifestFile 
  Write-Verbose "  Update '$buildManifest'"
  Copy-Item $srcManifest $buildManifest -ErrorAction SilentlyContinue
  Set-ModuleFunctions -Name $buildManifest -FunctionsToExport $($GetPublicFunctionsNames.Invoke())
} `
  -Partial `
  -Inputs (Get-ChildItem $Dirs.src -Recurse -File) `
  -Outputs $Files.BuildManifestFile