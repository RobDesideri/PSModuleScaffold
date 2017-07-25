<#
.SYNOPSIS
  Test script for PowerShell modules.
.DESCRIPTION
  Execute selected tests present in test folder.
  This script should not be invoked directly.
  It is called from the console.ps1 script.
.INPUTS
  None.
.OUTPUTS
  If EnableLog is on, create one or more lo files containing the tests results.
.NOTES
  Require:
  - Pester module
  - The __ global variable
#>

param(
  # Code to test (source|build|deployed)
  [Parameter(Mandatory = $true,
  Position = 0,
  HelpMessage = '[source|build|deploy]')]
  [AllowEmptyString()]
  [string]
  $CodeToTest,

  # TestType
  [Parameter(Mandatory = $true,
    Position = 1,
    HelpMessage = '[full|spec|help|project|regression|unit]')]
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
  [switch]
  $EnableLog
)

### =============================================================================
### Script variables init
### =============================================================================
$ModuleName = $Global:__.ModuleName
$Src = $Global:__.Paths.Dir.Src
$Build = $Global:__.Paths.Dir.Build
$Test = $Global:__.Paths.Dir.Test
$TimeStamp = $(((get-date).ToUniversalTime()).ToString("yyyyMMddThhmmssZ")).ToString()

### =============================================================================
### Parameters handling
### =============================================================================
if ($EnableLog) {
  $OutFile = @("$OutPath\$($TestType)TestResults_PS$PSVersion`_$Script:TimeStamp.xml")
}
if ($TestType -eq "full") {
  if ($OutPath) {
    $OutFile += "$OutPath\AcceptanceTestResults_PS$PSVersion`_$Script:TimeStamp.xml"
  }
}

if (($CodeToTest -eq "deployed") -and ($CodeType -eq "static")) {
  throw "In case of static test, you cannot use the 'deployed' as code to test."
}

### =============================================================================
### Execution
### =============================================================================

# SUT selection
Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
switch ($CodeToTest) {
  "source" {
    $Script:TargetPath = "$Src\$ModuleName.psd1"
  }
  "build" {
    $Script:TargetPath = $Build
  }
  "deployed" {
    $Script:TargetPath = $ModuleName
    Install-Module $Script:TargetPath -Scope CurrentUser
  }
  Default {
    $Script:TargetPath = $Src
  }
}
Import-Module $Script:TargetPath

# Build options object
#   > common
$opts = @{
  ExcludeTag = 'Slow'
  PassThru   = $true
}
#   > for tag
if ($Tags.Count -gt 0) {
  $opts.Add('Tag', $Tags)
}
#   > for full test
if ($TestType -eq "full") {
  $optionsForPester = $opts.Clone()
  $optionsForGherkin = $opts.Clone()
  if ($OutFile) {
    $optionsForPester.Add('OutputFormat', 'NUnitXml')
    $optionsForPester.Add('OutputFile', $OutFile[0])
    $optionsForGherkin.Add('OutputFormat', 'NUnitXml')
    $optionsForGherkin.Add('OutputFile', $OutFile[1])
  }
}
else {
  $options = $opts
  if ($OutFile) {
    $options.Add('OutputFormat', 'NUnitXml')
    $options.Add('OutputFile', $OutFile[0])
  }
}

# Switch for test type
switch ($TestType) {
  "full" { 
    $testResultsPester = Invoke-Pester -Path "$Test\*tests*" @optionsForPester
    $testResultsGherkin = Invoke-Gherkin "$Test\spec" @optionsForGherkin
    $TestResults = $testResultsPester, $testResultsGherkin
  }
  "spec" {
    $TestResults = Invoke-Gherkin "$Test\spec" @options
  }
  "static" {
    $TestResults = Invoke-Pester -Script @{
      Path       = "$Test\*static*"
      Parameters = {
        Path = $Script:TargetPath
      }
    } @options
  }
  "" {
    $TestResults = Invoke-Pester -Path "$Test\*unit*" @options
  }
  Default {
    $TestResults = Invoke-Pester -Path "$Test\*$TestType*" @options
  }
}

if ($TestResults.FailedCount -gt 0) {
  Write-Error "Failed [$($TestResults.FailedCount)] tests"
}

if ($PassThru) {
  return $TestResults
}
else {
  if ($TestResults.FailedCount -gt 0) {
    exit 1
  }
  else {
    exit 0
  }
}