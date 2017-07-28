@{
  PSDependOptions = @{
    Target = 'CurrentUser'
  }

  InvokeBuild  = @{
    Version = 'latest'
    Tags = 'build', 'test', 'package', 'deploy'
  }

  BuildHelpers  = @{
    Version = 'latest'
    Tags = 'package', 'deploy'
  }

  PSDeploy  = @{
    Version = 'latest'
    Tags = 'deploy'
  }

  Pester  = @{
    Version = 'latest'
    Tags = 'test'
  }

  PSScriptAnalyzer  = @{
    Version = 'latest'
    Tags = 'test'
  }
}