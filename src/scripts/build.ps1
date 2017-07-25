### =============================================================================
### Script scoped variables
### =============================================================================

# InvokeBuild BuidRoot variable
$BuildRoot = $Global:__.ProjectRoot

# Dirs paths
$script:ModuleName = $Global:__.ModuleName
$script:Source = $Global:__.SrcFolder
$script:Lib = $Global:__.LibFolder.SrcFolder
$script:Output = $Global:__.OutputFolder
$script:Scripts = $Global:__.ScriptsFolder
$script:Build = $Global:__.BuildFolder

# Files path
$script:ModulePath = "$Build\$ModuleName.psm1"
$script:ManifestPath = "$Build\$ModuleName.psd1"

# Dirs to compile
$script:DirsToCompile = $Global:__.DirsToCompile

# Timestamp at begin of the process
$script:TimeStamp = $(((get-date).ToUniversalTime()).ToString("yyyyMMddThhmmssZ")).ToString()

### =============================================================================
### Helpers functions
### =============================================================================
function TestCallGenerator ($code, $test) {

    $generateTestFileName = {
        return "$Output\$($test)TestResults_PS$PSVersion`_$TimeStamp.xml"
    }

    $options = @{
        PassThru = $true
    }

    if ($code -eq "build") {
        $options.Add("NoReloadModule", $true)
    }

    $testsScript = "$Scripts\module.tests.ps1"

    $TestResults = & $testsScript -CodeToTest "$code" -TestType "$test" -OutFile (& $generateTestFileName) @options
    if ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed [$($r.FailedCount)] Pester tests"
    }
}

### =============================================================================
### InvokeBuild Tasks
### =============================================================================

Task Default Require, Build, Tests, UpdateSource, Publish
Task Build CopyToOutput, BuildPSM1, BuildPSD1
Task Tests UnitTests, HelpTests, Build, ImportModule, ProjectTests, AcceptanceTests

Task Require {
    Invoke-PSDepend -Path $Source\package.psd1 -Install -Force
}

Task Clean {
    $null = Remove-Item $Output -Recurse -ErrorAction Ignore
    $null = New-Item  -Type Directory -Path $Build
}

Task StaticTests {
    TestCallGenerator "build" "static"
}

Task UnitTests {
    TestCallGenerator "source" "unit"
}

Task HelpTests {
    TestCallGenerator "source" "help"
}

Task ProjectTests {
    $TestResults = .$Global:PRJ\scripts\module.tests.ps1 -CodeToTest "source" -TestType "project" -OutFile $script:ProjectTestFile -PassThru -NoReloadModule
    if ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed [$($r.FailedCount)] Pester tests"
    }
}

Task AcceptanceTests {
    $TestResults = .$Global:PRJ\scripts\module.tests.ps1 -CodeToTest "build" -TestType "spec" -OutFile $script:AcceptanceTestFile -PassThru -Tags Build -NoReloadModule
    foreach ($r in $TestResults) {
        if ($r.FailedCount -gt 0) {
            Write-Error "Failed [$($r.FailedCount)] Pester tests"
        }
    }
}

Task CopyToOutput {

    Write-Output "  Create Directory [$Build]"
    $null = New-Item -Type Directory -Path $Build -ErrorAction Ignore

    Get-ChildItem $source -File | 
        Where-Object name -NotMatch "$ModuleName\.ps[dm]1" | 
        Copy-Item -Destination $Build -Force -PassThru | 
        ForEach-Object { "  Create [.{0}]" -f $_.fullname.replace($PSScriptRoot, '')}

    Get-ChildItem $source -Directory | 
        Where-Object name -NotIn $DirsToCompile | 
        Copy-Item -Destination $Build -Recurse -Force -PassThru | 
        ForEach-Object { "  Create [.{0}]" -f $_.fullname.replace($PSScriptRoot, '')}
}

