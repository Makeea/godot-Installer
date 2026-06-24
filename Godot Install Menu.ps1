<#
Date Created: 2026-06-23
Version: 1.0
Last Updated: 2026-06-23
Changelog:
- 1.0 Initial version

Description:
Double-click entry point for people who do not use PowerShell. Auto
elevates to Administrator, then shows a plain numbered menu that wraps
Install-Godot.ps1, Get-LatestGodot.ps1, Get-LatestGodot-Force.ps1, and
Get-GodotDocs.ps1 so nobody has to know script names or parameters.

How to run:
Double-click "Godot Install Menu.bat" in this same folder. Do not
double-click this .ps1 file directly, Windows will try to open it in a
text editor instead of running it.

Email: 23248581+Makeea@users.noreply.github.com
GitHub: https://github.com/Makeea
#>

function Test-IsElevated {
	$wi = [Security.Principal.WindowsIdentity]::GetCurrent()
	$pr = New-Object Security.Principal.WindowsPrincipal($wi)
	return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsElevated)) {
	try {
		Start-Process -FilePath 'powershell.exe' -WorkingDirectory $PSScriptRoot -Verb RunAs -ErrorAction Stop -ArgumentList @(
			'-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
		) | Out-Null
	} catch {
		Write-Host ""
		Write-Host "Elevation was cancelled, so the installer can't continue." -ForegroundColor Yellow
		Write-Host "This tool needs to run as Administrator to install Godot." -ForegroundColor Yellow
		Write-Host ""
		Write-Host "Press Enter to close this window..."
		[void][System.Console]::ReadLine()
	}
	exit
}

# Settings
$install_root	= "$env:ProgramFiles\Godot"
$docs_url	= "https://docs.godotengine.org/en/stable/"

Add-Type -AssemblyName System.Windows.Forms

function Show-Menu {
	Write-Host "========================================"
	Write-Host "  Godot Install Menu  (running as Administrator)"
	Write-Host "========================================"
	Write-Host ""
	Write-Host "  1) Install everything (latest Godot, Mono, and offline docs)"
	Write-Host "  2) Download and install the latest Godot from the internet"
	Write-Host "  3) Install Godot from a folder on this computer"
	Write-Host "  4) Download offline help docs for an installed Godot"
	Write-Host "  5) Open the logs folder"
	Write-Host "  6) Exit"
	Write-Host ""
}

function Read-MenuChoice {
	param([Parameter(Mandatory)] [string[]]$ValidChoices)
	while ($true) {
		$choice = Read-Host "Choose an option ($($ValidChoices -join '-'))"
		if ($ValidChoices -contains $choice) { return $choice }
		Write-Host "Please enter one of: $($ValidChoices -join ', ')" -ForegroundColor Yellow
	}
}

function Read-YesNo {
	param([Parameter(Mandatory)] [string]$Prompt)
	while ($true) {
		$answer = Read-Host "$Prompt (y/n)"
		if ($answer -match '^(y|yes)$') { return $true }
		if ($answer -match '^(n|no)$') { return $false }
		Write-Host "Please answer y or n." -ForegroundColor Yellow
	}
}

function Select-Variant {
	Write-Host ""
	Write-Host "Which version of Godot do you want?"
	Write-Host ""
	Write-Host "  1) Godot"
	Write-Host "  2) Godot Mono (for C# projects)"
	Write-Host "  3) Both"
	Write-Host ""
	$choice = Read-MenuChoice -ValidChoices @('1', '2', '3')
	switch ($choice) {
		'1' { return 'Standard' }
		'2' { return 'Mono' }
		'3' { return 'Both' }
	}
}

function Select-FolderDialog {
	param(
		[Parameter(Mandatory)] [string]$Description,
		[string]$InitialPath = $PSScriptRoot
	)
	$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
	$dialog.Description = $Description
	$dialog.SelectedPath = $InitialPath
	if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		return $dialog.SelectedPath
	}
	return $null
}

function Wait-ForEnter {
	Write-Host ""
	Write-Host "Press Enter to return to the menu..."
	[void][System.Console]::ReadLine()
}

