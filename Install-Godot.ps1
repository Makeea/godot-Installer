<#
Date Created: 2026-06-23
Version: 1.0
Last Updated: 2026-06-23
Changelog:
- 1.0 Initial version

Description:
"Soft installs" a portable Godot Engine build: copies the chosen build(s)
into Program Files under a version-specific folder (so multiple versions
can coexist without ever auto-updating), then creates all-users Desktop
and Start Menu shortcuts for the app, the install folder, and the docs.

How to run:
1) Point -SourcePath at a folder containing a Godot version's build files
   (the extracted exe folder(s) and/or .zip(s), e.g. "Godot v4.7"),
   optionally alongside a "docs-html" folder holding the rendered offline
   documentation (see Get-GodotDocs.ps1).
2) Run PowerShell as Administrator.
3) Execute: .\Install-Godot.ps1 -SourcePath "C:\path\to\Godot v4.7"

Email: 23248581+Makeea@users.noreply.github.com
GitHub: https://github.com/Makeea
#>

param(
	[string]$SourcePath = $PSScriptRoot,
	[ValidateSet('Standard', 'Mono', 'Both')]
	[string]$Variant = 'Both',
	[string]$InstallRoot = "$env:ProgramFiles\Godot",
	[string]$DocsUrl = "https://docs.godotengine.org/en/stable/"
)

# Settings
$log_dir	= Join-Path (Get-Location) "logs"
$log_path	= Join-Path $log_dir "godot_install.log"
$stage_dir	= Join-Path $env:TEMP "Godot_Install_Stage"

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

# Find a build of the given variant in $SourcePath; expands a .zip into
# $stage_dir if no extracted copy is found. Returns the folder containing
# the matching .exe, or $null if the variant isn't present at all.
function Find-Build {
	param([ValidateSet('Standard', 'Mono')] [string]$BuildVariant)

	$pattern = if ($BuildVariant -eq 'Mono') { 'Godot_v[\d.]+-stable_mono_win64' } else { 'Godot_v[\d.]+-stable_win64' }

	$exeMatch = Get-ChildItem -LiteralPath $SourcePath -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -match "^$pattern\.exe$" } |
		Select-Object -First 1
	if ($exeMatch) { return $exeMatch.Directory.FullName }

	$zipMatch = Get-ChildItem -LiteralPath $SourcePath -Filter '*.zip' -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -match "^$pattern\.exe\.zip$" } |
		Select-Object -First 1
	if (-not $zipMatch) { return $null }

	$dest = Join-Path $stage_dir $BuildVariant
	if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
	New-Item -ItemType Directory -Path $dest -Force | Out-Null
	log "Expanding $($zipMatch.Name) ..."
	Expand-Archive -LiteralPath $zipMatch.FullName -DestinationPath $dest -Force

	$exeMatch = Get-ChildItem -LiteralPath $dest -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -match "^$pattern\.exe$" } |
		Select-Object -First 1
	if ($exeMatch) { return $exeMatch.Directory.FullName }
	return $null
}

# Determine which variants to install
$variantsToInstall = switch ($Variant) {
	'Standard' { @('Standard') }
	'Mono'     { @('Mono') }
	'Both'     { @('Standard', 'Mono') }
}

# Locate builds and figure out the version number
$builds = @{}
$version = $null
foreach ($v in $variantsToInstall) {
	$folder = Find-Build -BuildVariant $v
	if (-not $folder) {
		log "ERROR: Could not find a $v build (.exe or .zip) under $SourcePath"
		exit 1
	}
	$exeName = (Get-ChildItem -LiteralPath $folder -Filter '*.exe' | Where-Object { $_.Name -notmatch '_console\.exe$' } | Select-Object -First 1).Name
	if ($exeName -match 'Godot_v(?<ver>[\d.]+)-stable') { $version = $matches['ver'] }
	$builds[$v] = $folder
	log "Found $v build for version $version at $folder"
}

if (-not $version) {
	log "ERROR: Could not determine Godot version from build filenames."
	exit 1
}

# Copy builds into the install root, versioned so multiple installs coexist
$versionRoot = Join-Path $InstallRoot $version
$installedExes = @{}
foreach ($v in $builds.Keys) {
	$destDir = Join-Path $versionRoot $v
	log "Installing $v build to $destDir"
	if (Test-Path -LiteralPath $destDir) { Remove-Item -LiteralPath $destDir -Recurse -Force }
	New-Item -ItemType Directory -Path $destDir -Force | Out-Null
	Copy-Item -Path (Join-Path $builds[$v] '*') -Destination $destDir -Recurse -Force

	$exe = Get-ChildItem -LiteralPath $destDir -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch '_console\.exe$' } | Select-Object -First 1
	$installedExes[$v] = $exe.FullName
}

# Optional local rendered docs (see Get-GodotDocs.ps1)
$docsSource = Join-Path $SourcePath 'docs-html'
$localDocsIndex = $null
if (Test-Path -LiteralPath (Join-Path $docsSource 'index.html')) {
	$localDocsDir = Join-Path $versionRoot 'docs-html'
	log "Copying local docs to $localDocsDir"
	if (Test-Path -LiteralPath $localDocsDir) { Remove-Item -LiteralPath $localDocsDir -Recurse -Force }
	Copy-Item -Path $docsSource -Destination $localDocsDir -Recurse -Force
	$localDocsIndex = Join-Path $localDocsDir 'index.html'
} else {
	log "No docs-html folder found in $SourcePath; skipping local docs shortcut."
}

# Shortcut labels per variant
$labels = @{ Standard = "Godot $version"; Mono = "Godot $version (Mono)" }

# All-users Desktop shortcuts (app launchers only)
$desktopDir = Join-Path $env:Public 'Desktop'
foreach ($v in $installedExes.Keys) {
	$lnkPath = Join-Path $desktopDir "$($labels[$v]).lnk"
	log "Creating Desktop shortcut $lnkPath"
	New-Shortcut -Path $lnkPath -Target $installedExes[$v] -WorkingDirectory (Split-Path $installedExes[$v])
}

# All-users Start Menu folder with app launchers + install folder + docs
$startMenuDir = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Godot $version"
New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null

foreach ($v in $installedExes.Keys) {
	$lnkPath = Join-Path $startMenuDir "$($labels[$v]).lnk"
	log "Creating Start Menu shortcut $lnkPath"
	New-Shortcut -Path $lnkPath -Target $installedExes[$v] -WorkingDirectory (Split-Path $installedExes[$v])
}

$openFolderLnk = Join-Path $startMenuDir 'Open Install Folder.lnk'
log "Creating Start Menu shortcut $openFolderLnk"
New-Shortcut -Path $openFolderLnk -Target $versionRoot

$docsOnlineLnk = Join-Path $startMenuDir 'Godot Docs (Online).url'
log "Creating Start Menu shortcut $docsOnlineLnk"
New-UrlShortcut -Path $docsOnlineLnk -Url $DocsUrl

if ($localDocsIndex) {
	$docsLocalLnk = Join-Path $startMenuDir 'Godot Docs (Local).lnk'
	log "Creating Start Menu shortcut $docsLocalLnk"
	New-Shortcut -Path $docsLocalLnk -Target $localDocsIndex
}

log "Done. Installed Godot $version ($($installedExes.Keys -join ', ')) to $versionRoot"
