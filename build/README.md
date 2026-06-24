# build

Maintainer-only. Not something end users run, and not something the
menu or any of the install scripts depend on at runtime.

## Build-SfxInstaller.ps1 / Build-SfxInstaller.bat

Packages `scripts\` (minus this build folder), `Godot Install Menu.bat`,
`README.md`, and `LICENSE` from the repo root into a single
self-extracting `Godot-Installer-Setup.exe`, using `iexpress.exe`
(built into Windows, no extra tools needed on the build machine or on
whoever downloads the result).

Double-click `Build-SfxInstaller.bat`, or from PowerShell at the repo
root:

```
.\build\Build-SfxInstaller.ps1
```

Produces `dist\Godot-Installer-Setup.exe` at the repo root (gitignored,
this is the file that gets attached to GitHub Releases, not committed).

Running that `.exe` extracts everything flat into one temp folder
(iexpress cannot preserve a `scripts\` subfolder on extraction), copies
it to `%USERPROFILE%\Downloads\Godot Installer`, and launches
`Godot Install Menu.bat` from there via the bundled `_bootstrap.bat`.
Because of that flattening, `Godot Install Menu.bat` and
`Godot Install Menu.ps1` both detect at runtime whether they are sitting
in the git repo's nested layout or in this flat extracted layout, rather
than assuming one or the other.

## _bootstrap.bat

Bundled inside the `.exe`, not meant to be run on its own. Copies the
extracted files to `%USERPROFILE%\Downloads\Godot Installer` and starts
`Godot Install Menu.bat` from there.
