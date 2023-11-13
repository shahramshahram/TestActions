<#
.SYNOPSIS
    Sets a new version by updating PackageVersion.txt and SharedAssemblyInfo.cs

.DESCRIPTION
    Sets a new version by updating PackageVersion.txt and SharedAssemblyInfo.cs

.PARAMETER Version
    Exact version to set.

.PARAMETER IncreaseMinorVersion
    Bump version by a minor version.

.EXAMPLE
    .\RunVersionBump.ps1 -Version 3.25.0
    New version to set.

.EXAMPLE
    .\RunVersionBump.ps1 -IncreaseMinorVersion
    Bump version by a minor version.
#>

[CmdletBinding()]
[OutputType([System.Void])]
param (
    [Parameter(Mandatory = $false)]
    [string] $Version,

    [Parameter(Mandatory = $false)]
    [switch] $IncreaseMinorVersion
)

if (-not $IncreaseMinorVersion -and -not $Version) {
    throw "Version or IncreaseMinorVersion parameters are required."
}

if ($IncreaseMinorVersion -and $Version) {
    throw "Can't specify both Version and IncreaseMinorVersion"
}

if ($Version -and $Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must be in the format: 0.0.0"
}

$versionFilePath = "$PSScriptRoot/../PackageVersion.txt"

$packageVersionFileContent = Get-Content -Path $versionFilePath
$currentVersion = $packageVersionFileContent

if (-not $currentVersion) {
    throw "Can't find package version in $VersionFilePath"
}

if ($IncreaseMinorVersion) {
    $currentVersionParts = $currentVersion -split "\."

    $newVersion = "$($currentVersionParts[0]).$(1+$currentVersionParts[1]).0"

    Write-Output "Increasing minor version to: $newVersion"
}
else {
    if ($currentVersion -eq $Version) {
        Write-Output "Version already at $currentVersion"
        "version=$currentVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        return
    }

    $newVersion = $Version
    Write-Output "Setting exact version: $newVersion"
}

$versionParsed = [System.Version]::Parse($newVersion)
$versionParsed.ToString() | Set-Content -Path $versionFilePath

$sharedAssemblyInfoFile = "$PSScriptRoot/../../SharedAssemblyInfo.cs"
$pattern = '\[assembly: Assembly(\w*)Version\("(.*)"\)\]'
$replacement = '[assembly: Assembly$1Version("' + $newVersion + '")]'
(Get-Content -Path $sharedAssemblyInfoFile) | ForEach-Object {
    $line = $_ -replace $pattern, $replacement
    $line
} | Set-Content -Path $sharedAssemblyInfoFile

"version=$newVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append