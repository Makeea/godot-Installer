# scripts

The menu and the four scripts it wraps. Non-technical users should not
be in this folder at all, they want `Godot Install Menu.bat` one level
up at the repo root, which double-clicks into `Godot Install Menu.ps1`
here automatically.

Everything below is for running a script directly instead of going
through the menu. Run them from the repo root, for example:

```
.\scripts\Install-Godot.ps1 -SourcePath "C:\path\to\folder\with\build\files"
```

All four require Administrator and will stop with a message if you are
not elevated.

## Godot Install Menu.ps1

The menu itself. Do not double-click this file directly, Windows opens
`.ps1` files in a text editor instead of running them, that is what the
`.bat` at the repo root is for.

## Install-Godot.ps1

Installs Godot from build files you already have on disk. Use this when
you downloaded a specific version yourself and want to pin that exact
build.

Parameters:

- `-SourcePath` folder containing the build(s). Can hold the already
  extracted exe folder(s) or the original .zip files from
  godotengine.org or GitHub. See [`source/`](../source/README.md) for
  the expected layout.
- `-Variant` Standard, Mono, or Both. Default is Both.
- `-InstallRoot` where versions get installed. Default is
  `C:\Program Files\Godot`.
- `-DocsUrl` the online docs link used for the docs shortcut. Default is
  `https://docs.godotengine.org/en/stable/`.

If a `docs-html` folder is found inside `-SourcePath` (the rendered
offline docs, see Get-GodotDocs.ps1 below), it gets copied alongside the
install and a local docs shortcut is added, pointing straight at
`index.html`.

## Get-LatestGodot.ps1

Self-contained script that pulls the latest stable release straight from
the godotengine/godot GitHub repo, checks its SHA512 checksum, and
installs it the same way as Install-Godot.ps1. If that version is
already installed, it skips the download and just makes sure the
shortcuts exist.

Takes the same `-Variant`, `-InstallRoot`, and `-DocsUrl` parameters as
Install-Godot.ps1.

## Get-LatestGodot-Force.ps1

Same as Get-LatestGodot.ps1, but it always re-downloads and overwrites
that version's install, even if it is already there.

## Get-GodotDocs.ps1

Downloads the official prebuilt offline HTML documentation (rendered
pages, not the raw .rst source) from the godot-docs project, refreshed
weekly, and attaches it to an already installed Godot version. Updates
the `Godot Docs (Local)` Start Menu shortcut to open `index.html`
directly.

Parameters:

- `-DocsVersion` stable, latest, or 3.6. Default is stable.
- `-GodotVersion` which installed version to attach the docs to, for
  example 4.7. If only one version is installed, this is detected
  automatically. Required if more than one is installed.
- `-InstallRoot` same meaning as in the other scripts.
- `-Destination` instead of attaching to an install, just download and
  extract the docs to a folder of your choice, for example to fill in
  `source\docs-html` before running Install-Godot.ps1.
