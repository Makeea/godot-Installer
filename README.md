# Godot Install Scripts

PowerShell scripts that install Godot Engine on Windows without using the
usual unzip and run workflow. Each version gets its own folder under
Program Files so old and new versions sit side by side, and the scripts
create Desktop and Start Menu shortcuts so the app, the install folder,
and the docs are easy to find.

## For everyone else (no PowerShell needed)

Double-click `Godot Install Menu.bat`. It asks for Administrator once,
then shows a plain numbered menu, no typing required beyond answering
its yes/no and pick-a-number questions:

1. Install everything (latest Godot, Mono, and offline docs) in one go
2. Download and install the latest Godot from the internet
3. Install Godot from a folder on this computer
4. Download offline help docs for an installed Godot
5. Open the logs folder
6. Exit

Options 2 and 3 ask whether you want Godot, Godot Mono (for C#
projects), or both. Option 1 always installs both with no extra
questions, since it is meant to be the simplest path for a new machine.

Everything below this section is for whoever maintains the scripts
themselves.

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
  godotengine.org or GitHub. See `source` below for the expected
  layout.
- `-Variant` Standard, Mono, or Both. Default is Both.
- `-InstallRoot` where versions get installed. Default is
  `C:\Program Files\Godot`.
- `-DocsUrl` the online docs link used for the docs shortcut. Default is
  `https://docs.godotengine.org/en/stable/`.

If a `docs-html` folder is found inside `-SourcePath` (the rendered
offline docs, see Get-GodotDocs.ps1 below), it gets copied alongside the
install and a local docs shortcut is added, pointing straight at
`index.html`.

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

### Get-GodotDocs.ps1

Downloads the official prebuilt offline HTML documentation (rendered
pages, not the raw .rst source) from the godot-docs project, refreshed
weekly, and attaches it to an already installed Godot version. Updates
the `Godot Docs (Local)` Start Menu shortcut to open `index.html`
directly.

```
.\Get-GodotDocs.ps1
```

Parameters:

- `-DocsVersion` stable, latest, or 3.6. Default is stable.
- `-GodotVersion` which installed version to attach the docs to, for
  example 4.7. If only one version is installed, this is detected
  automatically. Required if more than one is installed.
- `-InstallRoot` same meaning as in the other scripts.
- `-Destination` instead of attaching to an install, just download and
  extract the docs to a folder of your choice, for example to fill in
  `source\docs-html` before running Install-Godot.ps1.

## What gets created

For a given version, for example 4.7:

- `C:\Program Files\Godot\4.7\Standard` and `\Mono`, the actual installed
  builds
- `C:\Program Files\Godot\4.7\docs-html`, the rendered offline docs, if
  supplied to Install-Godot.ps1 or fetched with Get-GodotDocs.ps1
- Desktop shortcuts on `C:\Users\Public\Desktop` named `Godot 4.7` and
  `Godot 4.7 (Mono)`
- A Start Menu folder named `Godot 4.7` under Programs, with the same
  app shortcuts plus `Open Install Folder` and the docs shortcut(s)

Running any of these scripts again for a newer version does not touch an
older one. Each version lives in its own folder with its own shortcuts.

## source

Shows the folder layout Install-Godot.ps1 expects for `-SourcePath`.
Drop your real Godot zip or extracted build folder in place of the
placeholder text files and point `-SourcePath` at the `source` folder
(or copy the layout anywhere else you like).

## Logs

Each script writes a timestamped log to a `logs` folder created in
whatever directory you ran it from.
