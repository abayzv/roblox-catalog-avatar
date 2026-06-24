# Roblox UI Guidelines

When creating or modifying Roblox UIs in this workspace, strictly follow the layout guidelines and patterns defined in `roblox_ui_layout_guide.md`.

Key points to remember:
- **Root Screen**: Always fill the screen (`Size = UDim2.fromScale(1, 1)`). Do not rely on fixed sizes for the root layout.
- **Split Area Layout**: Use `Scale` to divide main areas (e.g., Left/Right or Main/Side).
- **Content Scaling**: Use `UIScale` to scale down the *content* of an area rather than fixing the size of the area itself when it needs to be smaller on mobile. Ensure internal components maintain proportional design size.
- **Fixed Height Rows**: Explicitly define heights for components using `UIListLayout` to ensure consistency.
- **Stroke Clipping**: Always provide enough padding (4-6px) so that `UIStroke` does not get clipped.
- **Grid Layout**: Calculate cell sizes based on a viewport scale, avoiding double scaling.
- **Canvas Size**: Explicitly calculate scrolling canvas sizes using estimated content height to prevent cutoff at the bottom.
- **Modal Blocker (Optional)**: Modals should block inputs with `Modal = true`, and Z-Index must be carefully managed. Use only for true modal UIs (like shop/settings). Do not use blocker for HUDs or non-modal overlays.
- **ViewportFrame Preview**: Use proper structure (PreviewPanel -> Stage -> ViewportFrame -> WorldModel -> Camera) and ensure camera fit calculations are based on the model's bounding box.

Never use fixed offset sizes for main structural surfaces that should adapt to different screen dimensions.

# Architecture Guidelines

- **Avatar Preview Flow**: Always use a `ViewportFrame` clone for previewing avatars ("Try On"). 
- **DO NOT** mutate the live local character (`Players.LocalPlayer.Character`) during preview.
- **Server Application**: Only apply the final avatar choice to the live character via server request when the user confirms ("Apply"). Do not fire remotes during Try On.
- **Reset Preview**: Reset actions must clear or restore the state of the viewport clone, not the local live character.
- **UI State**: Apply and Reset buttons must read from the `PreviewState` of the items currently being previewed in the viewport.
- **Remote Payload & Validation**: The apply payload must be the final item IDs from `PreviewState`, not a diff. The server must validate the whitelist/ownership of these item IDs and not trust visual changes from the client.

# Terminal Rules — Windows PowerShell Only

You are running in Windows PowerShell by default.

Before writing or executing any terminal command:
1. Assume the shell is Windows PowerShell, not Bash, not Linux shell.
2. Do not use Bash syntax.
3. If a command looks like Bash/Linux syntax, rewrite it to valid PowerShell first.
4. Prefer explicit PowerShell commands over Unix aliases.
5. Never run a command until it has passed the PowerShell syntax check below.

## Forbidden Bash syntax

Do not use:

- rm -rf
- cp -r
- mkdir -p
- touch
- export KEY=value
- source .venv/bin/activate
- VAR=value command
- command1 && command2 if running in Windows PowerShell 5.1
- cat <<EOF
- grep, sed, awk unless explicitly available

## Correct PowerShell equivalents

Use these instead:

- Remove folder:
  Remove-Item -Recurse -Force "path"

- Create folder:
  New-Item -ItemType Directory -Force -Path "path"

- Create empty file:
  New-Item -ItemType File -Force -Path "file.txt"

- Copy folder:
  Copy-Item -Recurse -Force "source" "destination"

- Move/rename:
  Move-Item "source" "destination"

- Delete file:
  Remove-Item -Force "file.txt"

- Set env variable:
  $env:KEY = "value"

- Activate Python venv on Windows:
  .\.venv\Scripts\Activate.ps1

- Run Python from venv directly:
  .\.venv\Scripts\python.exe script.py

- Run npm:
  npm install
  npm run dev

## Mandatory self-check

Before executing a command, silently check:

- Is this valid PowerShell?
- Does it contain Bash-only syntax?
- Does it use Linux paths where Windows paths are required?
- Does it need quotes around paths?

If invalid, rewrite it before running.

# GitHub CLI (`gh`) Rules

When running GitHub CLI commands (`gh`), the system environment may contain an invalid dummy `GITHUB_TOKEN` which overrides the active valid keyring authentication. You MUST explicitly clear this token from the environment within the same command line before invoking `gh`.

**Correct Syntax (PowerShell):**
```powershell
Remove-Item Env:\GITHUB_TOKEN -ErrorAction SilentlyContinue; gh <command>
```

Do NOT use `gh` without prefixing it with the token removal command.
**NOTE**: Only use this token removal command specifically when you are running `gh` commands. You do not need to prepend this for other normal terminal commands!

# Critical Rule: grep is forbidden

The terminal is Windows PowerShell.

Never use `grep`.

If you are about to write `grep`, stop and replace it with PowerShell syntax.

## grep replacements

Wrong:
grep "keyword" file.txt

Correct:
Select-String -Path "file.txt" -Pattern "keyword"

Wrong:
cat file.txt | grep "keyword"

Correct:
Get-Content "file.txt" | Select-String -Pattern "keyword"

Wrong:
grep -r "keyword" .

Correct:
Get-ChildItem -Recurse -File | Select-String -Pattern "keyword"

Wrong:
grep -rn "keyword" .

Correct:
Get-ChildItem -Recurse -File | Select-String -Pattern "keyword" | Select-Object Path, LineNumber, Line

Wrong:
npm run dev | grep "error"

Correct:
npm run dev | Select-String -Pattern "error"

## Mandatory command validation

Before executing any terminal command:

1. Check if the command contains `grep`.
2. If it contains `grep`, do not execute it.
3. Rewrite the command using `Select-String`.
4. Only execute the rewritten PowerShell command.
