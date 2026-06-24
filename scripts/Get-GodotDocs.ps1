<#
Date Created: 2026-06-23
Version: 1.0
Last Updated: 2026-06-23
Changelog:
- 1.0 Initial version

Description:
Downloads the official prebuilt offline HTML documentation for Godot
Engine (rendered pages, not the raw .rst source) and attaches it to an
already installed version, updating the "Godot Docs (Local)" Start Menu
shortcut to open it directly. The docs are pulled from the same build
that godotengine/godot-docs publishes for offline reading, refreshed
weekly.

How to run:
1) Run PowerShell as Administrator.
2) Install a Godot version first with Install-Godot.ps1 or
   Get-LatestGodot.ps1, then execute:
   .\Get-GodotDocs.ps1
   If more than one version is installed, pass -GodotVersion to say
   which one to attach the docs to.

Use -Destination instead of -GodotVersion to just download and extract
the docs to a folder of your choice, for example to bundle a "docs-html"
folder alongside a build before running Install-Godot.ps1.

Email: 23248581+Makeea@users.noreply.github.com
GitHub: https://github.com/Makeea
#>

param(
	[ValidateSet('stable', 'latest', '3.6')]
	[string]$DocsVersion = 'stable',
	[string]$GodotVersion,
	[string]$InstallRoot = "$env:ProgramFiles\Godot",
	[string]$Destination
)

# Settings
$log_dir	= Join-Path (Get-Location) "logs"
$log_path	= Join-Path $log_dir "godot_docs_install.log"
$stage_dir	= Join-Path $env:TEMP "Godot_Docs_Download"
$headers	= @{ 'User-Agent' = 'Get-GodotDocs-Script' }
$docsZipUrl	= "https://nightly.link/godotengine/godot-docs/workflows/build_offline_docs/master/godot-docs-html-$DocsVersion.zip"

# Admin check
$wi = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($wi)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Error "Run this script as Administrator."
	exit 1
}

# Logging
if (-not (Test-Path -LiteralPath $log_dir)) { New-Item -ItemType Directory -Path $log_dir | Out-Null }
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Start docs download" | Out-File -FilePath $log_path -Encoding utf8

function log {
	param([string]$msg)
	$line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
	Write-Host $line
	$line | Out-File -Append -FilePath $log_path -Encoding utf8
}

function New-Shortcut {
	param(
		[Parameter(Mandatory)] [string]$Path,
		[Parameter(Mandatory)] [string]$Target
	)
	$shell = New-Object -ComObject WScript.Shell
	$shortcut = $shell.CreateShortcut($Path)
	$shortcut.TargetPath = $Target
	$shortcut.Save()
}

# Work out where the extracted docs should land
$attachToInstall = -not $Destination
if ($attachToInstall) {
	if (-not $GodotVersion) {
		$installed = Get-ChildItem -LiteralPath $InstallRoot -Directory -ErrorAction SilentlyContinue
		if ($installed.Count -eq 1) {
			$GodotVersion = $installed[0].Name
			log "Auto-detected installed Godot version $GodotVersion"
		} elseif ($installed.Count -eq 0) {
			log "ERROR: No Godot version found under $InstallRoot. Install one first, or pass -Destination to just download the docs somewhere."
			exit 1
		} else {
			log "ERROR: Multiple Godot versions found under $InstallRoot ($($installed.Name -join ', ')). Pass -GodotVersion to pick one."
			exit 1
		}
	}
	$targetDir = Join-Path (Join-Path $InstallRoot $GodotVersion) 'docs-html'
} else {
	$targetDir = $Destination
}

# Download
if (Test-Path -LiteralPath $stage_dir) { Remove-Item -LiteralPath $stage_dir -Recurse -Force }
New-Item -ItemType Directory -Path $stage_dir -Force | Out-Null
$zipPath = Join-Path $stage_dir "godot-docs-html-$DocsVersion.zip"

log "Downloading offline docs ($DocsVersion) from $docsZipUrl ..."
try {
	Invoke-WebRequest -Uri $docsZipUrl -OutFile $zipPath -Headers $headers
} catch {
	log "ERROR: Failed to download the docs archive: $_"
	exit 1
}

# Extract straight into the target folder
log "Extracting docs to $targetDir ..."
if (Test-Path -LiteralPath $targetDir) { Remove-Item -LiteralPath $targetDir -Recurse -Force }
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $targetDir -Force
Remove-Item -LiteralPath $zipPath -Force

$indexPath = Join-Path $targetDir 'index.html'
if (-not (Test-Path -LiteralPath $indexPath)) {
	log "ERROR: index.html not found in extracted docs at $targetDir"
	exit 1
}

if ($attachToInstall) {
	$startMenuDir = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Godot $GodotVersion"
	New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
	$docsLocalLnk = Join-Path $startMenuDir 'Godot Docs (Local).lnk'
	log "Creating Start Menu shortcut $docsLocalLnk"
	New-Shortcut -Path $docsLocalLnk -Target $indexPath
	log "Done. Local docs for Godot $GodotVersion are at $targetDir"
} else {
	log "Done. Docs extracted to $targetDir"
}
