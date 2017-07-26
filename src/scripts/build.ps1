<#
.SYNOPSIS
  Retrieve the source code in src folder and build a well formed PS Module directory.
  This script should not be invoked directly.
  It is called from the automation.ps1 script
.NOTES
  Require:
  - InvokeBuild module
  - BuildHelpers module
    - Set-BuildEnvironment already invoked in project root path
  - PSDepend module
  - The __ global variable
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

$Script:ModuleName = $Global:__.ModuleName
$Script:Source = $Global:__.Paths.Dir.Src
$Script:Output = $Global:__.Paths.Dir.Output
$Script:Scripts = $Global:__.Paths.Dir.Scripts
$Script:Build = $Global:__.Paths.Dir.Build
$Script:ModulePath = $Global:__.Paths.File.SrcModule
$script:ManifestPath = $Global:__.Paths.File.SrcManifest
$Script:DirsToCompile = $Global:__.SrcDirsToCompile
$Script:DirsToCopy = $Global:__.SrcDirsToCopy
$Script:Deps = $Global:__.Paths.File.SrcDeps
$Script:Version = $Global:__.Paths.File.BuildVersion

### =============================================================================
### InvokeBuild Tasks
### =============================================================================

Task Default Require, Clean, CopyToOutput, BuildPSM1, BuildPSD1, UpdateSource

Task Require {
    Invoke-PSDepend -Path $Script:Deps -Install -Force
}

Task Clean {
    Remove-Item $Script:Build -Recurse -ErrorAction Ignore | Out-Null
    New-Item  -Type Directory -Path $Script:Build | Out-Null
}

Task CopyToOutput {
    Write-Output "  Create Directory [$Script:Build]"
    New-Item -Type Directory -Path $Script:Build -ErrorAction Ignore |Out-Null

    Get-ChildItem $Script:Source -Directory | 
        Where-Object name -In $Script:DirsToCopy | 
        Copy-Item -Destination $Script:Build -Recurse -Force -PassThru | 
        ForEach-Object { "  Create [.{0}]" -f $_.fullname.replace($PSScriptRoot, '')}
}

Task BuildPSM1 -Inputs (Get-Item "$Script:Source\*\*.ps1") -Outputs $Script:ModulePath {
    [System.Text.StringBuilder]$stringbuilder = [System.Text.StringBuilder]::new()    
    foreach ($folder in $Script:DirsToCompile ) {
        [void]$stringbuilder.AppendLine( "Write-Verbose 'Importing from [$Script:Source\$folder]'" )
        if (Test-Path "$Script:Source\$folder") {
            $fileList = Get-ChildItem "$Script:Source\$folder\*.ps1" | Where-Object Name -NotLike '*.Tests.ps1'
            foreach ($file in $fileList) {
                $shortName = $file.fullname.replace($PSScriptRoot, '')
                Write-Output "  Importing [.$shortName]"
                [void]$stringbuilder.AppendLine( "# .$shortName" ) 
                [void]$stringbuilder.AppendLine( [System.IO.File]::ReadAllText($file.fullname) )
            }
        }
    }
    Write-Output "  Creating module [$Script:ModulePath]"
    Set-Content -Path  $Script:ModulePath -Value $stringbuilder.ToString() 
}

Task NextPSGalleryVersion -if (-Not ( Test-Path $Script:Version ) ) -Before BuildPSD1 {
    $galleryVersion = Get-NextPSGalleryVersion -Name $Script:ModuleName
    $galleryVersion | Export-Clixml -Path "$Script:Output\version.xml"
}

Task BuildPSD1 -inputs (Get-ChildItem $Script:Source -Recurse -File) -Outputs $Script:ManifestPath {
   
    Write-Output "  Update [$Script:ManifestPath]"
    Copy-Item "$Script:Source\$Script:ModuleName.psd1" -Destination $Script:ManifestPath

    $Script:BumpVersionType = 'Patch'

    $functions = Get-ChildItem "$Script:ModuleName\Public\*.ps1" | Where-Object { $_.name -notmatch 'Tests'} | Select-Object -ExpandProperty basename      

    $oldFunctions = (Get-Metadata -Path $Script:ManifestPath -PropertyName 'FunctionsToExport')

    $functions | Where-Object {$_ -notin $oldFunctions } | ForEach-Object {$Script:BumpVersionType = 'Minor'}
    $oldFunctions | Where-Object {$_ -notin $Functions } | ForEach-Object {$Script:BumpVersionType = 'Major'}

    Set-ModuleFunctions -Name $Script:ManifestPath -FunctionsToExport $functions

    # Bump the module version
    $version = [version] (Get-Metadata -Path $Script:ManifestPath -PropertyName 'ModuleVersion')
    $galleryVersion = Import-Clixml -Path "$Script:Output\version.xml"
    if ( $version -lt $galleryVersion ) {
        $version = $galleryVersion
    }
    Write-Output "  Stepping [$Script:BumpVersionType] version [$version]"
    $version = [version] (Step-Version $version -Type $Script:BumpVersionType)
    Write-Output "  Using version: $version"
    
    Update-Metadata -Path $Script:ManifestPath -PropertyName ModuleVersion -Value $version
}

Task UpdateSource {
    Copy-Item $Script:ManifestPath -Destination "$Script:Source\$Script:ModuleName.psd1"
}