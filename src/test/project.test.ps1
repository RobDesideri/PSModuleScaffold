# Load the global variable
$Script:__ = $Global:__

Describe "Module import validation" {

    Context "Source module" -Tag Source {
        It "can import cleanly" {
            & powershell Import-Module $__.SrcFolder
            $LASTEXITCODE | Should Be 0
        }
    }

    Context "Built module" -Tag Build {
        It "can import cleanly" {
            & powershell Import-Module $__.BuildFolder
            $LASTEXITCODE | Should Be 0
        }
    }

}

Describe "Project structure" {

    Context "Source folder" -Tag Source {

        It "should contains a psd1 manifest file" {
            "$($__.SrcFolder)\*.psd1" | Should Exist
        }

        It "should contains a psm1 module file" {
            "$($__.SrcFolder)\*.psm1" | Should Exist
        }

        It "should contains a public folder" {
            "$($__.SrcFolder)\public" | Should Exist
        }

        It "should contains a ps1 file in public folder" {
            "$($__.SrcFolder)\public\*.ps1" | Should Exist
        }
    }

    Context "Project folder" -Tag Project {
        It "should contains a readme.md file" {
            "$($__.ProjectRoot)\README.md" | Should Exist
        }

        It "should contains a LICENSE file" {
            "$($__.ProjectRoot)\LICENSE" | Should Exist
        }

        It "should contains a gitignore file" {
            "$($__.ProjectRoot)\.gitignore" | Should Exist
        }

        It "should contains an appveyor file" {
            "$($__.ProjectRoot)\.appveyor.yml" | Should Exist
        }

        It "should contains the console.ps1 file" {
            "$($__.ProjectRoot)\.console.ps1" | Should Exist
        }

        It "should contains a test folder" {
            "$($__.ProjectRoot)\test" | Should Exist
        }

        It "should contains project test files" {
            "$($__.ProjectRoot)\test\project.test.ps1" | Should Exist
        }

        It "should contains help test files" {
            "$($__.ProjectRoot)\test\help.test.ps1" | Should Exist
        }

        It "should contains regression test files" {
            "$($__.ProjectRoot)\test\regression.test.ps1" | Should Exist
        }

        It "should contains unit test files" {
            "$($__.ProjectRoot)\test\unit.test.ps1" | Should Exist
        }

        It "should contains some spec files and relative steps" {
            "$($__.ProjectRoot)\test\spec" | Should Exist

            "$($__.ProjectRoot)\test\spec\*.feature" | Should Exist

            "$($__.ProjectRoot)\test\spec\*.steps" | Should Exist
        }

        It "should contains a scripts folder" {
            "$($__.ProjectRoot)\scripts" | Should Exist
        }

        It "should contains the test script file" {
            "$($__.ProjectRoot)\scripts\test.ps1" | Should Exist
        }

        It "should contains the build script file" {
            "$($__.ProjectRoot)\scripts\build.ps1" | Should Exist
        }

        It "should contains the deploy script file" {
            "$($__.ProjectRoot)\scripts\deploy.ps1" | Should Exist
        }

        It "should contains a docs folder" {
            "$($__.ProjectRoot)\docs" | Should Exist
        }

        It "should contains a src folder" {
            "$($__.ProjectRoot)\src" | Should Exist
        }
    }

    Context "Build folder" -Tag Build {
        It "should contains a psd1 manifest file" {
            "$($__.BuildFolder)\*.psd1" | Should Exist
        }

        It "should contains a psm1 module file" {
            "$($__.BuildFolder)\*.psm1" | Should Exist
        }

        It "should contains a lib folder only if exists in source" {
            if (Test-Path "$($__.SrcFolder)\lib") {
                "$($__.BuildFolder)\lib" | Should Exist
            }
            else {
                "$($__.BuildFolder)\lib" | Should Not Exist
            }
        }

        It "should contains a data folder only if exists in source" {
            if (Test-Path "$($__.SrcFolder)\data") {
                "$($__.BuildFolder)\data" | Should Exist
            }
            else {
                "$($__.BuildFolder)\data" | Should Not Exist
            }
        }
    }
}

Describe "Public functions" {

    # Vars
    $Script:PublicFunctionsNames = @()
    $Script:PublicFunctionsScriptBlock = @()
    $Script:PublicFunctions = @()
    $Script:PublicFunctionsCount = @()

    BeforeAll {
        $publicScripts = Get-ChildItem "$($__.SrcFolder)\*" -Recurse -Filter "*.ps1" -File
        $exported = @()

        foreach ($s in $publicScripts) {
            $exported.Clear()
            # https://github.com/zloeber/ModuleBuild/blob/master/ModuleBuild.build.ps1#L296
            $exported += ([System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Path $_.FullName -Raw), [ref]$null, [ref]$null)).FindAll( { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
            $Script:PublicFunctions += $exported
            $Script:PublicFunctionsCount = $exported.Count 
        }

        $Script:PublicFunctionsNames = $PublicFunctions | Select-Object { $_.Name }
        $Script:PublicFunctionsScriptBlock = $PublicFunctions | Select-Object { $_.ScriptBlock }
    }

    Context "Source code" -Tag Source {

        It "should be contained one for script file" {
            foreach ($c in $Script:PublicFunctionsCount) {
                $c | Should Be 1
            }
        }
    }

    Context "Builded code" -Tag Build {

        It "should contains a cmdletbinding" {
            $match = [regex]::Escape('\[CmdletBinding\(.*\)\]')
            foreach ($s in $Script:PublicFunctionsScriptBlock) {
                $match = [regex]::Escape($Text)
                $($s.ToString()) -match "\[CmdletBinding\(.*\)\]" | Should Be True
            }
        }

        It "should contains a ThrowTerminatingError" {
            $match = [regex]::Escape('ThrowTerminatingError\(.*\)')
            foreach ($s in $Script:PublicFunctionsScriptBlock) {
                $match = [regex]::Escape($Text)
                $($s.ToString()) -match "\[CmdletBinding\(.*\)\]" | Should Be True
            }
        }

    }

    Context "Module manifest in builded code" -Tag Build {

        # Vars
        $psd = Import-PowerShellDataFile -Path "$($__.BuildFolder)\$($__.ModuleName).psd1"
        $PublicDeclared = $psd.FunctionsToExport

        It "should list all public functions" {
            foreach ($f in $Script:PublicFunctionsNames) {
                $PublicDeclared -contains $f | Should Be $true
            }
        }

        It "should list only public functions" {
            foreach ($f in $PublicDeclared) {
                $Script:PublicFunctionsNames -contains $f | Should Be $true
            }
        }
    }

}