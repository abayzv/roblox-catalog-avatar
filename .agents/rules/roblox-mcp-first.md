# Roblox Studio MCP First Rules

Roblox Studio MCP is the primary source of truth for this project.

Do not treat MCP as an optional debug tool.
Do not wait for the user to report an error before using MCP.
Do not write Roblox code purely from assumptions.

## Mandatory MCP-first workflow

For any Roblox-related task, follow this order:

1. Confirm Studio connection.
2. Inspect the live Roblox Studio state.
3. Find the relevant instances/scripts/remotes/modules.
4. Read existing scripts before editing.
5. Apply the smallest safe change.
6. Validate in Studio.
7. Check console output.
8. Report verification clearly.

## Session setup

When starting a Roblox task:

- Use `list_roblox_studios` to see available Studio sessions.
- Use `set_active_studio` if more than one Studio instance exists.
- Do not assume the active Studio session is correct if multiple sessions exist.

## Before coding

Before writing or editing Roblox scripts, answer these internally using MCP:

- Where is the target script located?
- Is it a ServerScript, LocalScript, or ModuleScript?
- What services/folders already exist?
- What RemoteEvents or RemoteFunctions already exist?
- What ModuleScripts are already used?
- What object names are actually present in Studio?
- What UI, tools, models, animations, or character objects are involved?
- Does this behavior need Play mode to verify?

If these cannot be answered from MCP, inspect Studio first.

## DataModel and Explorer inspection

Use the right MCP tools:

- `search_game_tree` to find instances in the DataModel.
- `inspect_instance` to inspect properties, attributes, children, and descendants.
- `explore_subagent` for broad project exploration.

Do not invent instance paths.
Do not assume names like `MainGui`, `Remotes`, `PlayerGui`, `Tool`, or `HumanoidRootPart` exist without inspection.

## Script inspection

Use the right MCP tools:

- `script_search` to find scripts by name.
- `script_grep` to search code content inside Studio scripts.
- `script_read` before editing an existing script.
- `multi_edit` to create or modify scripts inside Studio.

Do not use terminal `grep` for Roblox Studio script search.
Do not guess script paths.
Do not edit a script before reading it.

## Runtime verification

Use the right MCP tools:

- `execute_luau` for direct runtime checks.
- `start_stop_play` for gameplay testing.
- `console_output` to inspect errors and warnings.
- `screen_capture` for UI, camera, map, character, and visual checks.

## Player interaction verification

For gameplay that requires user/player behavior, use:

- `playtest_subagent` for scenario testing.
- `character_navigation` for movement tests.
- `keyboard_input` for keyboard interaction.
- `mouse_input` for UI clicking, scrolling, camera movement, or mouse actions.

Do not claim interactive gameplay works without testing the interaction path.

## Anti-lazy MCP rule

Do not repeatedly use only the same MCP tools.

Choose the most specific tool for the job:

- Need to find a script by name? Use `script_search`.
- Need to search script content? Use `script_grep`.
- Need to read existing code? Use `script_read`.
- Need to modify code? Use `multi_edit`.
- Need to understand Explorer/DataModel? Use `search_game_tree` or `inspect_instance`.
- Need to verify runtime behavior? Use `execute_luau` or `start_stop_play`.
- Need to check errors? Use `console_output`.
- Need to verify UI/visual state? Use `screen_capture`.
- Need player movement/input? Use `character_navigation`, `keyboard_input`, `mouse_input`, or `playtest_subagent`.

Pick the tool that matches the task, not just the tool that is most familiar.

## No blind Roblox coding

Never write Roblox gameplay, UI, tool, character, camera, RemoteEvent, animation, or runtime code purely from assumption.

MCP inspection is required before coding.

If MCP is unavailable, say MCP is unavailable and make only a best-effort code proposal. Do not claim the change was tested in Studio.
