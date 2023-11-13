<#
.SYNOPSIS
    Validate that existing github release is correctly set or remove current release if a new one should be created.

.DESCRIPTION
    Validate that existing github release is correctly set or remove current release if a new one should be created.

.PARAMETER GithubToken
    Github token to provide access to Github API

.PARAMETER ExistingRelease
    Specify if releases should be updated for an existing Github release, leave empty if it's for a new release.

.PARAMETER Hotfix
    Specify if used for a hotfix release.

.PARAMETER Repository
    Repository update github release for.

.EXAMPLE
    .\setcurrentgithubrelease.ps1 -GithubToken $token
    Verify that there are no ongoing releases in Github.

.EXAMPLE
    .\setcurrentgithubrelease.ps1 -GithubToken $token -ExistingRelease
    Verify that the ongoing release is the correct one, and then delete it so that a new release can be created later in the pipeline.
#>

[CmdletBinding()]
[OutputType([System.Void])]
param (
    [Parameter(Mandatory = $true)]
    [string] $GithubToken,

    [Parameter(Mandatory = $false)]
    [switch] $ExistingRelease,

    [Parameter(Mandatory = $false)]
    [switch] $Hotfix,

    [Parameter(Mandatory = $false)]
    [string] $Repository = "shahramshahram/TestActions"
)

$headers = @{
    Authorization = "Bearer $GithubToken"
    Accept = "application/vnd.github.v3+json"
}

$releaseResponse = Invoke-WebRequest -Uri "https://api.github.com/repos/$Repository/releases" -Headers $headers -Method "Get"
$draftReleases = @((ConvertFrom-Json -InputObject $releaseResponse.Content) | Where-Object { $_.draft -eq $true })

if ($ExistingRelease -or $Hotfix) {
    # Bump an ongoing release
    if ($draftReleases.Count -gt 1) {
        throw "Multiple releases found, only one draft release is allowed: $($draftReleases.name -join ", ")"
    }

    $versionFilePath = "$PSScriptRoot/../PackageVersion.txt"
    $packageVersionFileContent = Get-Content -Path $versionFilePath
    $parsedVersion = [System.Version]::Parse($packageVersionFileContent)
    $packageVersionTag = "v$($parsedVersion.ToString())"

    if ($Hotfix) {
        $draftReleases = @($draftReleases | Where-Object { $_.tag_name -eq $packageVersionTag })
    }

    if ($draftReleases.Count -eq 1) {
        $release = $draftReleases[0]

        if ($release.tag_name -ne $packageVersionTag) {
            throw "Current release is $($release.tag_name), expected $packageVersionTag"
        }

        # Delete release so that a new one can be created later in the process
        $null = Invoke-WebRequest -Uri $release.url -Headers $headers -Method "Delete"
    }
    else {
        # No current release found, verify that it isn't already released
        $existingTag = Invoke-Expression "git tag --list '$packageVersionTag'"
        if ($existingTag) {
             throw "$packageVersionTag is already released"
        }
    }
    "version=$($parsedVersion.ToString())" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
}
elseif ($draftReleases.Count -gt 0) {
    # There shouldn't be any ongoing releases before bumping release version
    throw "Draft release found, close before starting a new release: $($draftReleases.name -join ", ")"
}