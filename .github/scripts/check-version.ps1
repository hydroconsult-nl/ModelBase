<#
Checks that every place that states this repository's version agrees (see VERSIONING.md).

  -Sources  one or more "kind=path" entries, path relative to the repository root:
              assemblyinfo  AssemblyFileVersion in AssemblyInfo.vb / AssemblyInfo.cs
              msbuild       <Version> (else <FileVersion>/<AssemblyVersion>) in a .vbproj/.csproj
              iss           #define MyAppVersion in an Inno Setup script
              releasenotes  the first line that starts with "v<number>" in the release notes

Only Major.Minor.Patch is compared; the fourth number is the build number and may differ.

On a release (a tag vX.Y.Z, or a pull request from a branch release/vX.Y.Z) the check is strict:
every source must match the tag/branch version, and that version must be higher than every
existing vX.Y.Z tag. On other builds a mismatch is reported as a warning only, so that a
repository whose files disagree today keeps building until its next release.
#>
param(
    [Parameter(Mandatory)][string[]]$Sources,
    [string]$RefType = $env:GITHUB_REF_TYPE,   # 'tag' or 'branch'
    [string]$RefName = $env:GITHUB_REF_NAME,   # tag name or branch name
    [string]$HeadRef = $env:GITHUB_HEAD_REF    # source branch of a pull request
)
$ErrorActionPreference = 'Stop'

function ConvertTo-Version([string]$text) {
    # '3.5.1.0' / 'v 3.5.1' / '3.2.0-beta.1' -> [version] 3.5.1 (Major.Minor.Patch)
    $m = [regex]::Match($text, '^\s*v?\s*(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-[0-9A-Za-z.-]+)?\s*:?\s*$')
    if (-not $m.Success) { return $null }
    $patch = if ($m.Groups[3].Success) { [int]$m.Groups[3].Value } else { 0 }
    [version]::new([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, $patch)
}

function Get-SourceVersion([string]$kind, [string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Version source not found: $path" }
    $lines = Get-Content -LiteralPath $path   # detects UTF-8 / UTF-16 by the byte order mark
    $raw = switch ($kind) {
        'assemblyinfo' {
            $l = $lines | Where-Object { $_ -match '^\s*[<\[]\s*[Aa]ssembly\s*:\s*AssemblyFileVersion\s*\(\s*"([^"]+)"' } | Select-Object -First 1
            if ($l) { $Matches[1] }
        }
        'msbuild' {
            $x = [xml]($lines -join "`n")
            $groups = @($x.Project.PropertyGroup)
            foreach ($tag in 'Version', 'FileVersion', 'AssemblyVersion') {
                $v = $groups | ForEach-Object { $_.$tag } | Where-Object { $_ -is [string] -and $_ } | Select-Object -First 1
                if ($v) { $v; break }
            }
        }
        'iss' {
            $l = $lines | Where-Object { $_ -match '^\s*#define\s+MyAppVersion\s+"([^"]+)"' } | Select-Object -First 1
            if ($l) { $Matches[1] }
        }
        'releasenotes' {
            $l = $lines | Where-Object { $_ -match '^\s*v\s*(\d+(?:\.\d+){1,3}(?:-[0-9A-Za-z.-]+)?)' } | Select-Object -First 1
            if ($l) { $Matches[1] }
        }
        default { throw "Unknown source kind '$kind' (use assemblyinfo, msbuild, iss or releasenotes)" }
    }
    if (-not $raw) { throw "No version found in $path ($kind)" }
    [pscustomobject]@{ Source = "$kind=$path"; Raw = "$raw".Trim(); Version = (ConvertTo-Version "$raw") }
}

# ---- what does this repository say? ----
$found = foreach ($s in $Sources) {
    $kind, $path = $s -split '=', 2
    Get-SourceVersion $kind.Trim().ToLowerInvariant() $path.Trim()
}
$found | ForEach-Object { '{0,-14} {1,-12} {2}' -f ($_.Source -split '=')[0], $_.Raw, ($_.Source -split '=', 2)[1] }

# ---- is this a release? ----
$expectedText = $null
if ($RefType -eq 'tag' -and $RefName -match '^v\d') { $expectedText = $RefName; $why = "tag $RefName" }
elseif ($HeadRef -match '^release/(v\d.*)$') { $expectedText = $Matches[1]; $why = "pull request from $HeadRef" }
elseif ($RefType -eq 'branch' -and $RefName -match '^release/(v\d.*)$') { $expectedText = $Matches[1]; $why = "branch $RefName" }
$release = [bool]$expectedText

$problems = New-Object Collections.Generic.List[string]
foreach ($f in $found) {
    if (-not $f.Version) { $problems.Add("$($f.Source): '$($f.Raw)' is not a version of the form Major.Minor.Patch[.Build]") }
}
$versions = @($found | Where-Object Version | ForEach-Object { $_.Version.ToString() } | Sort-Object -Unique)
if ($versions.Count -gt 1) { $problems.Add("The sources disagree: $($versions -join ' / ')") }

if ($release) {
    $expected = ConvertTo-Version $expectedText
    if (-not $expected) { $problems.Add("$why does not name a version of the form vMajor.Minor.Patch") }
    else {
        foreach ($f in $found | Where-Object Version) {
            if ($f.Version -ne $expected) { $problems.Add("$($f.Source) says $($f.Version), the $why says $expected") }
        }
        # the new version must be higher than every version already released
        # only final releases count (v3.2.0, v2.5.5.3), not pre-releases such as v3.2.0-beta.1
        $tags = @(git tag --list 'v*' 2>$null) | Where-Object { $_ -ne $RefName -and $_ -match '^v\d+(\.\d+){1,3}$' }
        $older = $tags | ForEach-Object { ConvertTo-Version $_ } | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
        if ($older -and $expected -le $older) { $problems.Add("Version $expected is not higher than the latest release tag v$older") }
        elseif ($older) { "Latest release tag: v$older" }
    }
}

if ($problems.Count -eq 0) {
    "Version check passed: $($versions -join '')" + $(if ($release) { " ($why)" } else { '' })
    exit 0
}
foreach ($p in $problems) {
    if ($release) { Write-Output "::error::$p" } else { Write-Output "::warning::$p" }
}
if ($release) {
    Write-Output "Version check failed for a release ($why). See VERSIONING.md."
    exit 1
}
Write-Output "Version check: warnings only (not a release build). Fix these before the next release; see VERSIONING.md."
exit 0
