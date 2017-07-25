[cmdletbinding()]
param()
Write-Verbose "This psm1 is replaced in the build output. This file is only used for debugging."
Write-Verbose $PSScriptRoot

Write-Verbose 'Creating the <%= $PLASTER_PARAM_ModuleName %> variable'
New-Variable -Name $('<%= $PLASTER_PARAM_ModuleName %>' + 'root') -Value $PSScriptRoot

Write-Verbose 'Import vendor'
$items = Get-ChildItem -Directory -Path "$PSScriptRoot\vendor"
foreach ($item in $items) {
    Import-Module $item.FullName
}

Write-Verbose 'Import everything in sub folders'
foreach ($folder in @('classes', 'private', 'public', 'includes', 'internal'))
{
    $root = Join-Path -Path $PSScriptRoot -ChildPath $folder
    if (Test-Path -Path $root)
    {
        Write-Verbose "processing folder $root"
        $files = Get-ChildItem -Path $root -Filter *.ps1 -Recurse

        # dot source each file
        $files | where-Object { $_.name -NotLike '*.Tests.ps1'} | 
            ForEach-Object {Write-Verbose $_.basename; . $_.FullName}
    }
}

Export-ModuleMember -function (Get-ChildItem -Path "$PSScriptRoot\public\*.ps1").basename
