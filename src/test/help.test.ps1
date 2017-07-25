Describe "Help test" {
  
  $functions = Get-Command -Module $($Global:__.ModuleName)
  $help = $functions | ForEach-Object {Get-Help $_.name}
  foreach ($node in $help) {
    Context $node.name {
  
      it "has a description" {
        $node.description | Should Not BeNullOrEmpty
      }
      it "has an example" {
        $node.examples | Should Not BeNullOrEmpty
      }
      foreach ($parameter in $node.parameters.parameter) {
        if ($parameter -notmatch 'whatif|confirm') {
          it "parameter $($parameter.name) has a description" {
            $parameter.Description.text | Should Not BeNullOrEmpty
          }
        }
      }
    }
  }
}  