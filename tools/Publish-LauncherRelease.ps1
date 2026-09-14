#requires -Version 7.2

[CmdletBinding()]
param(
    [string]$DistributionRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

throw @'
This public-checkout publisher is intentionally disabled. It does not implement
the required pending-release pin, clean reviewed commit, unpublished draft,
uploaded-asset digest verification, and anonymous-download gate. Use the
protected workstation's canonical Project Reverie GitHub release publisher,
passing this public checkout as DistributionRoot and the exact x.y.z Version.
'@
