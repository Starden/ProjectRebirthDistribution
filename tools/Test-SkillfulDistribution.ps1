#requires -Version 7.2
[CmdletBinding()]
param([string]$DistributionRoot=(Split-Path -Parent $PSScriptRoot))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$channel=Join-Path $DistributionRoot 'site/skillful/stable'
$bytes=[IO.File]::ReadAllBytes((Join-Path $channel 'manifest.json'))
$signature=[IO.File]::ReadAllText((Join-Path $channel 'manifest.json.sig')).Trim()
if($bytes.Length -gt 1MB -or $signature.Length -gt 1024){throw 'Skillful metadata exceeds its size bound.'}
$key=[Security.Cryptography.ECDsa]::Create()
try{
    $key.ImportFromPem([IO.File]::ReadAllText((Join-Path $DistributionRoot 'site/update-signing-public-key.pem')))
    $pin='MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEO8fHaX+xO+04KDR7CaCaPqnuXMZv5BzPbSV9M2ArcR4qxZsSqSvQ5eeat17bt0jweCbe/Xu4wZgrk+6XG9bh2g=='
    if([Convert]::ToBase64String($key.ExportSubjectPublicKeyInfo()) -cne $pin -or
        -not $key.VerifyData($bytes,[Convert]::FromBase64String($signature),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.DSASignatureFormat]::IeeeP1363FixedFieldConcatenation)){
        throw 'Skillful signature or launcher-pinned verification key mismatch.'
    }
}finally{$key.Dispose()}
$manifest=[Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
$versionPattern='\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\z'
$settings=Get-Content -LiteralPath (Join-Path $DistributionRoot 'distribution.settings.json') -Raw | ConvertFrom-Json
if($manifest.schemaVersion -ne 1 -or $manifest.product -cne 'Project Skillful' -or $manifest.channel -cne 'stable' -or
    $manifest.contentEpoch -ne 0 -or $manifest.signatureAlgorithm -cne 'ECDSA_P256_SHA256_P1363' -or
    $manifest.contentVersion -cnotmatch $versionPattern -or $manifest.minimumLauncherVersion -cnotmatch $versionPattern -or
    [version]$manifest.minimumLauncherVersion -lt [version]'2.2.0' -or [version]$manifest.minimumLauncherVersion -gt [version]$settings.launcherVersion){
    throw 'Skillful identity, version, generation or required launcher mismatch.'
}
if($manifest.requiredWowBuild -ne 12340 -or $manifest.cleanWowSha256 -cne 'AA63A5750D60EF16746C686B3D5E26876D98953EAB08B1C026CD0FAF78E88CB8' -or
    $manifest.realm.name -cne 'Skillful' -or $manifest.realm.authAddress -cne '134.122.124.150' -or $manifest.realm.authPort -ne 3725 -or $manifest.realm.worldPort -ne 8085){
    throw 'Skillful client contract or approved public realm mismatch.'
}
$published=[DateTimeOffset]$manifest.publishedAtUtc
$expires=[DateTimeOffset]$manifest.expiresAtUtc
if($published -gt [DateTimeOffset]::UtcNow.AddMinutes(10) -or $expires -le [DateTimeOffset]::UtcNow -or $expires -le $published){throw 'Skillful feed timestamps are invalid or expired.'}
$prefix='Interface/AddOns/ProjectSkillful/'
$allowed=@('Equipment.lua','QuestRewards.lua','ProjectSkillful.lua','ProjectSkillful.toc','README.md') | ForEach-Object {$prefix+$_}
$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
if(@($manifest.files).Count -ne $allowed.Count){throw 'Skillful must contain exactly its five owned addon files.'}
foreach($entry in $manifest.files){
    if($entry.path -cnotin $allowed -or -not $seen.Add($entry.path) -or $entry.url -cne ('payload/'+$entry.path) -or
        $entry.size -le 0 -or $entry.size -gt 2MB -or $entry.sha256 -cnotmatch '\A[A-Fa-f0-9]{64}\z'){throw 'Unexpected, duplicate or unsafe Skillful payload.'}
    $path=Join-Path $channel $entry.url
    if((Get-Item -LiteralPath $path).Length -ne $entry.size -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $entry.sha256){throw 'Skillful payload fingerprint mismatch.'}
}
Write-Output "PASS Skillful signed feed: pinned key, identity, launcher minimum, expiry, public endpoint and all five payloads ($($manifest.contentVersion))"
