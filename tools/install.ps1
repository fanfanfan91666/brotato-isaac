param(
    [Parameter(Mandatory = $true)]
    [string]$GameRoot,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$isaacGame = (Resolve-Path -LiteralPath $GameRoot).Path
$isaacExe = Join-Path $isaacGame 'Brotato.exe'
if (-not (Test-Path -LiteralPath $isaacExe -PathType Leaf)) { throw 'Brotato.exe not found in GameRoot.' }
if (@(Get-Process -Name Brotato -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $isaacExe }).Count) {
    throw 'Close Brotato before installing.'
}
$isaacPackages = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter 'Local-Isaac-*.zip')
if ($isaacPackages.Count -ne 1) { throw 'Keep one Local-Isaac ZIP next to install.ps1.' }
$isaacZip = $isaacPackages[0]
$isaacArchive = [IO.Compression.ZipFile]::OpenRead($isaacZip.FullName)
try {
    $isaacEntry = $isaacArchive.GetEntry('mods-unpacked/Local-Isaac/manifest.json')
    if ($null -eq $isaacEntry) { throw 'Local-Isaac manifest not found in ZIP.' }
    $isaacReader = [IO.StreamReader]::new($isaacEntry.Open())
    try { $isaacManifest = $isaacReader.ReadToEnd() | ConvertFrom-Json } finally { $isaacReader.Dispose() }
    if ($isaacManifest.namespace -ne 'Local' -or $isaacManifest.name -ne 'Isaac' -or
        $isaacManifest.extra.godot.compatible_game_version -notcontains '1.2.0.1' -or @($isaacManifest.dependencies).Count) {
        throw 'This installer requires the standalone Brotato 1.2.0.1 edition of Local-Isaac.'
    }
} finally { $isaacArchive.Dispose() }
$isaacDigest = (Get-FileHash -LiteralPath $isaacZip.FullName -Algorithm SHA256).Hash
$isaacExpected = (Get-Content -LiteralPath ($isaacZip.FullName + '.sha256') -TotalCount 1).Split(' ')[0]
if ($isaacDigest -ne $isaacExpected) { throw 'ZIP checksum mismatch.' }

$isaacBridgeSource = Join-Path $PSScriptRoot 'isaac-local-loader.gd'
$isaacBridgeHash = (Get-FileHash -LiteralPath $isaacBridgeSource).Hash
$isaacOverride = Join-Path $isaacGame 'override.cfg'
$isaacBridge = Join-Path $isaacGame 'isaac-local-loader.gd'
$isaacOverrideText = if (Test-Path -LiteralPath $isaacOverride) { [IO.File]::ReadAllText($isaacOverride) } else { '' }
$isaacExisting = [regex]::Match($isaacOverrideText, '(?m)^ModLoader\s*=\s*"\*([^"]+)"')
if ($isaacExisting.Success) {
    $isaacBridge = $isaacExisting.Groups[1].Value
    if (-not (Test-Path -LiteralPath $isaacBridge -PathType Leaf) -or (Get-FileHash -LiteralPath $isaacBridge).Hash -ne $isaacBridgeHash) {
        throw 'The existing ModLoader override differs from this local ZIP loader.'
    }
} else {
    if ($isaacOverrideText -match '(?m)^\s*ModLoader\s*=') { throw 'Unrecognized ModLoader override.' }
    if ((Test-Path -LiteralPath $isaacBridge) -and (Get-FileHash -LiteralPath $isaacBridge).Hash -ne $isaacBridgeHash) {
        throw 'An unrelated isaac-local-loader.gd already exists.'
    }
    $isaacSetting = 'ModLoader="*' + $isaacBridge.Replace('\','/') + '"'
    $isaacSection = [regex]::Match($isaacOverrideText, '(?m)^\[autoload\][ \t]*\r?$')
    if ($isaacSection.Success) {
        $isaacOverrideText = $isaacOverrideText.Insert($isaacSection.Index + $isaacSection.Length, "`n" + $isaacSetting)
    } else {
        $isaacOverrideText += "`n[autoload]`n" + $isaacSetting + "`n"
    }
}

$isaacMods = Join-Path $isaacGame 'mods'
$isaacTarget = Join-Path $isaacMods $isaacZip.Name
$isaacProfile = Join-Path $env:APPDATA 'Brotato/mod_user_profiles.json'
$isaacConfig = if (Test-Path -LiteralPath $isaacProfile) {
    Get-Content -LiteralPath $isaacProfile -Raw | ConvertFrom-Json
} else {
    [pscustomobject]@{current_profile='default';profiles=[pscustomobject]@{default=[pscustomobject]@{mod_list=[pscustomobject]@{}}}}
}
$isaacCurrent = $isaacConfig.profiles.PSObject.Properties[$isaacConfig.current_profile]
if (-not $isaacCurrent -or -not $isaacCurrent.Value.mod_list) { throw 'Invalid current mod profile.' }
if ($CheckOnly) {
    [pscustomobject]@{Status='PreflightPassed';Version=$isaacManifest.version_number;Target=$isaacTarget;Profile=$isaacConfig.current_profile;SHA256=$isaacDigest}
    return
}

$isaacBackup = Join-Path $PSScriptRoot ('backups/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $isaacBackup, $isaacMods -Force | Out-Null
if (Test-Path -LiteralPath $isaacProfile) { Copy-Item -LiteralPath $isaacProfile -Destination (Join-Path $isaacBackup 'mod_user_profiles.before.json') }
if (Test-Path -LiteralPath $isaacOverride) { Copy-Item -LiteralPath $isaacOverride -Destination (Join-Path $isaacBackup 'override.before.cfg') }
foreach ($isaacOld in @(Get-ChildItem -LiteralPath $isaacMods -File -Filter 'Local-Isaac-*.zip')) {
    Move-Item -LiteralPath $isaacOld.FullName -Destination (Join-Path $isaacBackup $isaacOld.Name)
}
Copy-Item -LiteralPath $isaacZip.FullName -Destination $isaacTarget
if (-not $isaacExisting.Success) {
    Copy-Item -LiteralPath $isaacBridgeSource -Destination $isaacBridge
    [IO.File]::WriteAllText($isaacOverride, $isaacOverrideText, [Text.UTF8Encoding]::new($false))
}
$isaacCurrent.Value.mod_list | Add-Member -MemberType NoteProperty -Name 'Local-Isaac' -Value ([pscustomobject]@{is_active=$true;zip_path=$isaacTarget.Replace('\','/')}) -Force
New-Item -ItemType Directory -Path (Split-Path -Parent $isaacProfile) -Force | Out-Null
[IO.File]::WriteAllText($isaacProfile, ($isaacConfig | ConvertTo-Json -Depth 35), [Text.UTF8Encoding]::new($false))
[pscustomobject]@{Status='Installed';Version=$isaacManifest.version_number;Target=$isaacTarget;Profile=$isaacConfig.current_profile;Backup=$isaacBackup}