Task BuildPSM1 -Inputs (Get-Item "$source\*\*.ps1") -Outputs $ModulePath {

    [System.Text.StringBuilder]$stringbuilder = [System.Text.StringBuilder]::new()    
    foreach ($folder in $DirsToCompile ) {
        [void]$stringbuilder.AppendLine( "Write-Verbose 'Importing from [$Source\$folder]'" )
        if (Test-Path "$source\$folder") {
            $fileList = Get-ChildItem "$source\$folder\*.ps1" | Where-Object Name -NotLike '*.Tests.ps1'
            foreach ($file in $fileList) {
                $shortName = $file.fullname.replace($PSScriptRoot, '')
                Write-Output "  Importing [.$shortName]"
                [void]$stringbuilder.AppendLine( "# .$shortName" ) 
                [void]$stringbuilder.AppendLine( [System.IO.File]::ReadAllText($file.fullname) )
            }
        }
    }
    
    Write-Output "  Creating module [$ModulePath]"
    Set-Content -Path  $ModulePath -Value $stringbuilder.ToString() 
}

Task NextPSGalleryVersion -if (-Not ( Test-Path "$output\version.xml" ) ) -Before BuildPSD1 {
    $galleryVersion = Get-NextPSGalleryVersion -Name $ModuleName
    $galleryVersion | Export-Clixml -Path "$output\version.xml"
}

Task BuildPSD1 -inputs (Get-ChildItem $Source -Recurse -File) -Outputs $ManifestPath {
   
    Write-Output "  Update [$ManifestPath]"
    Copy-Item "$source\$ModuleName.psd1" -Destination $ManifestPath

    $Script:BumpVersionType = 'Patch'

    $functions = Get-ChildItem "$ModuleName\Public\*.ps1" | Where-Object { $_.name -notmatch 'Tests'} | Select-Object -ExpandProperty basename      

    $oldFunctions = (Get-Metadata -Path $manifestPath -PropertyName 'FunctionsToExport')

    $functions | Where-Object {$_ -notin $oldFunctions } | ForEach-Object {$Script:BumpVersionType = 'Minor'}
    $oldFunctions | Where-Object {$_ -notin $Functions } | ForEach-Object {$Script:BumpVersionType = 'Major'}

    Set-ModuleFunctions -Name $ManifestPath -FunctionsToExport $functions

    # Bump the module version
    $version = [version] (Get-Metadata -Path $manifestPath -PropertyName 'ModuleVersion')
    $galleryVersion = Import-Clixml -Path "$output\version.xml"
    if ( $version -lt $galleryVersion ) {
        $version = $galleryVersion
    }
    Write-Output "  Stepping [$Script:BumpVersionType] version [$version]"
    $version = [version] (Step-Version $version -Type $Script:BumpVersionType)
    Write-Output "  Using version: $version"
    
    Update-Metadata -Path $ManifestPath -PropertyName ModuleVersion -Value $version
}

Task UpdateSource {
    Copy-Item $ManifestPath -Destination "$source\$ModuleName.psd1"
}

Task ImportModule {
    if ( -Not ( Test-Path $ManifestPath ) ) {
        Write-Output "  Modue [$ModuleName] is not built, cannot find [$ManifestPath]"
        Write-Error "Could not find module manifest [$ManifestPath]. You may need to build the module first"
    }
    else {
        if (Get-Module $ModuleName) {
            Write-Output "  Unloading Module [$ModuleName] from previous import"
            Remove-Module $ModuleName
        }
        Write-Output "  Importing Module [$ModuleName] from [$ManifestPath]"
        Import-Module $ManifestPath -Force
    }
}

Task Publish {
    # Gate deployment
    if (
        $ENV:BHBuildSystem -ne 'Unknown' -and 
        $ENV:BHBranchName -eq "master" -and 
        $ENV:BHCommitMessage -match '!deploy'
    ) {
        $Params = @{
            Path  = $BuildRoot
            Force = $true
        }

        Invoke-PSDeploy @Verbose @Params
    }
    else {
        "Skipping deployment: To deploy, ensure that...`n" + 
        "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" + 
        "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" + 
        "`t* Your commit message includes !deploy (Current: $ENV:BHCommitMessage)"
    }
}
