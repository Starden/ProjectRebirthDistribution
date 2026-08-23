#requires -Version 7.2

[CmdletBinding()]
param(
    [string]$DistributionRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$SkipReleaseAsset
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failures = [System.Collections.Generic.List[string]]::new()
$script:Passes = 0

function Add-Failure {
    param([Parameter(Mandatory)][string]$Message)
    $script:Failures.Add($Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Add-Pass {
    param([Parameter(Mandatory)][string]$Message)
    $script:Passes++
    Write-Host "PASS: $Message" -ForegroundColor Green
}

function Get-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Failure "Required JSON file is missing: $Path"
        return $null
    }
    try {
        return [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
    }
    catch {
        Add-Failure "Invalid JSON in '$Path': $($_.Exception.Message)"
        return $null
    }
}

function Test-PublicTree {
    param([Parameter(Mandatory)][string]$Root)

    $forbidden = [System.Collections.Generic.List[string]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force)) {
        $relative = [System.IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\', '/')
        if ($relative.StartsWith('.git/', [System.StringComparison]::OrdinalIgnoreCase) -or
            $relative.StartsWith('release-assets/', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $segments = $relative.Split('/')
        $hasDataTree = @($segments | Where-Object { $_ -ieq 'Data' }).Count -gt 0
        $isPublicVerificationKey = $relative -ceq 'site/update-signing-public-key.pem'
        if ($file.Name -ieq 'Wow.exe' -or
            $file.Extension -ieq '.mpq' -or
            $file.Extension -in @('.pfx', '.p12', '.key') -or
            ($file.Extension -ieq '.pem' -and -not $isPublicVerificationKey) -or
            $file.Name -ieq 'publisher.settings.json' -or
            $file.Name -match '(?i)(wireguard|wg0|credential|password|private[-_]?key)' -or
            $hasDataTree) {
            $forbidden.Add($relative)
        }
    }

    if ($forbidden.Count -eq 0) {
        Add-Pass 'Public repository tree contains no client, credential, VPN-profile, or private-key artifact'
    }
    else {
        foreach ($finding in $forbidden) {
            Add-Failure "Forbidden public artifact: $finding"
        }
    }
}

function Test-BootstrapObject {
    param(
        [Parameter(Mandatory)]$Bootstrap,
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)][string]$Label
    )

    $expectedManifest = ([Uri]::new([Uri]$Settings.pagesBaseUri, "$($Settings.channel)/manifest.json")).AbsoluteUri
    $expectedSignature = ([Uri]::new([Uri]$Settings.pagesBaseUri, "$($Settings.channel)/manifest.json.sig")).AbsoluteUri
    if ($Bootstrap.product -ne 'Project Rebirth' -or $Bootstrap.channel -ne $Settings.channel) {
        Add-Failure "$Label identifies the wrong product or channel"
    }
    elseif ([bool]$Bootstrap.allowLocalFeed) {
        Add-Failure "$Label enables a local feed"
    }
    elseif ([string]$Bootstrap.manifestUri -cne $expectedManifest -or
        [string]$Bootstrap.signatureUri -cne $expectedSignature) {
        Add-Failure "$Label does not use the expected absolute GitHub Pages HTTPS URLs"
    }
    elseif (-not ([Uri]$Bootstrap.manifestUri).Scheme.Equals('https', [System.StringComparison]::OrdinalIgnoreCase) -or
        -not ([Uri]$Bootstrap.signatureUri).Scheme.Equals('https', [System.StringComparison]::OrdinalIgnoreCase)) {
        Add-Failure "$Label contains a non-HTTPS update URL"
    }
    elseif ([int]$Bootstrap.requiredWowBuild -ne 12340 -or
        [string]$Bootstrap.cleanWowSha256 -notmatch '^[A-F0-9]{64}$') {
        Add-Failure "$Label does not enforce the expected clean build-12340 client"
    }
    else {
        Add-Pass "$Label uses absolute HTTPS, disables local feeds, and requires clean build 12340"
    }
}

function Test-LauncherArchive {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Settings,
        [Parameter(Mandatory)]$RepositoryBootstrap
    )

    $assetRoot = Join-Path $Root 'release-assets'
    $expectedName = "Project-Rebirth-Launcher-$($Settings.launcherVersion)-win-x64.zip"
    $zipPath = Join-Path $assetRoot $expectedName
    $hashPath = "$zipPath.sha256"
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $hashPath -PathType Leaf)) {
        Add-Failure "Launcher release archive or SHA-256 sidecar is missing under '$assetRoot'"
        return
    }

    $sidecar = [System.IO.File]::ReadAllText($hashPath).Trim()
    $sidecarMatch = [regex]::Match($sidecar, '^(?<hash>[a-fA-F0-9]{64})\s{2}(?<name>[^\/\\]+)$')
    $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $sidecarMatch.Success -or
        $sidecarMatch.Groups['name'].Value -cne $expectedName -or
        $sidecarMatch.Groups['hash'].Value.ToLowerInvariant() -cne $actualHash) {
        Add-Failure 'Launcher SHA-256 sidecar does not match the exact archive bytes and filename'
    }
    else {
        Add-Pass "Launcher archive SHA-256 matches: $actualHash"
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        foreach ($required in @('ProjectRebirth.Launcher.exe', 'launcher.bootstrap.json', 'PLAYER-GUIDE.md', 'README.md')) {
            if ($entryNames -notcontains $required) {
                Add-Failure "Launcher archive is missing required entry: $required"
            }
        }

        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            $segments = $name.Split('/')
            if ($name -match '(^|/)Wow\.exe$' -or
                $name -match '(?i)\.mpq$' -or
                @($segments | Where-Object { $_ -ieq 'Data' }).Count -gt 0 -or
                $name -match '(?i)(\.pfx$|\.p12$|\.key$|\.pem$|publisher\.settings\.json$|wireguard|wg0|credential|password|private[-_]?key)' -or
                $name.StartsWith('feed/', [System.StringComparison]::OrdinalIgnoreCase)) {
                Add-Failure "Forbidden entry in launcher archive: $name"
            }
        }

        $bootstrapEntry = $archive.GetEntry('launcher.bootstrap.json')
        if ($null -ne $bootstrapEntry) {
            $stream = $bootstrapEntry.Open()
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.UTF8Encoding]::new($false), $true)
            try {
                $archiveBootstrap = $reader.ReadToEnd() | ConvertFrom-Json
                Test-BootstrapObject -Bootstrap $archiveBootstrap -Settings $Settings -Label 'Packaged launcher bootstrap'
                if (($archiveBootstrap | ConvertTo-Json -Depth 5 -Compress) -cne
                    ($RepositoryBootstrap | ConvertTo-Json -Depth 5 -Compress)) {
                    Add-Failure 'Packaged launcher bootstrap differs from launcher/launcher.bootstrap.json'
                }
                else {
                    Add-Pass 'Packaged launcher bootstrap matches the reviewed public bootstrap'
                }
            }
            finally {
                $reader.Dispose()
                $stream.Dispose()
            }
        }
        Add-Pass 'Launcher archive contains no bundled feed, client, MPQ, Data tree, credential, or private key'
    }
    finally {
        $archive.Dispose()
    }
}

