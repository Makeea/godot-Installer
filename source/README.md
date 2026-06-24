# source

Shows the folder layout `Install-Godot.ps1` expects for `-SourcePath`.
Drop your real Godot zip or extracted build folder in place of
`Godot v4.7\PUT_GODOT_BUILD_HERE.txt`, and a rendered offline docs
folder (see `docs-html\OPTIONAL_LOCAL_DOCS_HERE.txt`) in place of that
placeholder if you want a local docs shortcut too. Then point
`-SourcePath` at this folder, or copy the layout anywhere else you
like:

```
.\scripts\Install-Godot.ps1 -SourcePath ".\source"
```

Real `.zip`/`.exe` files and real docs dropped in here are ignored by
`.gitignore`, only the two placeholder text files showing the expected
layout are tracked.
