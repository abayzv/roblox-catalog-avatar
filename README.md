# Roblox Item Catalog V2

Roblox item catalog system with a UI-first workflow. The catalog UI is built as a client React-lua app, while avatar try-on preview runs in a client-only `ViewportFrame` clone. Other players should only see changes after the player confirms with `Apply` and the server validates the final selection.

## Current Focus

1. Repository foundation
2. Catalog UI design system
3. Static catalog panel with mock data
4. Client-only try-on preview in a viewport clone
5. Server-visible apply flow

See `roblox_item_catalog_milestones.md` for the issue-by-issue roadmap.
See `roblox_ui_layout_guide.md` for the reusable fullscreen frame/layout guide.

## Setup

Install the toolchain with Aftman:

```powershell
aftman install
```

Install Wally packages:

```powershell
wally install
```

The catalog UI is opened from a TopbarPlus button labeled `Catalog`. In Studio, sync with Rojo, press Play, then click `Catalog` in the Roblox topbar to show or hide the current UI progress.

Run checks:

```powershell
.\scripts\check.ps1
```

Build the Rojo model:

```powershell
.\scripts\build.ps1
```

Start Rojo for Studio sync:

```powershell
rojo serve default.project.json
```

## Project Layout

```text
src/
  client/
    App.client.luau
    ui/
      App.luau
      screens/
      theme/
  shared/
    types/
scripts/
default.project.json
wally.toml
aftman.toml
stylua.toml
```

## Architecture Notes

- UI components should stay presentational.
- `Try On` should preview on a client-only viewport clone.
- `Apply` should be the first step that contacts the server.
- The server must validate item ids before applying anything visible to other players.
