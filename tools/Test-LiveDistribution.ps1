#requires -Version 7.2

[CmdletBinding()]
param(
    [string]$DistributionRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$settings = [System.IO.File]::ReadAllText((Join-Path $DistributionRoot 'distribution.settings.json')) | ConvertFrom-Json
$manifestUri = [Uri]::new([Uri]$settings.pagesBaseUri, "$($settings.channel)/manifest.json")
$signatureUri = [Uri]::new([Uri]$settings.pagesBaseUri, "$($settings.channel)/manifest.json.sig")
$publicKeyPem = [System.IO.File]::ReadAllText((Join-Path $DistributionRoot 'site\update-signing-public-key.pem'))
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(30)
try {
    $manifestBytes = $client.GetByteArrayAsync($manifestUri).GetAwaiter().GetResult()
    $signatureText = $client.GetStringAsync($signatureUri).GetAwaiter().GetResult().Trim()
    $signatureBytes = [Convert]::FromBase64String($signatureText)
    $key = [System.Security.Cryptography.ECDsa]::Create()
    try {
        $key.ImportFromPem($publicKeyPem)
        if (-not $key.VerifyData(
            $manifestBytes,
            $signatureBytes,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.DSASignatureFormat]::IeeeP1363FixedFieldConcatenation)) {
            throw 'The live detached signature does not match the exact live manifest bytes.'
        }
    }
    finally {
        $key.Dispose()
    }

    $manifest = [System.Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
    if ([string]$manifest.realm.authAddress -cne '134.122.124.150') {
        throw "The live feed advertises an unexpected realm endpoint: $($manifest.realm.authAddress)"
    }
    foreach ($entry in @($manifest.files)) {
        $payloadUri = [Uri]::new($manifestUri, [string]$entry.url)
        if ($payloadUri.Scheme -ne 'https' -or $payloadUri.Host -cne $manifestUri.Host -or
            -not $payloadUri.AbsolutePath.StartsWith($manifestUri.AbsolutePath.Substring(0, $manifestUri.AbsolutePath.LastIndexOf('/') + 1), [System.StringComparison]::Ordinal)) {
            throw "A live payload URL escapes the signed HTTPS channel: $payloadUri"
        }
        $bytes = $client.GetByteArrayAsync($payloadUri).GetAwaiter().GetResult()
        $hash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
        if ($bytes.LongLength -ne [Int64]$entry.size -or $hash -cne ([string]$entry.sha256).ToUpperInvariant()) {
            throw "Live payload size or hash mismatch: $($entry.path)"
        }
        Write-Host "PASS: $($entry.path)" -ForegroundColor Green
    }
    Write-Host "PASS: live signed HTTPS distribution is internally consistent at $manifestUri" -ForegroundColor Green
}
finally {
    $client.Dispose()
}