$DistributionRoot = [System.IO.Path]::GetFullPath($DistributionRoot)
Write-Host "Project Rebirth public distribution validation: $DistributionRoot" -ForegroundColor Cyan

$settingsPath = Join-Path $DistributionRoot 'distribution.settings.json'
$settings = Get-JsonFile -Path $settingsPath
if ($null -eq $settings) {
    exit 1
}

    $expectedBase = 'https://starden.github.io/ProjectRebirthDistribution/'
if ([string]$settings.pagesBaseUri -cne $expectedBase -or
    [string]$settings.repositoryOwner -cne 'Starden' -or
    [string]$settings.repositoryName -cne 'ProjectRebirthDistribution') {
    Add-Failure 'Distribution settings do not match the reviewed public repository and Pages base URL'
}
else {
    Add-Pass 'Distribution settings use the expected GitHub Pages origin'
}

Test-PublicTree -Root $DistributionRoot

$bootstrapPath = Join-Path $DistributionRoot 'launcher\launcher.bootstrap.json'
$bootstrap = Get-JsonFile -Path $bootstrapPath
if ($null -ne $bootstrap) {
    Test-BootstrapObject -Bootstrap $bootstrap -Settings $settings -Label 'Repository launcher bootstrap'
}

$channelRoot = Join-Path (Join-Path $DistributionRoot 'site') $settings.channel
$manifestPath = Join-Path $channelRoot 'manifest.json'
$signaturePath = Join-Path $channelRoot 'manifest.json.sig'
$publicKeyPath = Join-Path $DistributionRoot 'site\update-signing-public-key.pem'
$manifest = Get-JsonFile -Path $manifestPath

if (-not (Test-Path -LiteralPath $signaturePath -PathType Leaf)) {
    Add-Failure "Detached signature is missing: $signaturePath"
}
if (-not (Test-Path -LiteralPath $publicKeyPath -PathType Leaf)) {
    Add-Failure "Public verification key is missing: $publicKeyPath"
}

