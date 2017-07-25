### =============================================================================
### Script scoped variables
### =============================================================================

# InvokeBuild BuidRoot variable
$BuildRoot = $Global:__.ProjectRoot

# Dirs paths
$Script:ModuleName = $Global:__.ModuleName
$Script:Source = $Global:__.SrcFolder
$Script:Lib = $Global:__.LibFolder.SrcFolder
$Script:Output = $Global:__.OutputFolder
$Script:Scripts = $Global:__.ScriptsFolder
$Script:Build = $Global:__.BuildFolder

# Files path
$Script:ModulePath = "$Script:Build\$Script:ModuleName.psm1"
$script:ManifestPath = "$Script:Build\$Script:ModuleName.psd1"

# Dirs to compile
$Script:DirsToCompile = $Global:__.DirsToCompile

### =============================================================================
### InvokeBuild Tasks
### =============================================================================

Task Default Require, Clean, CopyToOutput, BuildPSM1, BuildPSD1, UpdateSource

Task Require {
    Invoke-PSDepend -Path $Script:Source\package.psd1 -Install -Force
}

Task Clean {
    $null = Remove-Item $Script:Output -Recurse -ErrorAction Ignore
    $null = New-Item  -Type Directory -Path $Script:Build
}

Task CopyToOutput {

    Write-Output "  Create Directory [$Script:Build]"
    $null = New-Item -Type Directory -Path $Script:Build -ErrorAction Ignore

    Get-ChildItem $Script:Source -File | 
        Where-Object name -NotMatch "$Script:ModuleName\.ps[dm]1" | 
        Copy-Item -Destination $Script:Build -Force -PassThru | 
        ForEach-Object { "  Create [.{0}]" -f $_.fullname.replace($PSScriptRoot, '')}

    Get-ChildItem $Script:Source -Directory | 
        Where-Object name -NotIn $Script:DirsToCompile | 
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

Task NextPSGalleryVersion -if (-Not ( Test-Path "$Script:Output\version.xml" ) ) -Before BuildPSD1 {
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