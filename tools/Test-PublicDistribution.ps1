#requires -Version 7.2

[CmdletBinding()]
param(
    [string]$DistributionRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$SkipReleaseAsset,
    [string]$ReleaseTag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failures = [System.Collections.Generic.List[string]]::new()
$script:Passes = 0
$script:PendingReleaseValid = $false

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

function Test-DistributionSettingsSchema {
    param([Parameter(Mandatory)]$Settings)

    $required = @(
        'schemaVersion', 'repositoryOwner', 'repositoryName', 'pagesBaseUri',
        'channel', 'launcherVersion', 'contentVersion', 'authAddress',
        'authPort', 'worldPort'
    )
    $allowed = @($required + 'pendingRelease')
    $actual = @($Settings.PSObject.Properties.Name)
    $unknown = @($actual | Where-Object { $_ -cnotin $allowed })
    $missing = @($required | Where-Object { $_ -cnotin $actual })
    $canonical = '\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\z'

    if ($unknown.Count -ne 0 -or $missing.Count -ne 0 -or
        $Settings.schemaVersion -ne 1 -or
        [string]$Settings.channel -cne 'stable' -or
        [string]$Settings.launcherVersion -cnotmatch $canonical -or
        [string]$Settings.contentVersion -cnotmatch $canonical) {
        Add-Failure 'Distribution settings have unknown/missing fields, wrong schema/channel, or non-canonical active versions'
        return
    }
    Add-Pass 'Distribution settings schema and active versions are exact'

    if (-not $Settings.PSObject.Properties['pendingRelease']) {
        Add-Pass 'No pending launcher release is staged'
        return
    }

    $pending = $Settings.pendingRelease
    $fields = @('launcherVersion', 'contentVersion', 'archiveSha256', 'archiveSize')
    if ($null -eq $pending -or
        @($pending.PSObject.Properties).Count -ne $fields.Count -or
        @($pending.PSObject.Properties.Name | Where-Object { $_ -cnotin $fields }).Count -ne 0 -or
        @($fields | Where-Object { $_ -cnotin @($pending.PSObject.Properties.Name) }).Count -ne 0 -or
        [string]$pending.launcherVersion -cnotmatch $canonical -or
        [string]$pending.contentVersion -cnotmatch $canonical -or
        [version]$pending.launcherVersion -le [version]$Settings.launcherVersion -or
        [version]$pending.contentVersion -lt [version]$Settings.contentVersion -or
        [string]$pending.archiveSha256 -cnotmatch '\A[a-fA-F0-9]{64}\z' -or
        ($pending.archiveSize -isnot [long] -and $pending.archiveSize -isnot [int]) -or
        [long]$pending.archiveSize -le 0 -or [long]$pending.archiveSize -gt 512MB) {
        Add-Failure 'Pending launcher release has unknown/missing fields or an invalid version/hash/size pin'
        return
    }

    $script:PendingReleaseValid = $true
    Add-Pass "Pending launcher $($pending.launcherVersion) has an exact reviewed archive pin"
}

function Test-PublicTree {
    param([Parameter(Mandatory)][string]$Root)

    $forbidden = [System.Collections.Generic.List[string]]::new()
    $textLeaks = [System.Collections.Generic.List[string]]::new()
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

        if ($file.Extension -in @('.md', '.ps1', '.json', '.yml', '.yaml', '.html', '.txt')) {
            $text = [System.IO.File]::ReadAllText($file.FullName)
            if ($text -match '(?i)C:\\Users\\PC(?:\\|/)|D:\\Project Rebirth(?:\\|/)|10\.50\.0\.(?:1|2)\b') {
                $textLeaks.Add($relative)
            }
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

    if ($textLeaks.Count -eq 0) {
        Add-Pass 'Public repository text contains no operator-local paths or private tunnel addresses'
    }
    else {
        foreach ($finding in $textLeaks) {
            Add-Failure "Private operator/path detail in public text: $finding"
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
    if ($Bootstrap.product -ne 'Project Reverie' -or $Bootstrap.channel -ne $Settings.channel) {
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
        [Parameter(Mandatory)]$RepositoryBootstrap,
        [Parameter(Mandatory)][string]$Version,
        [string]$ExpectedHash,
        [long]$ExpectedSize
    )

    $assetRoot = Join-Path $Root 'release-assets'
    $expectedName = "Project-Reverie-Launcher-$Version-win-x64.zip"
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
    if ($ExpectedHash -and ($actualHash -ine $ExpectedHash -or (Get-Item -LiteralPath $zipPath).Length -ne $ExpectedSize)) {
        Add-Failure 'Release-event launcher archive differs from its reviewed pending hash or size'
    }
    elseif ($ExpectedHash) {
        Add-Pass 'Release-event launcher archive matches its reviewed pending hash and size'
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    $temp = $null
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        $requiredEntries = @('ProjectReverie.Launcher.exe', 'launcher.bootstrap.json', 'PLAYER-GUIDE.md', 'README.md')
        $actualInventory = (@($entryNames | Sort-Object) -join '|')
        $requiredInventory = (@($requiredEntries | Sort-Object) -join '|')
        if ($actualInventory -cne $requiredInventory) {
            Add-Failure 'Launcher archive must contain exactly the four reviewed root files'
        }
        else {
            Add-Pass 'Launcher archive contains exactly the four reviewed root files'
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
        $launcherEntry = $archive.GetEntry('ProjectReverie.Launcher.exe')
        if ($null -ne $launcherEntry -and $launcherEntry.Length -gt 0 -and $launcherEntry.Length -le 250MB) {
            $temp = [IO.Directory]::CreateTempSubdirectory('reverie-public-launcher-pe-').FullName
            $temporaryExe = Join-Path $temp 'ProjectReverie.Launcher.exe'
            [IO.Compression.ZipFileExtensions]::ExtractToFile($launcherEntry, $temporaryExe, $false)
            if ((Get-Item -LiteralPath $temporaryExe).VersionInfo.FileVersion -cne ($Version + '.0')) {
                Add-Failure 'Launcher archive PE version differs from the requested release'
            }
            else {
                Add-Pass "Launcher archive PE version is $Version"
            }
        }
        else {
            Add-Failure 'Launcher executable is missing, empty, or oversized'
        }
        Add-Pass 'Launcher archive contains no bundled feed, client, MPQ, Data tree, credential, or private key'
    }
    finally {
        $archive.Dispose()
        if ($temp) {
            [IO.File]::Delete((Join-Path $temp 'ProjectReverie.Launcher.exe'))
            [IO.Directory]::Delete($temp, $false)
        }
    }
}

$DistributionRoot = [System.IO.Path]::GetFullPath($DistributionRoot)
Write-Host "Project Reverie public distribution validation (Rebirth realm): $DistributionRoot" -ForegroundColor Cyan

$settingsPath = Join-Path $DistributionRoot 'distribution.settings.json'
$settings = Get-JsonFile -Path $settingsPath
if ($null -eq $settings) {
    exit 1
}

Test-DistributionSettingsSchema -Settings $settings

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
    if ([string]$manifest.product -ne 'Project Reverie' -or
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
        $approvedManagedPath = $managedPath.StartsWith('Interface/AddOns/ProjectRebirthTooltips/', [System.StringComparison]::OrdinalIgnoreCase) -or
            $managedPath.StartsWith('Interface/AddOns/RebirthWardrobe/', [System.StringComparison]::OrdinalIgnoreCase)
        if (-not $approvedManagedPath -or
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
                Add-Failure 'Public verification key differs from the key pinned in the launcher'
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

$launcherFeedPath = Join-Path $channelRoot 'launcher.json'
$launcherSignaturePath = "$launcherFeedPath.sig"
if ((Test-Path -LiteralPath $launcherFeedPath) -or (Test-Path -LiteralPath $launcherSignaturePath)) {
    try {
        $bytes = [IO.File]::ReadAllBytes($launcherFeedPath)
        $signatureText = [IO.File]::ReadAllText($launcherSignaturePath).Trim()
        if ($bytes.Length -gt 16384 -or $signatureText.Length -gt 1024) { throw 'Launcher feed exceeds size limit.' }
        $key = [Security.Cryptography.ECDsa]::Create()
        try {
            $key.ImportFromPem([IO.File]::ReadAllText($publicKeyPath))
            if (-not $key.VerifyData($bytes, [Convert]::FromBase64String($signatureText), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.DSASignatureFormat]::IeeeP1363FixedFieldConcatenation)) { throw 'Launcher-release signature mismatch.' }
        } finally { $key.Dispose() }
        $launcherRelease = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
        $versionPattern = '\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\z'
        if ($launcherRelease.schemaVersion -ne 1 -or $launcherRelease.product -cne 'Project Reverie' -or $launcherRelease.channel -cne 'stable' -or $launcherRelease.latestVersion -cne $settings.launcherVersion) { throw 'Launcher feed identity/version mismatch.' }
        if ($launcherRelease.latestVersion -notmatch $versionPattern -or $launcherRelease.minimumSupportedVersion -notmatch $versionPattern -or [version]$launcherRelease.minimumSupportedVersion -gt [version]$launcherRelease.latestVersion) { throw 'Invalid launcher version range.' }
        $published = [DateTimeOffset]$launcherRelease.publishedAtUtc
        $expires = [DateTimeOffset]$launcherRelease.expiresAtUtc
        if ($published -gt [DateTimeOffset]::UtcNow.AddMinutes(10) -or $expires -le [DateTimeOffset]::UtcNow -or $expires -le $published) { throw 'Launcher feed is expired or has invalid timestamps.' }
        if ($launcherRelease.archiveSha256 -notmatch '\A[a-fA-F0-9]{64}\z' -or $launcherRelease.archiveSize -le 0 -or $launcherRelease.archiveSize -gt 512MB) { throw 'Invalid launcher archive fingerprint.' }
        if (-not $SkipReleaseAsset) {
            $archive = Join-Path $DistributionRoot "release-assets\Project-Reverie-Launcher-$($launcherRelease.latestVersion)-win-x64.zip"
            if ((Get-Item -LiteralPath $archive).Length -ne $launcherRelease.archiveSize -or (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ine $launcherRelease.archiveSha256) { throw 'Signed launcher fingerprint does not match the release ZIP.' }
        }
        Add-Pass "Independent launcher $($launcherRelease.latestVersion) feed signature, identity, expiry and archive fingerprint"
    } catch { Add-Failure "Launcher release verification failed: $($_.Exception.Message)" }
}
elseif ([version]$settings.launcherVersion -ge [version]'1.4.0') {
    Add-Failure 'Launcher 1.4.0+ requires the independent signed launcher-release feed.'
}

if ($ReleaseTag -and $null -ne $bootstrap) {
    if ($ReleaseTag -cnotmatch '\Alauncher-v(?<version>(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*))\z') {
        Add-Failure 'Release-event tag is not a canonical launcher tag'
    }
    else {
        $releaseVersion = $Matches.version
        $expectedHash = $null
        [long]$expectedSize = 0
        if ($script:PendingReleaseValid -and
            $settings.pendingRelease.launcherVersion -ceq $releaseVersion) {
            $expectedHash = [string]$settings.pendingRelease.archiveSha256
            $expectedSize = [long]$settings.pendingRelease.archiveSize
        }
        elseif ($settings.launcherVersion -cne $releaseVersion) {
            Add-Failure 'Release-event version is neither active nor the reviewed pending launcher'
        }
        Test-LauncherArchive -Root $DistributionRoot -Settings $settings -RepositoryBootstrap $bootstrap -Version $releaseVersion -ExpectedHash $expectedHash -ExpectedSize $expectedSize
    }
}
elseif (-not $SkipReleaseAsset -and $null -ne $bootstrap) {
    Test-LauncherArchive -Root $DistributionRoot -Settings $settings -RepositoryBootstrap $bootstrap -Version ([string]$settings.launcherVersion)
}

Write-Host ''
Write-Host "Result: $script:Passes passed, $($script:Failures.Count) failed" -ForegroundColor Cyan
if ($script:Failures.Count -gt 0) {
    exit 1
}
exit 0