if ($null -ne $manifest) {
    if ([string]$manifest.product -ne 'Project Rebirth' -or
        [string]$manifest.channel -ne [string]$settings.channel -or
        [string]$manifest.contentVersion -ne [string]$settings.contentVersion -or
        [string]$manifest.signatureAlgorithm -ne 'ECDSA_P256_SHA256_P1363') {
        Add-Failure 'Manifest identity, version, or signature algorithm differs from distribution settings'
    }
    else {
        Add-Pass 'Manifest identity and content version match distribution settings'
    }

    if ([string]$manifest.realm.authAddress -cne '134.122.124.150' -or
        [int]$manifest.realm.authPort -ne 3724 -or [int]$manifest.realm.worldPort -ne 8087 -or
        [string]$manifest.realm.authAddress -match '^(127\.|localhost$|192\.168\.|10\.0\.)') {
        Add-Failure 'Manifest does not contain only the approved public VPS gateway endpoint'
    }
    else {
        Add-Pass 'Manifest realm endpoint is the approved VPS gateway 134.122.124.150:3724/8087'
    }

    $expiresAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$manifest.expiresAtUtc, [ref]$expiresAt) -or
        $expiresAt -le [DateTimeOffset]::UtcNow) {
        Add-Failure 'Manifest expiry is invalid or already expired'
    }
    else {
        Add-Pass "Manifest remains valid until $($expiresAt.ToString('u'))"
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($manifest.files)) {
        $managedPath = [string]$entry.path
        $url = [string]$entry.url
        if (-not $managedPath.StartsWith('Interface/AddOns/ProjectRebirthTooltips/', [System.StringComparison]::OrdinalIgnoreCase) -or
            $managedPath.Contains('\') -or $managedPath.Contains('..') -or $managedPath.Contains(':') -or
            -not $seen.Add($managedPath)) {
            Add-Failure "Unsafe or duplicate managed path: $managedPath"
            continue
        }
        if ($url.Contains('\') -or $url.Contains('..') -or [Uri]::IsWellFormedUriString($url, [UriKind]::Absolute)) {
            Add-Failure "Payload URL must be a canonical relative URL under the signed channel: $url"
            continue
        }
        $payloadPath = [System.IO.Path]::GetFullPath((Join-Path $channelRoot $url.Replace('/', [System.IO.Path]::DirectorySeparatorChar)))
        $channelPrefix = [System.IO.Path]::GetFullPath($channelRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $payloadPath.StartsWith($channelPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
            Add-Failure "Payload is missing or escapes the channel: $url"
            continue
        }
        $size = (Get-Item -LiteralPath $payloadPath).Length
        $hash = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($size -ne [Int64]$entry.size -or $hash -cne ([string]$entry.sha256).ToUpperInvariant()) {
            Add-Failure "Payload size or SHA-256 mismatch: $managedPath"
        }
        else {
            Add-Pass "Payload verified: $managedPath"
        }
    }
}

if ((Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
    (Test-Path -LiteralPath $signaturePath -PathType Leaf) -and
    (Test-Path -LiteralPath $publicKeyPath -PathType Leaf)) {
    try {
        $manifestBytes = [System.IO.File]::ReadAllBytes($manifestPath)
        $signatureBytes = [Convert]::FromBase64String([System.IO.File]::ReadAllText($signaturePath).Trim())
        $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
        try {
            $ecdsa.ImportFromPem([System.IO.File]::ReadAllText($publicKeyPath))
            $expectedSpki = 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEO8fHaX+xO+04KDR7CaCaPqnuXMZv5BzPbSV9M2ArcR4qxZsSqSvQ5eeat17bt0jweCbe/Xu4wZgrk+6XG9bh2g=='
            $actualSpki = [Convert]::ToBase64String($ecdsa.ExportSubjectPublicKeyInfo())
            if ($actualSpki -cne $expectedSpki) {
                Add-Failure 'Public verification key differs from the key pinned in launcher 1.0.0'
            }
            elseif (-not $ecdsa.VerifyData(
                $manifestBytes,
                $signatureBytes,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.DSASignatureFormat]::IeeeP1363FixedFieldConcatenation)) {
                Add-Failure 'Detached ECDSA signature does not match the exact manifest bytes'
            }
            else {
                Add-Pass 'Detached ECDSA signature matches the exact manifest bytes and launcher-pinned key'
            }
        }
        finally {
            $ecdsa.Dispose()
        }
    }
    catch {
        Add-Failure "Signature verification failed: $($_.Exception.Message)"
    }
}

if (-not $SkipReleaseAsset -and $null -ne $bootstrap) {
    Test-LauncherArchive -Root $DistributionRoot -Settings $settings -RepositoryBootstrap $bootstrap
}

Write-Host ''
Write-Host "Result: $script:Passes passed, $($script:Failures.Count) failed" -ForegroundColor Cyan
if ($script:Failures.Count -gt 0) {
    exit 1
}
exit 0
