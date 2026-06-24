# Antigravity Roblox Agent Master Dictionary

This file is the source dictionary for the Antigravity Roblox workflow.

Use this file as the reference for:

- Forbidden Bash syntax
- Correct PowerShell replacements
- Roblox Studio MCP tool selection
- Roblox testing workflow
- Common failure patterns

This dictionary should be treated as the source of truth for agent behavior.

---

# 1. Shell Dictionary

## Default shell

```yaml
default_shell: Windows PowerShell
bash_allowed: false
wsl_allowed_by_default: false
```

## Forbidden terminal commands

```yaml
forbidden_terminal_tokens:
  - grep
  - rm -rf
  - mkdir -p
  - touch
  - export
  - source
  - sed
  - awk
  - cat <<EOF
  - chmod +x
```

## Bash to PowerShell replacements

```yaml
replacements:
  grep_file:
    wrong: grep "keyword" file.txt
    correct: Select-String -Path "file.txt" -Pattern "keyword"

  grep_pipe:
    wrong: cat file.txt | grep "keyword"
    correct: Get-Content "file.txt" | Select-String -Pattern "keyword"

  grep_recursive:
    wrong: grep -r "keyword" .
    correct: Get-ChildItem -Recurse -File | Select-String -Pattern "keyword"

  grep_recursive_line_number:
    wrong: grep -rn "keyword" .
    correct: Get-ChildItem -Recurse -File | Select-String -Pattern "keyword" | Select-Object Path, LineNumber, Line

  remove_folder:
    wrong: rm -rf dist
    correct: Remove-Item -Recurse -Force "dist"

  create_folder:
    wrong: mkdir -p src/components
    correct: New-Item -ItemType Directory -Force -Path "src/components"

  create_file:
    wrong: touch notes.txt
    correct: New-Item -ItemType File -Force -Path "notes.txt"

  copy_folder:
    wrong: cp -r source destination
    correct: Copy-Item -Recurse -Force "source" "destination"

  move_item:
    wrong: mv source destination
    correct: Move-Item "source" "destination"

  set_env:
    wrong: export NODE_ENV=development
    correct: $env:NODE_ENV = "development"

  activate_python_venv:
    wrong: source .venv/bin/activate
    correct: .\.venv\Scripts\Activate.ps1

  run_python_venv:
    wrong: python script.py
    correct: .\.venv\Scripts\python.exe script.py
```

## Search command preference

```yaml
local_code_search_priority:
  1: rg
  2: Select-String
  forbidden: grep

roblox_studio_script_search:
  use: MCP script_grep
  forbidden: terminal grep
```

---

# 2. Roblox MCP Tool Dictionary

## Session tools

```yaml
list_roblox_studios:
  purpose: List available Roblox Studio sessions.
  use_when:
    - Starting any Roblox task
    - Unsure which Studio instance is active
    - Multiple Studio windows may exist

set_active_studio:
  purpose: Select the correct active Roblox Studio session.
  use_when:
    - More than one Studio session exists
    - The current active session is unclear
```

## DataModel tools

```yaml
search_game_tree:
  purpose: Search the live Roblox DataModel / Explorer hierarchy.
  use_when:
    - Need to find services, folders, models, UI, tools, remotes, or scripts
    - Need to confirm object names and paths
    - Need to avoid guessing instance paths

inspect_instance:
  purpose: Inspect a specific Roblox instance.
  use_when:
    - Need properties, attributes, children, descendants, or object details
    - Need to understand a folder/model/tool/UI structure
    - Need to verify that an object exists before coding against it

explore_subagent:
  purpose: Broad project exploration.
  use_when:
    - The task scope is unclear
    - Need a project overview before making changes
```

## Script tools

```yaml
script_search:
  purpose: Find scripts by name or location.
  use_when:
    - Looking for a specific Script, LocalScript, or ModuleScript
    - The user names a script but the path is unknown

script_grep:
  purpose: Search code content inside Roblox Studio scripts.
  use_when:
    - Looking for RemoteEvent usage
    - Looking for function names
    - Looking for require calls
    - Looking for old code patterns
    - Searching Roblox scripts, not local files
  note: This is not terminal grep. This is an MCP tool.

script_read:
  purpose: Read the full content of a Studio script.
  use_when:
    - Before editing any existing script
    - Before debugging an error in a script
    - Before modifying behavior

multi_edit:
  purpose: Create or modify scripts/objects inside Studio.
  use_when:
    - Applying edits to Roblox scripts
    - Creating new scripts
    - Making coordinated multi-file changes
```

## Runtime and verification tools

```yaml
execute_luau:
  purpose: Run small Luau checks in Studio context.
  use_when:
    - Need to inspect runtime state
    - Need to validate small assumptions
    - Need quick Studio-side checks

start_stop_play:
  purpose: Start or stop Play mode.
  use_when:
    - Testing gameplay
    - Testing LocalScripts
    - Testing PlayerGui
    - Testing RemoteEvents / RemoteFunctions
    - Testing character, humanoid, tool, camera, UI, animation, or physics behavior

console_output:
  purpose: Read Studio output errors, warnings, and logs.
  use_when:
    - After every script change
    - After Play mode
    - When debugging an error
    - Before claiming success

screen_capture:
  purpose: Capture visual state in Studio.
  use_when:
    - UI verification
    - Camera verification
    - Map/model placement verification
    - Character visual verification
    - Visual effects verification
```

