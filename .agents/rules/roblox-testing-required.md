# Roblox Testing Required Rules

For Roblox tasks, completion requires Studio verification.

Do not say a task is done until it has been verified through Roblox Studio MCP, unless MCP is unavailable and this limitation is explicitly stated.

## Completion checklist

A Roblox task is not complete until:

1. The relevant Studio objects have been inspected with MCP.
2. Existing scripts have been read before editing.
3. The intended script/object changes have been applied.
4. Play mode has been used if runtime/gameplay behavior is affected.
5. `console_output` has been checked after the change.
6. Any errors or warnings have been reported.
7. Visual or UI behavior has been checked with `screen_capture` when relevant.
8. Player input has been tested when the feature depends on movement, clicking, keyboard input, or camera behavior.

## When Play mode is required

Use Play mode for tasks involving:

- Character movement
- Tools
- Weapons
- Combat
- Camera behavior
- UI runtime behavior
- PlayerGui
- LocalScript behavior
- RemoteEvents or RemoteFunctions
- Animations
- Humanoid behavior
- Physics
- Touch/click interactions
- Server/client communication
- DataStore-like flow simulation

After Play mode, always check `console_output`.

## When Play mode may not be required

Play mode may be skipped only for tasks that are purely static, such as:

- Renaming instances
- Organizing folders
- Adding comments
- Reading scripts
- Searching the game tree
- Creating non-runtime placeholder objects

If Play mode is skipped, explain why.

## Console output rule

Always check console output after making changes.

Report:

- Errors
- Warnings
- Relevant prints/logs
- Whether the console is clean

Never claim success without checking console output.

## UI and visual verification

For UI, camera, map, model placement, character appearance, or visual effects:

- Use `screen_capture` after the change.
- If the UI needs interaction, use `mouse_input` or `keyboard_input`.
- If the character needs to move, use `character_navigation`.

Do not claim visual correctness without visual verification.

## Required final report format

Every Roblox task must end with this section:

```text
MCP Verification:
- Studio inspected: yes/no
- Scripts read: <list paths or none>
- Scripts edited: <list paths or none>
- Playtest run: yes/no
- Console errors: none/list
- Console warnings: none/list
- Visual check: yes/no/not needed
- Player interaction tested: yes/no/not needed
- MCP tools used: <list tools>
```

If this section is missing, the task is incomplete.

## Error handling rule

If an error appears:

1. Read the exact console error.
2. Identify the script and line if available.
3. Inspect the relevant script with `script_read`.
4. Apply a minimal fix with `multi_edit`.
5. Run verification again.
6. Check `console_output` again.

Do not guess the fix without reading the error and related script.
