# Godot Install Scripts

PowerShell scripts that install Godot Engine on Windows without using the
usual unzip and run workflow. Each version gets its own folder under
Program Files so old and new versions sit side by side, and the scripts
create Desktop and Start Menu shortcuts so the app, the install folder,
and the docs are easy to find.

## Requirements

- Windows
- PowerShell, run as Administrator. The scripts check for this and stop
  if you are not elevated.

## Scripts

### Install-Godot.ps1

Installs Godot from build files you already have on disk. Use this when
you downloaded a specific version yourself and want to pin that exact
build.

```
.\Install-Godot.ps1 -SourcePath "C:\path\to\folder\with\build\files"
```

Parameters:

- `-SourcePath` folder containing the build(s). Can hold the already
  extracted exe folder(s) or the original .zip files from
  godotengine.org or GitHub. See `sample-source` below for the expected
  layout.
- `-Variant` Standard, Mono, or Both. Default is Both.
- `-InstallRoot` where versions get installed. Default is
  `C:\Program Files\Godot`.
- `-DocsUrl` the online docs link used for the docs shortcut. Default is
  `https://docs.godotengine.org/en/stable/`.

If a `godot-docs` folder is found inside `-SourcePath`, it gets copied
alongside the install and a local docs shortcut is added too.

### Get-LatestGodot.ps1

Self-contained script that pulls the latest stable release straight from
the godotengine/godot GitHub repo, checks its SHA512 checksum, and
installs it the same way as Install-Godot.ps1. If that version is
already installed, it skips the download and just makes sure the
shortcuts exist.

```
.\Get-LatestGodot.ps1
```

Takes the same `-Variant`, `-InstallRoot`, and `-DocsUrl` parameters as
above.

### Get-LatestGodot-Force.ps1

Same as Get-LatestGodot.ps1, but it always re-downloads and overwrites
that version's install, even if it is already there.

```
.\Get-LatestGodot-Force.ps1
```

## What gets created

For a given version, for example 4.7:

- `C:\Program Files\Godot\4.7\Standard` and `\Mono`, the actual installed
  builds
- `C:\Program Files\Godot\4.7\docs-source`, only if local docs were
  supplied to Install-Godot.ps1
- Desktop shortcuts on `C:\Users\Public\Desktop` named `Godot 4.7` and
  `Godot 4.7 (Mono)`
- A Start Menu folder named `Godot 4.7` under Programs, with the same
  app shortcuts plus `Open Install Folder` and the docs shortcut(s)

Running any of these scripts again for a newer version does not touch an
older one. Each version lives in its own folder with its own shortcuts.

## sample-source

Shows the folder layout Install-Godot.ps1 expects for `-SourcePath`.
Drop your real Godot zip or extracted build folder in place of the
placeholder text files and point `-SourcePath` at the `sample-source`
folder (or copy the layout anywhere else you like).

## Logs

Each script writes a timestamped log to a `logs` folder created in
whatever directory you ran it from.
