<#
Date Created: 2026-06-23
Version: 1.0
Last Updated: 2026-06-23
Changelog:
- 1.0 Initial version

Description:
Maintainer-only build script, not something end users run. Packages the
menu and the four install scripts into a single self-extracting .exe
using iexpress.exe (built into Windows, no extra tools needed). Running
the resulting .exe copies its contents to
%USERPROFILE%\Downloads\Godot Installer and launches
"Godot Install Menu.bat" from there. Intended to be attached to GitHub
Releases so non-technical users have one file to download and run.

How to run:
.\Build-SfxInstaller.ps1
Produces .\dist\Godot-Installer-Setup.exe

Email: 23248581+Makeea@users.noreply.github.com
GitHub: https://github.com/Makeea
#>

param(
	[string]$OutputPath = (Join-Path $PSScriptRoot 'dist\Godot-Installer-Setup.exe')
)

$filesToBundle = @(
	'Install-Godot.ps1'
	'Get-LatestGodot.ps1'
	'Get-LatestGodot-Force.ps1'
	'Get-GodotDocs.ps1'
	'Godot Install Menu.bat'
	'Godot Install Menu.ps1'
	'README.md'
	'LICENSE'
	'_bootstrap.bat'
)

$stage_dir	= Join-Path $env:TEMP 'Godot_Sfx_Stage'
$sed_path	= Join-Path $stage_dir 'GodotInstaller.sed'

if (Test-Path -LiteralPath $stage_dir) { Remove-Item -LiteralPath $stage_dir -Recurse -Force }
New-Item -ItemType Directory -Path $stage_dir -Force | Out-Null

foreach ($file in $filesToBundle) {
	$source = Join-Path $PSScriptRoot $file
	if (-not (Test-Path -LiteralPath $source)) {
		Write-Error "Missing file, can't build: $source"
		exit 1
	}
	Copy-Item -LiteralPath $source -Destination (Join-Path $stage_dir $file) -Force
}

$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }
if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }

$fileLines = for ($i = 0; $i -lt $filesToBundle.Count; $i++) { "FILE$i=`"$($filesToBundle[$i])`"" }
$sourceFileRefs = for ($i = 0; $i -lt $filesToBundle.Count; $i++) { "%FILE$i%=" }

$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$OutputPath
FriendlyName=Godot Installer
AppLaunched=_bootstrap.bat
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
$($fileLines -join "`r`n")
[SourceFiles]
SourceFiles0=$stage_dir
[SourceFiles0]
$($sourceFileRefs -join "`r`n")
"@

Set-Content -LiteralPath $sed_path -Value $sed -Encoding ASCII

Write-Host "Building $OutputPath ..."
& "$env:WINDIR\System32\iexpress.exe" /N $sed_path

# iexpress.exe returns before it has actually finished writing the file
# and doesn't give a reliable exit code, so poll for the file to show up
# and stop growing instead of trusting $LASTEXITCODE.
$lastSize = -1
$stableCount = 0
$deadline = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $deadline) {
	Start-Sleep -Seconds 1
	$item = Get-Item -LiteralPath $OutputPath -ErrorAction SilentlyContinue
	if ($item -and $item.Length -gt 0) {
		if ($item.Length -eq $lastSize) {
			$stableCount++
			if ($stableCount -ge 2) { break }
		} else {
			$stableCount = 0
		}
		$lastSize = $item.Length
	}
}

if (-not (Test-Path -LiteralPath $OutputPath) -or (Get-Item -LiteralPath $OutputPath).Length -eq 0) {
	Write-Error "iexpress did not produce an output file."
	exit 1
}

Write-Host "Done. Built $OutputPath"
