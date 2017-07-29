#Requires -Module Pester

<#
.SYNOPSIS
  Tests launcher.
.DESCRIPTION
  Launch the selected automated $Test through Pester or Gherkin.
  This differ from the test process, which launch all tests for all tags.

  Acceptance test are performed by Gherkin; all others are performed by Pester.
  
  The test name must correspond to basename of test file stored into the .\test directory.
  You can also pass specified test tags and/or scenarios.
.EXAMPLE
  .\tests.ps1 unit
  Launch all unit tests.
.EXAMPLE
  .\tests.ps1 acceptance
  Launch all automated acceptance tests.
.EXAMPLE
  .\tests.ps1 unit function, project
  Launch all unit tests tagged  function and/or project.

.EXAMPLE
  .\tests.ps1 acceptance -Scenarios myAwesomeScenario
  Launch acceptance test for myAwesomeScenario scenario.
.NOTES
  Version:        1.0
  Author:         Roberto Desideri
  Creation Date:  2017-07-27
  Purpose/Change: Initial script development
#>

param(
  # Name of the process as string
  [Parameter(Mandatory = $true,
    HelpMessage = 'The test type to launch.')]
  [switch]
  $TestType,

  # Tags to pass to selected process as array of string
  [Parameter(Mandatory = $false,
    HelpMessage = 'Test tags to filter-in.')]
  [string[]]
  $Tags,
  
  # Tags to pass to selected process as array of string
  [Parameter(Mandatory = $false,
    HelpMessage = 'Acceptance scenarios to test.')]
  [string[]]
  $Scenarios
)

#---------------------------------------------[Begin]---------------------------------------------#

$OriginalLocation = Get-Location
Set-Location $PSScriptRoot

if (!Test-Path variable:Dirs) {
  throw 'Dirs variable required.'
}

#--------------------------------------------[Process]--------------------------------------------#

if ($TestType -notmatch '.*acceptance.*') {
  $testFile = Get-ChildItem -File -Path $Dirs.Tests -Include "*$TestType.tests.ps1" -Recurse |
    Select-Object -ExpandProperty FullName
  if (!$testFile) {
    throw "Test $TestType not found in $($Dirs.Tests) directory."
  }
  Invoke-Pester -Script $testFile -Tag $Tags
}
else {
  Invoke-Gherkin -Path $Dirs.Specs -Tag -ScenarioName $Scenarios
}

#----------------------------------------------[End]----------------------------------------------#

# Restore location
Set-Location $OriginalLocation