param(
    # Code to test (source|build|deployed)
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]
    $CodeToTest,

    # TestType
    [Parameter(Mandatory = $true,
        Position = 1,
        HelpMessage = '(full|spec|help|project|regression|unit)')]
    [AllowEmptyString()]
    [string]
    $TestType,

    # Tags
    [Parameter(Mandatory = $false)]
    [AllowEmptyCollection()]
    [string[]]
    $Tags,

    # Output file
    [Parameter(Mandatory = $false)]
    [string[]]
    $OutFile,

    # PassThru
    [Parameter(Mandatory = $false)]
    [switch]
    $PassThru,

    # No reload the module, is already loaded
    [Parameter(Mandatory = $false)]
    [switch]
    $NoReloadModule
)

# Local vars
$ProjectRoot = $Global:__.Paths.ProjectRoot
$ModuleName = $Global:__.ModuleName
$SrcModulePath = $Global:__.Paths.SrcFolder
$BuildModulePath = $Global:__.Paths.BuildFolder

# Parameters handling
if ($TestType -eq "full") {
    if ($OutFile) {
        if ($OutFile -isnot [array]) {
            throw "In case of full test, the OutFile prameter must be an array of 2 files, one for Pester, one for Gherkin"
        }
    }
    if ($PassThru) {
        Write-Verbose "In case of full test, the PassThru object will be an array of 2 objects, one for Pester, one for Gherkin"
    }
}

if (($CodeToTest -eq "deployed") -and ($CodeType -eq "static")) {
    throw "In case of static test, you cannot use the 'deployed' as code to test."
}

# Default parameter settings
if ($CodeToTest -eq "") {
    $CodeToTest = "source"
}
if ($TestType -eq "") {
    $TestType = "spec"
}

# Switch for code to test
if (!$NoReloadModule) {
    Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
    switch ($CodeToTest) {
        "source" {
            $Script:TargetPath = "$SrcModulePath\$ModuleName.psd1"
        }
        "build" {
            $Script:TargetPath = $BuildModulePath
        }
        "deployed" {
            $Script:TargetPath = $ModuleName
            Install-Module $Script:TargetPath -Scope CurrentUser
        }
        Default {
            $Script:TargetPath = $SrcModulePath
        }
    }
    Import-Module $Script:TargetPath
}

# Options for all case
$opts = @{
    ExcludeTag = 'Slow'
    PassThru   = $true
}

# Options for tags
if ($Tags.Count -gt 0) {
    $opts.Add('Tag', $Tags)
}

# Options for full test
if ($TestType -eq "full") {

    $optionsForPester = $opts.Clone()
    $optionsForGherkin = $opts.Clone()

    if ($OutFile) {
        # Options for out files
        $optionsForPester.Add('OutputFormat', 'NUnitXml')
        $optionsForPester.Add('OutputFile', $OutFile[0])
        $optionsForGherkin.Add('OutputFormat', 'NUnitXml')
        $optionsForGherkin.Add('OutputFile', $OutFile[1])
    }

}
else {

    $options = $opts

    # Options for out files
    if ($OutFile) {
        $options.Add('OutputFormat', 'NUnitXml')
        $options.Add('OutputFile', $OutFile[0])
    }
}



# Switch for test type
switch ($TestType) {
    "full" { 
        $testResultsPester = Invoke-Pester -Path "$ProjectRoot\tests\*tests*" @optionsForPester
        $testResultsGherkin = Invoke-Gherkin "$ProjectRoot\tests\spec" @optionsForGherkin
        $TestResults = $testResultsPester, $testResultsGherkin
    }
    "spec" {
        $TestResults = Invoke-Gherkin "$ProjectRoot\tests\spec" @options
    }
    "static" {
        $TestResults = Invoke-Pester -Script @{
            Path       = "$ProjectRoot\tests\*static*"
            Parameters = {
                Path = $Script:TargetPath
            }
        } @options
    }
    "" {
        $TestResults = Invoke-Pester -Path "$ProjectRoot\tests\*unit*" @options
    }
    Default {
        $TestResults = Invoke-Pester -Path "$ProjectRoot\tests\*$TestType*" @options
    }
}

if ($TestResults.FailedCount -gt 0) {
    Write-Error "Failed [$($TestResults.FailedCount)] tests"
}

if ($PassThru) {
    return $TestResults
}