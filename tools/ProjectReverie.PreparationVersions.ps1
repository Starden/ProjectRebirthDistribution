# Pure validation used before preparing or signing any release bytes.
function Get-ReveriePreparationVersions($Settings, [string]$ContentVersion,
    [string]$LauncherVersion, [int]$ContentEpoch, [bool]$EpochExplicit) {
    $taskCanonical='\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\z'
    foreach ($taskValue in @($ContentVersion,$LauncherVersion,$Settings.contentVersion,$Settings.launcherVersion)) {
        if ($taskValue -isnot [string] -or $taskValue -cnotmatch $taskCanonical) { throw 'Stable canonical release versions are required.' }
    }
    $taskActiveEpoch=0
    if ($Settings.PSObject.Properties['contentEpoch']) {
        $taskEpoch=$Settings.contentEpoch
        if (($taskEpoch -isnot [int] -and $taskEpoch -isnot [long]) -or $taskEpoch -notin @(0,1)) { throw 'Invalid active content epoch.' }
        $taskActiveEpoch=[int]$taskEpoch
    }
    if (-not $EpochExplicit) { $ContentEpoch=$taskActiveEpoch }
    if ($ContentEpoch -notin @(0,1) -or $ContentEpoch -lt $taskActiveEpoch -or
        ($ContentEpoch -eq $taskActiveEpoch -and [version]$ContentVersion -le [version]$Settings.contentVersion)) {
        throw 'Prepared content must advance the active signed feed without an epoch rollback.'
    }
    if ([version]$LauncherVersion -le [version]$Settings.launcherVersion) { throw 'Prepared launcher must advance the active launcher.' }
    if ($ContentEpoch -eq 1 -and [version]$LauncherVersion -lt [version]'2.0.0') { throw 'Content epoch one requires launcher 2.0.0 or later.' }
    return [pscustomobject]@{contentVersion=$ContentVersion;launcherVersion=$LauncherVersion;contentEpoch=$ContentEpoch}
}
