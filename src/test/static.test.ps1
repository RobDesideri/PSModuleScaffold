#Requires -Module PSScriptAnalyzer, Pester
# Parameters
param(
  # Path to code to analyze.
  [Parameter(Mandatory=$true,
             Position=0,
             ValueFromPipeline=$true,
             ValueFromPipelineByPropertyName=$true,
             HelpMessage="Path to code to analyze.")]
  [ValidateNotNullOrEmpty()]
  [string]
  $Path
)

Describe "Static code analysis" -Tag Source {

  $Rules = Get-ScriptAnalyzerRule
  $scripts = Get-ChildItem "$Path"-Include *.ps1, *.psm1, *.psd1 -Recurse | Where-Object fullname -notmatch 'classes|lib'

  foreach ( $Script in $scripts ) {
      Context "Script '$($script.FullName)'" {

          foreach ( $rule in $rules ) {
              It "Rule [$rule]" {

                  (Invoke-ScriptAnalyzer -Path $script.FullName -IncludeRule $rule.RuleName).Count | Should Be 0
              }
          }
      }
  }
}