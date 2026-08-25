#requires -Version 7.2

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$DistributionRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LauncherRoot = 'D:\Project Rebirth\launcher',
    [string]$ProjectRoot = 'D:\Project Rebirth',
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Fa-f0-9 ]{40,}$')]
    [string]$CertificateThumbprint,
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$')]
    [string]$ContentVersion = '1.4.0',
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$LauncherVersion = '1.1.0',
    [ValidateRange(1, 90)]
    [int]$ManifestValidityDays = 30,
    [string]$DotNetPath = 'dotnet',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DistributionRoot = [System.IO.Path]::GetFullPath($DistributionRoot)
$LauncherRoot = [System.IO.Path]::GetFullPath($LauncherRoot)
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$settingsPath = Join-Path $DistributionRoot 'distribution.settings.json'
if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    throw "Distribution settings were not found: $settingsPath"
}
$settings = [System.IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
if ($settings.pagesBaseUri -notmatch '^https://[^/]+/.+/$') {
    throw 'pagesBaseUri must be an absolute HTTPS project-site URI ending in a slash.'
}
if ([string]$settings.authAddress -cne '134.122.124.150' -or
    [int]$settings.authPort -ne 3724 -or [int]$settings.worldPort -ne 8087) {
    throw 'Distribution settings do not contain the approved public VPS gateway endpoint.'
}

$publisher = Join-Path $LauncherRoot 'tools\Publish-ProjectRebirthClientFeed.ps1'
$builder = Join-Path $LauncherRoot 'tools\Build-ProjectRebirthPublicLauncher.ps1'
$trustSource = Join-Path $LauncherRoot 'src\ProjectRebirth.Launcher\UpdateTrust.cs'
$addonSources = @(
    (Join-Path $ProjectRoot 'client-addon\ProjectRebirthTooltips'),
    (Join-Path $ProjectRoot 'client-addon\RebirthWardrobe')
)
foreach ($required in @($publisher, $builder, $trustSource) + $addonSources) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required Project Rebirth publisher input is missing: $required"
    }
}

$siteRoot = Join-Path $DistributionRoot 'site'
$bootstrapPath = Join-Path $DistributionRoot 'launcher\launcher.bootstrap.json'
$releaseAssets = Join-Path $DistributionRoot 'release-assets'
$manifestUri = ([Uri]::new([Uri]$settings.pagesBaseUri, "$($settings.channel)/manifest.json")).AbsoluteUri
$signatureUri = ([Uri]::new([Uri]$settings.pagesBaseUri, "$($settings.channel)/manifest.json.sig")).AbsoluteUri

if (-not $PSCmdlet.ShouldProcess($DistributionRoot, "Create signed public content $ContentVersion and launcher $LauncherVersion")) {
    return
}

& $publisher `
    -LauncherRoot $LauncherRoot `
    -ProjectRoot $ProjectRoot `
    -AddonSource $addonSources `
    -FeedRoot $siteRoot `
    -Channel ([string]$settings.channel) `
    -ContentVersion $ContentVersion `
    -MinimumLauncherVersion $LauncherVersion `
    -AuthAddress ([string]$settings.authAddress) `
    -AuthPort ([int]$settings.authPort) `
    -WorldPort ([int]$settings.worldPort) `
    -ReleaseHeadline 'Rebirth Wardrobe 1.0' `
    -ReleaseSummary 'Adds the independent account-wide Rebirth Wardrobe, persistent cosmetic slots, outfits, and specialization bindings.' `
    -UpdateKind content `
    -RequiresClientUpdate $true `
    -ManifestValidityDays $ManifestValidityDays `
    -CertificateThumbprint $CertificateThumbprint `
    -UpdateTrustPath $trustSource `
    -Force:$Force
$publisherSucceeded = $?
if (-not $publisherSucceeded) {
    throw 'Feed publisher failed.'
}

$bootstrap = [ordered]@{
    product = 'Project Rebirth'
    channel = [string]$settings.channel
    manifestUri = $manifestUri
    signatureUri = $signatureUri
    allowLocalFeed = $false
    cleanWowSha256 = 'AA63A5750D60EF16746C686B3D5E26876D98953EAB08B1C026CD0FAF78E88CB8'
    requiredWowBuild = 12340
}
$bootstrapJson = $bootstrap | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($bootstrapPath, $bootstrapJson + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

$settings.contentVersion = $ContentVersion
$settings.launcherVersion = $LauncherVersion
[System.IO.File]::WriteAllText(
    $settingsPath,
    ($settings | ConvertTo-Json -Depth 5) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false))

& $builder `
    -LauncherRoot $LauncherRoot `
    -BootstrapFile $bootstrapPath `
    -DistributionRoot $releaseAssets `
    -Version $LauncherVersion `
    -DotNetPath $DotNetPath `
    -Force:$Force
$builderSucceeded = $?
if (-not $builderSucceeded) {
    throw 'Launcher build failed.'
}

& (Join-Path $DistributionRoot 'tools\Test-PublicDistribution.ps1') -DistributionRoot $DistributionRoot
$validationSucceeded = $?
if (-not $validationSucceeded) {
    throw 'Public distribution validation failed.'
}

Write-Host "Signed manifest: $(Join-Path $siteRoot "$($settings.channel)\manifest.json")"
Write-Host "HTTPS manifest URI: $manifestUri"
Write-Host "Launcher release assets: $releaseAssets"
Write-Host 'No signing private key, VPN profile, credential, WoW client, MPQ, or extracted client data was copied.'