## Player input tools

```yaml
playtest_subagent:
  purpose: Run a gameplay scenario test.
  use_when:
    - Testing a feature from a player perspective
    - The bug requires multiple actions
    - Manual player-like validation is needed

character_navigation:
  purpose: Move the player character.
  use_when:
    - Testing movement
    - Testing touch triggers
    - Testing proximity or zone behavior
    - Testing character-based interactions

keyboard_input:
  purpose: Send keyboard input.
  use_when:
    - Testing hotkeys
    - Testing movement controls
    - Testing keyboard-driven UI
    - Testing tools or abilities triggered by keys

mouse_input:
  purpose: Send mouse input.
  use_when:
    - Testing UI clicks
    - Testing camera/mouse behavior
    - Testing click detectors
    - Testing drag/scroll interactions
```

---

# 3. Task Type to MCP Tool Mapping

```yaml
find_script_by_name:
  tools:
    - script_search
    - script_read

search_script_content:
  tools:
    - script_grep
    - script_read

understand_game_structure:
  tools:
    - search_game_tree
    - inspect_instance
    - explore_subagent

edit_existing_script:
  tools:
    - script_search
    - script_read
    - multi_edit
    - console_output

create_new_script:
  tools:
    - search_game_tree
    - inspect_instance
    - multi_edit
    - console_output

fix_console_error:
  tools:
    - console_output
    - script_read
    - inspect_instance
    - multi_edit
    - start_stop_play
    - console_output

test_remote_event:
  tools:
    - search_game_tree
    - inspect_instance
    - script_grep
    - script_read
    - start_stop_play
    - console_output

test_ui:
  tools:
    - search_game_tree
    - inspect_instance
    - script_read
    - start_stop_play
    - screen_capture
    - mouse_input
    - keyboard_input
    - console_output

test_tool_or_weapon:
  tools:
    - search_game_tree
    - inspect_instance
    - script_read
    - start_stop_play
    - mouse_input
    - keyboard_input
    - console_output

test_character_or_movement:
  tools:
    - start_stop_play
    - character_navigation
    - keyboard_input
    - console_output
    - screen_capture
```

---

# 4. Mandatory Roblox Workflow

```yaml
roblox_task_workflow:
  - confirm_studio_connection
  - inspect_datamodel
  - find_relevant_instances
  - find_relevant_scripts
  - read_existing_scripts
  - plan_minimal_change
  - apply_change
  - run_static_or_runtime_check
  - start_play_mode_if_needed
  - check_console_output
  - capture_screen_if_visual
  - test_player_input_if_interactive
  - report_mcp_verification
```

---

# 5. Testing Requirement Dictionary

## Play mode required

```yaml
play_mode_required_for:
  - character movement
  - tools
  - weapons
  - combat
  - camera behavior
  - UI runtime behavior
  - PlayerGui
  - LocalScript behavior
  - RemoteEvents
  - RemoteFunctions
  - animations
  - humanoid behavior
  - physics
  - touch interactions
  - click interactions
  - server-client communication
```

## Play mode optional

```yaml
play_mode_optional_for:
  - reading scripts
  - searching scripts
  - organizing folders
  - renaming instances
  - adding comments
  - creating static placeholder objects
```

## Always check after changes

```yaml
after_change_checks:
  - console_output
  - playtest_when_runtime_behavior_is_affected
  - screen_capture_when_visual_behavior_is_affected
  - player_input_when_interaction_is_required
```

---

# 6. Required Final Verification Format

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

---

# 7. Common Failure Patterns

```yaml
failure_patterns:
  uses_grep_in_powershell:
    problem: Terminal grep does not exist in default Windows PowerShell.
    fix: Use Select-String, rg, or MCP script_grep for Studio scripts.

  codes_before_inspecting_studio:
    problem: Agent guesses object paths and script locations.
    fix: Use search_game_tree, inspect_instance, script_search, and script_read first.

  uses_only_execute_luau:
    problem: Agent treats MCP as a simple runtime console and ignores specialized tools.
    fix: Select MCP tools based on task type.

  claims_done_without_playtest:
    problem: Runtime behavior was not validated.
    fix: Use start_stop_play and console_output.

  claims_ui_fixed_without_visual_check:
    problem: UI may still be wrong visually.
    fix: Use screen_capture and input tools if needed.

  edits_existing_script_without_reading:
    problem: Agent may overwrite or duplicate existing logic.
    fix: Use script_read before multi_edit.
```

---

# 8. Short Agent Policy

```text
PowerShell is the default terminal.
Never use terminal grep.
Use Select-String or rg for local search.
Use MCP script_grep for Roblox Studio script search.
Roblox Studio MCP is mandatory before coding.
Do not guess Studio paths or object names.
Read scripts before editing.
Use the most specific MCP tool for the job.
Playtest runtime behavior before claiming success.
Check console_output after changes.
Report MCP verification at the end.
```