function Invoke-ChildScript {
	param(
		[Parameter(Mandatory)] [string]$ScriptName,
		[hashtable]$Parameters = @{}
	)
	$scriptPath = Join-Path $PSScriptRoot $ScriptName
	Write-Host ""
	Write-Host "Running $ScriptName ..." -ForegroundColor Cyan
	Write-Host ""
	Push-Location $PSScriptRoot
	try {
		& $scriptPath @Parameters
	} catch {
		Write-Host ""
		Write-Host "Something went wrong: $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Pop-Location
	}
}

function Invoke-InstallFromFolder {
	$sourceFolder = Join-Path $PSScriptRoot 'source'
	$initialPath = if (Test-Path -LiteralPath $sourceFolder) { $sourceFolder } else { $PSScriptRoot }
	$chosenFolder = Select-FolderDialog -Description "Select the folder containing the Godot build you want to install (the extracted folder or .zip files)" -InitialPath $initialPath
	if (-not $chosenFolder) {
		Write-Host "Cancelled, nothing was installed."
		return
	}
	$variant = Select-Variant
	Invoke-ChildScript -ScriptName 'Install-Godot.ps1' -Parameters @{ SourcePath = $chosenFolder; Variant = $variant }
}

function Invoke-GetLatest {
	$variant = Select-Variant
	$force = Read-YesNo "Force a fresh re-download even if this version is already installed?"
	if ($force) {
		Invoke-ChildScript -ScriptName 'Get-LatestGodot-Force.ps1' -Parameters @{ Variant = $variant }
	} else {
		Invoke-ChildScript -ScriptName 'Get-LatestGodot.ps1' -Parameters @{ Variant = $variant }
	}
}

function Select-InstalledGodotVersion {
	param([string]$NoneFoundMessage = "No installed Godot version was found.")

	$installed = Get-ChildItem -LiteralPath $install_root -Directory -ErrorAction SilentlyContinue
	if (-not $installed -or $installed.Count -eq 0) {
		Write-Host $NoneFoundMessage
		return $null
	}
	if ($installed.Count -eq 1) { return $installed[0].Name }

	Write-Host ""
	Write-Host "More than one Godot version is installed. Which one do you want?"
	Write-Host ""
	for ($i = 0; $i -lt $installed.Count; $i++) {
		Write-Host "  $($i + 1)) $($installed[$i].Name)"
	}
	$cancelChoice = $installed.Count + 1
	Write-Host "  $cancelChoice) Cancel"
	Write-Host ""

	$validChoices = 1..$cancelChoice | ForEach-Object { "$_" }
	$choice = [int](Read-MenuChoice -ValidChoices $validChoices)
	if ($choice -eq $cancelChoice) {
		Write-Host "Cancelled."
		return $null
	}
	return $installed[$choice - 1].Name
}

function Invoke-GetDocs {
	$version = Select-InstalledGodotVersion -NoneFoundMessage "No installed Godot version was found. Install one first using option 1, 2, or 3."
	if (-not $version) { return }
	Invoke-ChildScript -ScriptName 'Get-GodotDocs.ps1' -Parameters @{ GodotVersion = $version }
}

function Invoke-InstallEverything {
	Invoke-ChildScript -ScriptName 'Get-LatestGodot.ps1' -Parameters @{ Variant = 'Both' }
	$version = Select-InstalledGodotVersion -NoneFoundMessage "Something went wrong, no installed Godot version was found after installing."
	if ($version) {
		Invoke-ChildScript -ScriptName 'Get-GodotDocs.ps1' -Parameters @{ GodotVersion = $version }
	}
}

function Invoke-OpenLogsFolder {
	$logsPath = Join-Path $PSScriptRoot 'logs'
	if (-not (Test-Path -LiteralPath $logsPath)) {
		New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
	}
	Invoke-Item $logsPath
}

do {
	Clear-Host
	Show-Menu
	$choice = Read-MenuChoice -ValidChoices @('1', '2', '3', '4', '5', '6')

	switch ($choice) {
		'1' { Invoke-InstallEverything }
		'2' { Invoke-GetLatest }
		'3' { Invoke-InstallFromFolder }
		'4' { Invoke-GetDocs }
		'5' { Invoke-OpenLogsFolder }
		'6' { Write-Host "Goodbye!"; exit }
	}

	if ($choice -ne '6') { Wait-ForEnter }
} while ($true)
