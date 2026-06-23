<#
Date Created: 2026-06-23
Version: 1.0
Last Updated: 2026-06-23
Changelog:
- 1.0 Initial version

Description:
Fully self-contained script that fetches the LATEST stable Godot Engine
release straight from GitHub (godotengine/godot), verifies its SHA512
checksum, and "soft installs" it the same way Install-Godot.ps1 does:
a version-specific folder under Program Files plus all-users Desktop and
Start Menu shortcuts. Unlike Get-LatestGodot.ps1, this ALWAYS re-downloads
and overwrites that version's install, even if it's already present --
use this when you want to be sure the files on disk are untampered/fresh
rather than trusting whatever is already there.

How to run:
1) Run PowerShell as Administrator.
2) Execute: .\Get-LatestGodot-Force.ps1

Email: 23248581+Makeea@users.noreply.github.com
GitHub: https://github.com/Makeea
#>

param(
	[ValidateSet('Standard', 'Mono', 'Both')]
	[string]$Variant = 'Both',
	[string]$InstallRoot = "$env:ProgramFiles\Godot",
	[string]$DocsUrl = "https://docs.godotengine.org/en/stable/",
	[string]$RepoApi = "https://api.github.com/repos/godotengine/godot/releases/latest"
)

# Settings
$log_dir	= Join-Path (Get-Location) "logs"
$log_path	= Join-Path $log_dir "godot_latest_force_install.log"
$stage_dir	= Join-Path $env:TEMP "Godot_Latest_Force_Download"
$headers	= @{ 'User-Agent' = 'Get-LatestGodot-Force-Script' }

# Admin check
$wi = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($wi)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Error "Run this script as Administrator."
	exit 1
}

# Logging
if (-not (Test-Path -LiteralPath $log_dir)) { New-Item -ItemType Directory -Path $log_dir | Out-Null }
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Start install" | Out-File -FilePath $log_path -Encoding utf8

function log {
	param([string]$msg)
	$line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
	Write-Host $line
	$line | Out-File -Append -FilePath $log_path -Encoding utf8
}

function New-Shortcut {
	param(
		[Parameter(Mandatory)] [string]$Path,
		[Parameter(Mandatory)] [string]$Target,
		[string]$WorkingDirectory
	)
	$shell = New-Object -ComObject WScript.Shell
	$shortcut = $shell.CreateShortcut($Path)
	$shortcut.TargetPath = $Target
	if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
	$shortcut.Save()
}

function New-UrlShortcut {
	param(
		[Parameter(Mandatory)] [string]$Path,
		[Parameter(Mandatory)] [string]$Url
	)
	"[InternetShortcut]`r`nURL=$Url" | Out-File -FilePath $Path -Encoding ascii
}

# Determine which variants to install
$variantsToInstall = switch ($Variant) {
	'Standard' { @('Standard') }
	'Mono'     { @('Mono') }
	'Both'     { @('Standard', 'Mono') }
}

# Query GitHub for the latest stable release
log "Querying $RepoApi for the latest release..."
try {
	$release = Invoke-RestMethod -Uri $RepoApi -Headers $headers
} catch {
	log "ERROR: Failed to query GitHub API: $_"
	exit 1
}
$version = $release.tag_name -replace '-stable$', ''
log "Latest stable release is Godot $version"

$versionRoot = Join-Path $InstallRoot $version

# Asset name per variant, matching Godot's official release naming
$assetNames = @{
	Standard = "Godot_v$version-stable_win64.exe.zip"
	Mono     = "Godot_v$version-stable_mono_win64.zip"
}

if (Test-Path -LiteralPath $stage_dir) { Remove-Item -LiteralPath $stage_dir -Recurse -Force }
New-Item -ItemType Directory -Path $stage_dir -Force | Out-Null

# Download the checksum manifest once
$sumsAsset = $release.assets | Where-Object { $_.name -eq 'SHA512-SUMS.txt' } | Select-Object -First 1
$sumsText = $null
if ($sumsAsset) {
	$sumsPath = Join-Path $stage_dir 'SHA512-SUMS.txt'
	Invoke-WebRequest -Uri $sumsAsset.browser_download_url -OutFile $sumsPath -Headers $headers
	$sumsText = Get-Content -LiteralPath $sumsPath -Raw
} else {
	log "WARNING: SHA512-SUMS.txt not found in release assets; downloads will not be checksum-verified."
}

$installedExes = @{}

foreach ($v in $variantsToInstall) {
	$assetName = $assetNames[$v]
	$asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
	if (-not $asset) {
		log "ERROR: Could not find release asset '$assetName' for Godot $version."
		exit 1
	}

	$zipPath = Join-Path $stage_dir $assetName
	log "Downloading $assetName ..."
	Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -Headers $headers

	if ($sumsText) {
		if ($sumsText -match "(?m)^([0-9a-fA-F]{128})\s+$([regex]::Escape($assetName))\s*$") {
			$expected = $matches[1]
			$actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA512).Hash
			if ($actual -ne $expected) {
				log "ERROR: Checksum mismatch for $assetName. Expected $expected, got $actual."
				exit 1
			}
			log "Checksum verified for $assetName"
		} else {
			log "WARNING: No checksum entry found for $assetName; skipping verification."
		}
	}

	$extractDir = Join-Path $stage_dir $v
	log "Expanding $assetName ..."
	Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

	$destDir = Join-Path $versionRoot $v
	log "Installing $v build to $destDir (overwriting if present)"
	if (Test-Path -LiteralPath $destDir) { Remove-Item -LiteralPath $destDir -Recurse -Force }
	New-Item -ItemType Directory -Path $destDir -Force | Out-Null
	Copy-Item -Path (Join-Path $extractDir '*') -Destination $destDir -Recurse -Force

	$exe = Get-ChildItem -LiteralPath $destDir -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch '_console\.exe$' } | Select-Object -First 1
	$installedExes[$v] = $exe.FullName
}

# Shortcut labels per variant
$labels = @{ Standard = "Godot $version"; Mono = "Godot $version (Mono)" }

# All-users Desktop shortcuts (app launchers only)
$desktopDir = Join-Path $env:Public 'Desktop'
foreach ($v in $installedExes.Keys) {
	$lnkPath = Join-Path $desktopDir "$($labels[$v]).lnk"
	log "Recreating Desktop shortcut $lnkPath"
	New-Shortcut -Path $lnkPath -Target $installedExes[$v] -WorkingDirectory (Split-Path $installedExes[$v])
}

# All-users Start Menu folder with app launchers + install folder + online docs
$startMenuDir = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Godot $version"
New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null

foreach ($v in $installedExes.Keys) {
	$lnkPath = Join-Path $startMenuDir "$($labels[$v]).lnk"
	log "Recreating Start Menu shortcut $lnkPath"
	New-Shortcut -Path $lnkPath -Target $installedExes[$v] -WorkingDirectory (Split-Path $installedExes[$v])
}

$openFolderLnk = Join-Path $startMenuDir 'Open Install Folder.lnk'
log "Recreating Start Menu shortcut $openFolderLnk"
New-Shortcut -Path $openFolderLnk -Target $versionRoot

$docsOnlineLnk = Join-Path $startMenuDir 'Godot Docs (Online).url'
log "Recreating Start Menu shortcut $docsOnlineLnk"
New-UrlShortcut -Path $docsOnlineLnk -Url $DocsUrl

log "Done. Godot $version ($($installedExes.Keys -join ', ')) re-downloaded and installed at $versionRoot"
