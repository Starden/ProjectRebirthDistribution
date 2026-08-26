#requires -Version 7.2

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$DistributionRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$DistributionRoot = [System.IO.Path]::GetFullPath($DistributionRoot)
$settings = [System.IO.File]::ReadAllText((Join-Path $DistributionRoot 'distribution.settings.json')) | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = [string]$settings.launcherVersion
}
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
    throw "Invalid launcher version: $Version"
}
$repository = "$($settings.repositoryOwner)/$($settings.repositoryName)"
$tag = "launcher-v$Version"
$assetName = "Project-Reverie-Launcher-$Version-win-x64.zip"
$zipPath = Join-Path $DistributionRoot "release-assets\$assetName"
$hashPath = "$zipPath.sha256"
$notesPath = Join-Path $DistributionRoot "docs\RELEASE-NOTES-launcher-v$Version.md"

& (Join-Path $DistributionRoot 'tools\Test-PublicDistribution.ps1') -DistributionRoot $DistributionRoot
$validationSucceeded = $?
if (-not $validationSucceeded) {
    throw 'Public distribution validation failed; refusing to publish a GitHub Release.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is not installed or is not available on PATH.'
}

& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI is not authenticated.'
}
$repoJson = & gh repo view $repository --json nameWithOwner,isPrivate 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "GitHub repository does not exist or is not accessible: $repository"
}
$repoInfo = $repoJson | ConvertFrom-Json
if ([bool]$repoInfo.isPrivate) {
    throw "Repository '$repository' is private; an unauthenticated public launcher could not use this distribution edge."
}

& gh release view $tag --repo $repository *> $null
if ($LASTEXITCODE -eq 0) {
    throw "Release '$tag' already exists. Use a new launcher version; this script will not overwrite public assets."
}

if (-not $PSCmdlet.ShouldProcess("$repository release $tag", "Upload $assetName and its SHA-256 sidecar")) {
    return
}

& gh release create $tag $zipPath $hashPath `
    --repo $repository `
    --title "Project Reverie Launcher $Version — Rebirth" `
    --notes-file $notesPath `
    --latest
if ($LASTEXITCODE -ne 0) {
    throw "GitHub Release publication failed with exit code $LASTEXITCODE."
}

Write-Host "Published: https://github.com/$repository/releases/tag/$tag"
