# Viewport Avatar Preview Architecture

Keputusan terbaru: preview catalog menggunakan `ViewportFrame`, bukan active character mutation. Ini membuat `Try On` tetap client-only, sementara real character baru berubah saat user klik `Apply`.

## Why ViewportFrame

Active character client-only preview punya batasan besar:

- Client tidak reliable untuk `Humanoid:AddAccessory()` ke live character.
- `Humanoid:ApplyDescription()` ke live character bukan path yang aman untuk preview lokal.
- Server-side preview akan langsung terlihat oleh player lain, sehingga itu sudah masuk flow `Apply`.

Dengan `ViewportFrame`, kita bisa memisahkan:

- **Preview**: clone/dummy avatar di UI, local-only.
- **Apply**: real character di server, visible ke player lain.

## Runtime Flow

```text
Open Catalog
-> Blur world camera
-> Show Catalog UI
-> Build ViewportFrame preview rig from LocalPlayer.Character

Try On
-> Update PreviewState
-> Rebuild/apply HumanoidDescription on viewport rig only
-> No RemoteEvent
-> Other players do not see preview

Apply
-> Future milestone
-> Client sends final item ids to server
-> Server validates
-> Server applies final appearance to real character
```

## Current Test Item

Fedora macan tutul salju:

- Catalog URL: https://www.roblox.com/id/catalog/128159229/Fedora-macan-tutul-salju
- Asset id: `128159229`
- Preview category used for MVP: `HatAccessory`

## Implementation Notes

### `CatalogTopbarController`

- Creates/uses `Lighting.CatalogBackgroundBlur`.
- Enables blur when TopbarPlus `Catalog` icon is selected.
- Disables blur when catalog is closed/destroyed.

### `CatalogScreen`

- Keeps catalog panel on the left.
- Uses a transparent right-side preview space.
- Renders `AvatarPreviewViewport` in the preview space.

### `AvatarPreviewViewport`

- Creates:
  - `ViewportFrame`
  - `Camera`
  - `WorldModel`
- Clones `Players.LocalPlayer.Character` locally.
- Removes scripts from the clone.
- Keeps only `HumanoidRootPart` anchored, disables collisions/query/touch on cloned parts.
- Plays idle animation on the cloned rig so preview does not look frozen.
- Frames the camera for full-body preview and supports mouse/touch drag rotation.
- Applies preview item ids to the cloned rig's `HumanoidDescription`.
- Does not modify the real character.

## Scope Rules

For Issue 4.3:

- `Try On` must not call `FireServer`.
- `Try On` must not mutate live active character.
- Preview may use `Humanoid:ApplyDescription()` only on the cloned viewport rig.
- Server apply belongs to Milestone 5.

## Known Limits

- Current MVP maps preview asset ids into `HatAccessory`.
- Future work should map catalog item type to the correct `HumanoidDescription` field:
  - hats/hair -> `HatAccessory` or `HairAccessory`
  - face accessories -> `FaceAccessory`
  - back accessories -> `BackAccessory`
  - waist/shoulder/front/neck accessories -> matching fields
  - classic clothing -> `Shirt`, `Pants`, `GraphicTShirt`
  - animations/body/bundles -> later milestone

## Acceptance Criteria

- Opening catalog blurs the world camera.
- Closing catalog removes blur.
- Viewport preview shows local player avatar clone.
- Clicking Fedora item previews asset `128159229` on the viewport rig.
- Viewport clone is full-body, animated, rotatable, and styled like the catalog frame.
- Real player character is not changed by `Try On`.
- No preview RemoteEvent is introduced.
