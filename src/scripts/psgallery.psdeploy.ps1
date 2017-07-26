Deploy Module {
  By PSGalleryModule {
    FromSource $Global:__.Paths.Dir.Build
    To PSGallery
    WithOptions @{
      ApiKey = $ENV:NugetApiKey
    }
  }
}