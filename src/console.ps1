<#
.Description
Installs and loads all the required modules for the build.
Derived from scripts written by Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param(
  # Type of job to call
  [Parameter(Mandatory = $true,
    Position = 0,
    HelpMessage = 'Task to execute (test|build|deploy). You can also pass a DSL string in the form: "test source spec function" as meaning of Task: test, CodeType: source, -TestType: spec -Tags: function')]
  [string]
  $TaskType,

  # Parameter passed to the Task
  [Parameter(Mandatory = $false,
    HelpMessage = 'Interactive session? (True|False)')]
  [switch]
  $InteractiveSession
)


# Remove __ if already present
Remove-Variable -Name __ -Scope Global -Force -ErrorAction SilentlyContinue

$tmp__ = @{}

# 1) Module Name
$tmp__.Add("ModuleName", '<%= $PLASTER_PARAM_ModuleName %>')

# 1) Paths
$tmp__.Add("Paths", @{})
$tmp__.Paths.Add("ProjectRoot", "$PSScriptRoot")
$tmp__.Paths.Add("SrcFolder", (Join-Path $tmp__.Paths.ProjectRoot "src"))
$tmp__.Paths.Add("OutputFolder", (Join-Path $tmp__.Paths.ProjectRoot "out"))
$tmp__.Paths.Add("DocsFolder", (Join-Path $tmp__.Paths.ProjectRoot "docs"))
$tmp__.Paths.Add("TestFolder", (Join-Path $tmp__.Paths.ProjectRoot "test"))
$tmp__.Paths.Add("ScriptsFolder", (Join-Path $tmp__.Paths.ProjectRoot "scripts"))
$tmp__.Paths.Add("BuildFolder", (Join-Path $tmp__.Paths.OutputFolder $tmp__.ModuleName))

$tmp__.Add("DirsToCompile", @( 'private', 'public', 'class' ))
$tmp__.Add("Files", @{})
$tmp__.Add("VendorFolder", @{})

# Build the many vendor paths
foreach ($v in $tmp__.Paths.Keys) {
  $tmp__.VendorFolder.Add($v, $tmp__.Item($v) + '\vendor' )
}

# - Dependencies file
$tmp__.Files.Add("Deps", (Join-Path $tmp__.Paths.SrcFolder '\deps.psd1'))

Set-Variable -Name __ -Description "Global variables for share data in project script." -Value ($tmp__.Clone()) -Option ReadOnly -Scope Global -Force


# Parameters decoding
if ($TaskType.Contains(' ')) {
  $Script:Parameterized = $true

  $params = $TaskType.Split(' ')

  $Script:Task = $params[0]

  switch ($Script:Task) {
    "build" {
      if ($params.Count -gt 1) {
        $Script:BuildTask = $params[1]
      }
      else {
        $Script:BuildTask = "Default"
      }
    }
    "deploy" {
      # TODO: Deploy parameters handler
    }
    "test" {
      switch ($params.Count) {
        1 {
          $Script:CodeType = "build"
          $Script:TestType = "full"
          $Script:Tags = @()
          $Script:TestOutPath = $Global:__.Paths.OutputFolder
        }
        2 {
          $Script:CodeType = $params[1]
          $Script:TestType = "unit"
          $Script:Tags = @()
        }
        3 {
          $Script:CodeType = $params[1]
          $Script:TestType = $params[2]
          $Script:Tags = @()
        }
        Default {
          $Script:CodeType = $params[1]
          $Script:TestType = $params[2]
          $Script:Tags = @()
          if ($params.Count -gt 3) {
            for ($i = 3; $i -lt $params.Count; $i++) {
              $Script:Tags += $($params[$i].Replace(',', '')).Replace(' ', '')
            }
          }
        }
      }
    }
    Default {
      throw "Task not found"
    }
  }
}
else {
  $Script:Task = $TaskType
}

switch ($Script:Task) {
  "build" {

    Write-Output "Starting build"

    Write-Output "  Install Dependent Modules"
    Install-Module InvokeBuild, PSDeploy, BuildHelpers, PSScriptAnalyzer, Pester, PSDepend -Scope CurrentUser

    Write-Output "  Import Dependent Modules"
    Import-Module InvokeBuild, BuildHelpers, PSScriptAnalyzer

    Set-BuildEnvironment

    if ($Interactive) {
      # Interactive overwrite actual value
      $Script:BuildTask = Read-Host "Build task to execute? (Default is 'Default')"
    }

    Write-Output "  InvokeBuild"
    Invoke-Build $Script:BuildTask -File "$($Global:__.Paths.ScriptsFolder)\build.ps1" -Result

    if ($Result.Error) {
      exit 1
    }
    else {
      exit 0
    }
  }

  "deploy" {
    Write-Output "Starting deploy"
      
    Write-Output "  Install Dependent Modules"
    Install-Module PSDeploy, BuildHelpers -Scope CurrentUser
      
    Write-Output "  Import Dependent Modules"
    Import-Module PSDeploy, BuildHelpers
    
    # BuildHelpers cmdlet
    Set-BuildEnvironment

    # PSDeploy cmdlet
    Invoke-PSDeploy -Path "$($Global:__.Paths.ScriptsFolder)\deploy.ps1" -DeploymentRoot $Global:__.ProjectRoot
  }

  "test" {

    Write-Output "Starting test"

    Write-Output "  Install Dependent Modules"
    Install-Module Pester -Scope CurrentUser

    Write-Output "  Import Dependent Modules"
    Import-Module Pester

    if ($Interactive) {
      & "$($Global:__.Paths.ScriptsFolder)\test.ps1"
    }
    else {
      & "$($Global:__.Paths.ScriptsFolder)\test.ps1" -CodeToTest $Script:CodeType -TestType $Script:TestType -Tags $Script:Tags -OutPath $Script:TestOutPath
    }
  }
  Default {
    & "$($Global:__.Paths.ScriptsFolder)\test.ps1" -CodeToTest "source" -TestType "unit" -Tags @()
  }
}

