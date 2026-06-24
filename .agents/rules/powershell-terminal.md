# PowerShell Terminal Rules

The terminal in Antigravity is Windows PowerShell by default.

These rules are mandatory for every terminal command.

## Core rule

Always write terminal commands as valid Windows PowerShell.

Do not use Bash, Linux shell, macOS shell, or WSL syntax unless the user explicitly says the terminal is Bash/WSL.

Before executing any command, silently check:

1. Is this valid PowerShell?
2. Does it contain Bash-only syntax?
3. Does it assume Linux paths?
4. Does it need quotes around paths?
5. Does it use a command that does not exist in PowerShell?

If the command is not valid PowerShell, rewrite it before execution.

## Hard forbidden Bash syntax

Never use these in PowerShell:

- `grep`
- `rm -rf`
- `mkdir -p`
- `touch`
- `export KEY=value`
- `source .venv/bin/activate`
- `VAR=value command`
- `cat <<EOF`
- `sed`
- `awk`
- `chmod +x`
- `./script.sh` unless a shell environment is explicitly available
- Linux-style paths like `/home/user/project`

If a command contains any forbidden token, do not execute it. Rewrite it first.

## grep is forbidden

Never use terminal `grep`.

If you are about to write `grep`, stop and replace it.

### grep replacements

Wrong:

```bash
grep "keyword" file.txt
```

Correct:

```powershell
Select-String -Path "file.txt" -Pattern "keyword"
```

Wrong:

```bash
cat file.txt | grep "keyword"
```

Correct:

```powershell
Get-Content "file.txt" | Select-String -Pattern "keyword"
```

Wrong:

```bash
grep -r "keyword" .
```

Correct:

```powershell
Get-ChildItem -Recurse -File | Select-String -Pattern "keyword"
```

Wrong:

```bash
grep -rn "keyword" .
```

Correct:

```powershell
Get-ChildItem -Recurse -File | Select-String -Pattern "keyword" | Select-Object Path, LineNumber, Line
```

Wrong:

```bash
npm run dev | grep "error"
```

Correct:

```powershell
npm run dev | Select-String -Pattern "error"
```

## Prefer ripgrep for code search if available

For local codebase search on Windows, prefer `rg` if it is installed.

Correct:

```powershell
rg "RemoteEvent"
rg -n "function login" .\src
rg "require\(" .\src
```

If `rg` is not available, use `Select-String`.

## PowerShell equivalents

### Remove folder

Wrong:

```bash
rm -rf dist
```

Correct:

```powershell
Remove-Item -Recurse -Force "dist"
```

### Create folder

Wrong:

```bash
mkdir -p src/components
```

Correct:

```powershell
New-Item -ItemType Directory -Force -Path "src/components"
```

### Create empty file

Wrong:

```bash
touch notes.txt
```

Correct:

```powershell
New-Item -ItemType File -Force -Path "notes.txt"
```

### Copy folder

Wrong:

```bash
cp -r source destination
```

Correct:

```powershell
Copy-Item -Recurse -Force "source" "destination"
```

### Move or rename

Correct:

```powershell
Move-Item "source" "destination"
```

### Delete file

Correct:

```powershell
Remove-Item -Force "file.txt"
```

### Set environment variable

Wrong:

```bash
export NODE_ENV=development
```

Correct:

```powershell
$env:NODE_ENV = "development"
```

### Activate Python venv on Windows

Wrong:

```bash
source .venv/bin/activate
```

Correct:

```powershell
.\.venv\Scripts\Activate.ps1
```

### Run Python from venv directly

Correct:

```powershell
.\.venv\Scripts\python.exe script.py
```

## Roblox-specific search rule

For Roblox Studio script search, do not use terminal `grep`.

Use Roblox Studio MCP `script_grep` instead.

Local file search:

```powershell
rg "RemoteEvent"
```

Roblox Studio script search:

```text
Use MCP tool: script_grep
Pattern: RemoteEvent
```

## Mandatory command output format

Before running a terminal command, format it mentally as:

```text
Shell: PowerShell
Command: <valid PowerShell command>
```

Only execute the command if it is valid PowerShell.

If unsure, choose the safer PowerShell equivalent instead of guessing Bash syntax.
