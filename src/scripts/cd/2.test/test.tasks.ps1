#Requires -Module InvokeBuild, Pester
requires Dirs, Files

<#
.SYNOPSIS
  InvokeBuild testing tasks.
.DESCRIPTION
  Build scripts dot-source this script in order to use the task "create".
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

#-------------------------------------------[Functions]-------------------------------------------#
function _GetTestFilePath ($TestType) {
  $timeStamp = $(((Get-Date).ToUniversalTime()).ToString("yyyyMMddThhmmssZ")).ToString()
  return $Dirs.Output + "$($TestType)TestResults_PS$PSVersion`_$timeStamp.xml"
}

function _HandleTestResult ($Result, $TestType) {
  if ($Result.FailedCount -gt 0) {
    Write-Error "Failed [$($Result.FailedCount)] $TestType test."
  }
}

function _InvokePesterTest ($TestType) {
  $path = $Dirs.Test + '\' + "$TestType*"
  Write-Verbose " $TestType test by $path tests..."
  $result = Invoke-Pester -Path $path @script:PesterOpts
  _HandleTestResult $result $TestType
}

function _InvokeGherkinTest {
  $path = $Dirs.Spec
  Write-Verbose " Acceptance test from $path specs..."
  $result = Invoke-Gherkin -Path $path @GherkinOpts
  _HandleTestResult $result 'Acceptance'
}

#-------------------------------------------[Variables]-------------------------------------------#

$local:opts = @{
  ExcludeTag   = 'Slow'
  PassThru     = $true
  OutputFormat = 'NUnitXml'
}

$script:PesterOpts = $opts.Clone()
$PesterOpts.Add('OutputFile', $(_GetTestFilePath $Task.Name))

$script:GherkinOpts = $opts.Clone()
$GherkinOpts.Add('OutputFile', $(_GetTestFilePath 'Acceptance'))

#---------------------------------------------[Tasks]---------------------------------------------#

Task Test ImportModule, AllTests

Task ImportModule {
  $manifestPath = $Files.BuildManifest
  $moduleName = $Config.ModuleName
  if ( -Not ( Test-Path $manifestPath ) ) {
    Write-Information "  Module '$moduleName' is not built, cannot find '$manifestPath'"
    Write-Error "Could not find module manifest '$manifestPath'" + 
                "You may need to build the module first."
  }
  else {
    if (Get-Module $moduleName) {
      Write-Output "  Unloading Module '['$moduleName']' from previous import"
      Remove-Module $moduleName -Force
    }
    Write-Output "  Importing Module '$moduleName' from '$manifestPath'"
    Import-Module $manifestPath -Force
  }
}

Task AllTests AcceptanceTest, HelpTest, ProjectTest, RegressionTest, StaticTest, UnitTest

Task AcceptanceTest {
  _InvokeGherkinTest
}

Task HelpTest {
  _InvokePesterTest 'help'
}

Task ProjectTest {
  _InvokePesterTest 'project'
}

Task RegressionTest {
  _InvokePesterTest 'regression'
}

Task StaticTest {
  _InvokePesterTest 'static'
}

Task UnitTest {
  _InvokePesterTest 'unit'
}