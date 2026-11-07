[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$modRoot = Join-Path $repoRoot 'mods-unpacked/Local-Isaac'
$modPrefix = 'mods-unpacked/Local-Isaac/'
$distRoot = Join-Path $repoRoot 'dist'
$manifest = Get-Content -LiteralPath (Join-Path $modRoot 'manifest.json') -Raw | ConvertFrom-Json
if ($manifest.namespace -ne 'Local' -or $manifest.name -ne 'Isaac') {
    throw 'Unexpected mod identity in manifest.json.'
}
$version = [string]$manifest.version_number
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Expected a numeric major.minor.patch version.' }
if (@($manifest.dependencies).Count -ne 0 -or
    @($manifest.extra.godot.compatible_game_version) -notcontains '1.2.0.1') {
    throw 'Expected the standalone Brotato 1.2.0.1 edition of Local-Isaac.'
}

$allowedExtensions = @('.gd', '.shader', '.json', '.md', '.png', '.import', '.tres', '.tscn')
$entries = @{}
$allFiles = @(Get-ChildItem -LiteralPath $modRoot -Recurse -File | Sort-Object FullName)
$allItems = @(Get-Item -LiteralPath $modRoot) + @(Get-ChildItem -LiteralPath $modRoot -Recurse -Force)
foreach ($item in $allItems) {
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Symbolic links and junctions are not allowed in the mod source tree.'
    }
}
foreach ($file in $allFiles) {
    if ($allowedExtensions -notcontains $file.Extension.ToLowerInvariant()) {
        throw ('Unexpected source file type: ' + $file.Name)
    }
    $relative = $file.FullName.Substring($modRoot.Length + 1).Replace('\', '/')
    $entries[$modPrefix + $relative] = $file.FullName
}

# Only import artifacts explicitly referenced by this mod can enter the ZIP.
foreach ($file in $allFiles | Where-Object Extension -EQ '.import') {
    $metadata = Get-Content -LiteralPath $file.FullName -Raw
    $matches = [regex]::Matches($metadata, 'res://(\.import/[^"\r\n]+)')
    if ($matches.Count -eq 0) { throw ('No imported texture reference: ' + $file.Name) }
    foreach ($match in $matches) {
        $relative = $match.Groups[1].Value
        if ($relative -notmatch '^\.import/[A-Za-z0-9_.-]+\.stex$') {
            throw ('Unexpected imported texture path: ' + $relative)
        }
        $source = Join-Path $repoRoot $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw ('Missing imported texture: ' + $relative)
        }
        if (((Get-Item -LiteralPath $source).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw ('Imported texture must be a regular file: ' + $relative)
        }
        $entries[$relative] = $source
    }
}

# Native res:// references are supplied by the game. Local references must exist.
foreach ($file in $allFiles | Where-Object Extension -In @('.gd', '.shader', '.tres', '.tscn', '.import')) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($match in [regex]::Matches($content, 'res://(mods-unpacked/Local-Isaac/[^"\r\n]+)')) {
        $relative = $match.Groups[1].Value
        # Scripts also construct paths dynamically; validate complete literals only.
        if ($relative.EndsWith('/') -or [System.IO.Path]::GetExtension($relative) -eq '') { continue }
        if ($relative.Contains('..') -or -not (Test-Path -LiteralPath (Join-Path $repoRoot $relative) -PathType Leaf)) {
            throw ('Missing or unsafe local resource reference: ' + $relative)
        }
    }
}

New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
$zipPath = Join-Path $distRoot ('Local-Isaac-' + $version + '.zip')
if ((Test-Path -LiteralPath $zipPath) -and -not $Force) {
    throw 'A package for this version already exists. Use -Force to rebuild it.'
}
$tempPath = Join-Path $distRoot ([System.Guid]::NewGuid().ToString('N') + '.tmp')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    $stream = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::CreateNew)
    try {
        $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($name in $entries.Keys | Sort-Object) {
                $entry = $archive.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [System.DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
                $inputStream = [System.IO.File]::OpenRead($entries[$name])
                try {
                    $entryStream = $entry.Open()
                    try { $inputStream.CopyTo($entryStream) } finally { $entryStream.Dispose() }
                } finally { $inputStream.Dispose() }
            }
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
    $check = [System.IO.Compression.ZipFile]::OpenRead($tempPath)
    try {
        if ($check.Entries.Count -ne $entries.Count) { throw 'Archive entry count does not match the input set.' }
    } finally { $check.Dispose() }
    Move-Item -LiteralPath $tempPath -Destination $zipPath -Force:$Force
} finally {
    if (Test-Path -LiteralPath $tempPath -PathType Leaf) { Remove-Item -LiteralPath $tempPath }
}
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$hashPath = $zipPath + '.sha256'
$hash + '  ' + [System.IO.Path]::GetFileName($zipPath) | Set-Content -LiteralPath $hashPath -Encoding ASCII
Write-Output ('Built Local-Isaac ' + $version + ': ' + $entries.Count + ' entries; SHA256 ' + $hash)
Write-Output $zipPath
