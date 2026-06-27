# Phase 7 Technical Plan — Live-First Catalog Try-On System

Project: `abayzv/roblox-catalog-avatar`  
Baseline: Phase 6 completed with Morph-style `HumanoidDescription` apply pipeline  
Goal: remove the separate Apply flow and make **Try-On directly update the live character**.

---

## 0. Core Decision

The system will no longer use this flow:

```text
Try-On in ViewportFrame
↓
User clicks Apply
↓
Live character changes
```

New flow:

```text
Try-On item
↓
Live character changes immediately
↓
Catalog viewport syncs from live character
↓
Currently Wearing UI syncs from live character
```

Main UX rule:

```text
Apa yang user lihat dan pakai di live character
=
apa yang user lihat di catalog
=
apa yang tampil di Currently Wearing
```

This removes confusion such as:

```text
Preview shows A, but live character shows B
Catalog draft exists but character has changed through morph
User does not know which state is real
```

---

## 1. New Source of Truth

Use only two persistent appearance snapshots:

```text
OriginalSnapshot
= player's original avatar when they first join
= backup/reset source
= immutable after first initialization

LiveSnapshot
= appearance currently applied to the real server character
= source of truth for catalog, morph, currently wearing, respawn
```

Optional transient state:

```text
PendingSnapshot
= temporary snapshot waiting to be applied when user clicks quickly
= not a long-lived draft
```

Remove or stop relying on:

```text
persistent DraftSnapshot
Catalog applied state
Preview state as separate truth
Apply button state
```

---

## 2. Mental Model

```text
Live character = truth
ViewportFrame = mirror of truth
Catalog Try-On = change truth
Morph = change truth
Currently Wearing = display truth
Original avatar = reset point
```

The catalog is no longer a “draft kitchen”.  
The catalog is now a **live editor**.

---

## 3. Target Behavior

### Case A — User joins

```text
User joins
↓
Server reads current HumanoidDescription
↓
OriginalSnapshot = current description
LiveSnapshot = current description
LiveRevision = 1
```

### Case B — User opens catalog

```text
Open catalog
↓
Client requests LiveSnapshot
↓
ViewportFrame renders LiveSnapshot
↓
Currently Wearing renders LiveSnapshot
```

No draft restore.  
No sync prompt.  
No stale preview.

### Case C — User clicks Try-On item

```text
User clicks item
↓
Client builds next snapshot from LiveSnapshot + item payload
↓
Client sends TryOn request to server
↓
Server applies next snapshot to real character
↓
Server updates LiveSnapshot
↓
Server returns applied LiveSnapshot
↓
Client updates viewport + Currently Wearing
```

### Case D — User morphs

```text
User uses morph model
↓
Server gets morph HumanoidDescription
↓
Server applies it to real character
↓
LiveSnapshot updates
↓
Client catalog/viewport/currently wearing syncs from new LiveSnapshot
```

### Case E — User closes catalog

```text
Close catalog
↓
No draft saved
↓
Live character remains as-is
```

### Case F — User reopens catalog

```text
Open catalog
↓
Catalog always starts from LiveSnapshot
```

---

## 4. Non-Negotiable Rules

### Rule 1 — Remove Apply button for catalog outfit changes

There is no separate Apply button for trying on catalog items.

```text
Try-On = Apply live
```

### Rule 2 — All live appearance changes go through AvatarAppearanceService

Centralize all live character mutations.

Sources:

```text
catalog_try_on
morph
reset_original
respawn_reapply
```

No system should apply HumanoidDescription directly outside the service.

### Rule 3 — LiveSnapshot updates only after server apply succeeds

Correct:

```text
ApplyDescriptionResetAsync succeeds
↓
humanoid:GetAppliedDescription()
↓
serialize applied description
↓
LiveSnapshot = applied snapshot
LiveRevision += 1
```

Wrong:

```text
Update LiveSnapshot before server apply finishes
```

### Rule 4 — ViewportFrame always renders from server-confirmed LiveSnapshot

For the first version of this refactor, do not use long-lived optimistic preview.

Allowed:

```text
short loading state while Try-On applies
```

Not allowed:

```text
separate preview draft that can diverge from live character
```

### Rule 5 — Morph always updates LiveSnapshot

If morph happens while catalog is open:

```text
Morph applies
↓
LiveSnapshot changes
↓
Catalog viewport refreshes from LiveSnapshot
↓
Currently Wearing refreshes from LiveSnapshot
```

No prompt.  
No draft preservation.

### Rule 6 — OriginalSnapshot only for reset

OriginalSnapshot should not be overwritten by catalog try-on or morph.

### Rule 7 — One live apply per player at a time

Catalog Try-On, morph, reset, and respawn reapply must not overlap.

Use a per-player apply lock.

### Rule 8 — Spam clicking must be controlled

Because Try-On now calls server apply, clicking too fast must not fire uncontrolled server applies.

Use either:

```text
Option A: reject/disable while applying
```

or:

```text
Option B: latest-wins queue
```

Recommended for first implementation:

```text
Option A first, Option B later
```

---

# 5. High-Level Architecture

## Server

Create or refactor:

```text
src/server/services/AvatarAppearanceService.luau
```

Responsibilities:

```text
initialize OriginalSnapshot and LiveSnapshot
apply catalog try-on snapshot
apply morph snapshot
reset to original
reapply LiveSnapshot on respawn
manage LiveRevision
manage per-player apply lock
return live state to client
```

## Client

Create or refactor:

```text
src/client/services/AvatarAppearanceClient.luau
src/client/controllers/CatalogTryOnController.luau
src/client/controllers/AvatarPreviewController.luau
src/client/controllers/CurrentlyWearingController.luau
```

Responsibilities:

```text
request LiveSnapshot
render ViewportFrame from LiveSnapshot
build next snapshot when user Try-Ons item
send Try-On request
handle loading/disabled state
hydrate from server response
render Currently Wearing from LiveSnapshot
```

## Shared

Use existing serializer:

```text
src/shared/avatar/HumanoidDescriptionSerializer.luau
```

Use existing preview payload resolver:

```text
PreviewPayloadResolver
PreviewPayloadCache
```

But the payload is now used to mutate the **next LiveSnapshot**, not a persistent draft.

---

# 6. Required Data Model

## Server state

```luau
export type AppearanceSnapshot = {
	[string]: any,
}

export type PlayerAppearanceState = {
	originalSnapshot: AppearanceSnapshot?,
	liveSnapshot: AppearanceSnapshot?,
	liveRevision: number,

	isApplying: boolean,
	lastApplySource: string?,
}
```

Possible source values:

```text
"initial"
"catalog_try_on"
"morph"
"reset_original"
"respawn_reapply"
```

## Client state

```luau
export type ClientAppearanceState = {
	liveSnapshot: AppearanceSnapshot?,
	liveRevision: number?,
	isApplying: boolean,
	lastApplySource: string?,
}
```

No persistent draft state.

---

# 7. Remote Contracts

## GetAppearanceStateRemote

Client calls when:

```text
catalog opens
currently wearing opens/refreshes
client needs to resync
```

Request:

```luau
{
	action = "GetAppearanceState",
}
```

Response:

```luau
{
	success = true,
	liveSnapshot = {...},
	liveRevision = 3,
	lastApplySource = "morph",
}
```

---

## TryOnCatalogItemRemote / ApplyDescriptionRemote

Recommended request shape:

```luau
{
	action = "TryOnDescription",
	requestId = 101,
	baseLiveRevision = 3,
	description = {...},
}
```

Where `description` is the full next `HumanoidDescription` snapshot.

Response success:

```luau
{
	success = true,
	requestId = 101,
	liveSnapshot = {...},
	liveRevision = 4,
	source = "catalog_try_on",
}
```

Response failure:

```luau
{
	success = false,
	requestId = 101,
	code = "APPLY_IN_PROGRESS",
	message = "Appearance apply is already running.",
	liveSnapshot = {...}?,
	liveRevision = 3?,
}
```

---

## Morph remote/service result

Morph system should use the same service internally.

Response/signal to client:

```luau
{
	success = true,
	liveSnapshot = {...},
	liveRevision = 5,
	source = "morph",
}
```

---

# 8. Sub-Phase Breakdown

Do not implement all at once.

Use these sub-phases:

```text
7.0 Audit current Apply/draft state
7.1 Create AvatarAppearanceService as live state authority
7.2 Add GetAppearanceState remote
7.3 Refactor catalog open to render from LiveSnapshot
7.4 Remove catalog Apply button and persistent draft state
7.5 Implement Try-On as live apply
7.6 Refactor ViewportFrame as LiveSnapshot mirror
7.7 Add Currently Wearing from LiveSnapshot
7.8 Route Morph through AvatarAppearanceService
7.9 Add respawn reapply from LiveSnapshot
7.10 Add race guards / click lock
7.11 Manual test matrix
```

---

# 9. Sub-Phase 7.0 — Audit Current State

## Goal

Find and document all old preview/apply/draft paths.

Inspect:

```text
src/client/logic/AvatarDescriptionDraft.luau
src/client/controllers/AvatarPreviewController.luau
src/client/services/AvatarApplyClient.luau
src/client/services/*Catalog*.luau
src/client/components/*Catalog*.luau

src/server/services/AvatarApplyService.luau
src/server/services/*Morph*.luau
src/server/services/*Avatar*.luau

src/shared/avatar/HumanoidDescriptionSerializer.luau
```

Document current owners:

```text
Original state owner:
Live/current state owner:
Draft/preview state owner:
Apply button path:
Try-On path:
Morph path:
Respawn path:
```

## Acceptance

Before coding, the agent must know which files need migration.

---

# 10. Sub-Phase 7.1 — Create AvatarAppearanceService

## Goal

Centralize all server live appearance changes.

File:

```text
src/server/services/AvatarAppearanceService.luau
```

## API

```luau
local AvatarAppearanceService = {}

function AvatarAppearanceService.initializePlayer(player)
end

function AvatarAppearanceService.getState(player)
end

function AvatarAppearanceService.getLiveSnapshot(player)
end

function AvatarAppearanceService.getLiveRevision(player)
end

function AvatarAppearanceService.applyDescriptionSnapshot(player, snapshot, source)
end

function AvatarAppearanceService.applyMorphFromHumanoid(player, sourceHumanoid)
end

function AvatarAppearanceService.resetToOriginal(player)
end

function AvatarAppearanceService.reapplyLiveSnapshot(player)
end

return AvatarAppearanceService
```

## Initialize behavior

On first valid character humanoid:

```text
humanoid:GetAppliedDescription()
↓
serialize
↓
originalSnapshot = snapshot
liveSnapshot = snapshot
liveRevision = 1
```

Do not overwrite `originalSnapshot` on respawn or morph.

## applyDescriptionSnapshot behavior

```text
if isApplying -> return APPLY_IN_PROGRESS
validate snapshot
deserialize snapshot
humanoid:ApplyDescriptionResetAsync(description, Enum.AssetTypeVerification.Always)
appliedDescription = humanoid:GetAppliedDescription()
appliedSnapshot = serialize(appliedDescription)
liveSnapshot = appliedSnapshot
liveRevision += 1
lastApplySource = source
return liveSnapshot + liveRevision
```

## Acceptance

- Server can initialize original/live.
- Server can apply a snapshot.
- LiveRevision increments only after successful apply.
- LiveSnapshot matches real humanoid after apply.

---

# 11. Sub-Phase 7.2 — Add GetAppearanceState Remote

## Goal

Client can request current live state at any time.

Remote/function:

```text
GetAppearanceStateRemote
```

Response:

```luau
{
	success = true,
	liveSnapshot = {...},
	liveRevision = 1,
	lastApplySource = "initial",
}
```

## Acceptance

- Catalog open can fetch LiveSnapshot.
- Currently Wearing can fetch LiveSnapshot.
- Debug logs show liveRevision/source.

---

# 12. Sub-Phase 7.3 — Catalog Open Renders From LiveSnapshot

## Goal

Opening catalog always reflects the live character.

Flow:

```text
Open catalog
↓
GetAppearanceStateRemote
↓
Client stores liveSnapshot/liveRevision
↓
ViewportFrame render liveSnapshot
↓
Currently Wearing render liveSnapshot
```

Remove old logic:

```text
restore old draft
prompt sync
use stale preview
```

## Acceptance

- Morph first, then open catalog -> viewport shows morph.
- Catalog try-on first, then close/open -> viewport shows latest live try-on.
- No Apply button needed.

---

# 13. Sub-Phase 7.4 — Remove Apply Button and Persistent Draft State

## Goal

Delete or disable the old separate catalog Apply UX.

Remove/disable:

```text
Apply button
unsaved draft restore
dirty draft prompt
persistent DraftSnapshot
DraftBaseRevision
DraftDirty
```

Keep:

```text
loading/applying indicator
reset/original button if available
```

## Acceptance

- There is no user flow where try-on waits for Apply.
- Closing catalog does not save draft.
- Reopening catalog always starts from LiveSnapshot.

---

# 14. Sub-Phase 7.5 — Try-On as Live Apply

## Goal

Clicking a catalog item immediately applies it to live character.

Flow:

```text
User clicks ready card
↓
Read current client liveSnapshot
↓
Deserialize to HumanoidDescription
↓
Mutate description using PreviewPayload
↓
Serialize to nextSnapshot
↓
Send TryOnDescription request to server
↓
Server applies
↓
Client hydrates from server response
```

## Mutation examples

### Hair

```luau
description.HairAccessory = tostring(assetId)
```

### Classic shirt

```luau
description.Shirt = assetId
```

### Classic pants

```luau
description.Pants = assetId
```

### Layered jacket

```luau
description.JacketAccessory = tostring(assetId)
```

### Body bundle

```luau
description.Head = payload.bodyParts.Head or description.Head
description.Torso = payload.bodyParts.Torso or description.Torso
description.LeftArm = payload.bodyParts.LeftArm or description.LeftArm
description.RightArm = payload.bodyParts.RightArm or description.RightArm
description.LeftLeg = payload.bodyParts.LeftLeg or description.LeftLeg
description.RightLeg = payload.bodyParts.RightLeg or description.RightLeg
```

### Animation bundle

```luau
description.IdleAnimation = payload.animations.IdleAnimation or description.IdleAnimation
description.WalkAnimation = payload.animations.WalkAnimation or description.WalkAnimation
description.RunAnimation = payload.animations.RunAnimation or description.RunAnimation
description.JumpAnimation = payload.animations.JumpAnimation or description.JumpAnimation
description.FallAnimation = payload.animations.FallAnimation or description.FallAnimation
description.ClimbAnimation = payload.animations.ClimbAnimation or description.ClimbAnimation
description.SwimAnimation = payload.animations.SwimAnimation or description.SwimAnimation
```

### Emote

For this phase:

```text
Emote preview can play in ViewportFrame only.
Do not mutate LiveSnapshot unless the project explicitly supports equipping emotes.
```

## Acceptance

- Click hair -> live character changes to hair.
- Click jacket -> live character changes to jacket.
- Viewport updates from server response.
- No separate Apply click.

---

# 15. Sub-Phase 7.6 — ViewportFrame as LiveSnapshot Mirror

## Goal

ViewportFrame should mirror `LiveSnapshot`, not an independent draft.

After every successful live apply:

```text
server response liveSnapshot
↓
client liveSnapshot = response.liveSnapshot
↓
ViewportPreviewController.renderSnapshot(liveSnapshot)
```

When catalog opens:

```text
renderSnapshot(liveSnapshot)
```

When morph updates live:

```text
renderSnapshot(liveSnapshot)
```

## Important

Use render token to avoid stale async viewport apply:

```text
old viewport render must not overwrite newer liveSnapshot
```

## Acceptance

- Viewport and live character show same appearance after Try-On.
- Viewport and live character show same appearance after Morph.
- No stale preview draft.

---

# 16. Sub-Phase 7.7 — Currently Wearing UI From LiveSnapshot

## Goal

Add/update Currently Wearing UI to reflect what the user is wearing now.

Source:

```text
LiveSnapshot
```

Not:

```text
catalog draft
last clicked item only
raw UI selected state
```

Initial simple version:

```text
Show categories/properties from LiveSnapshot:
- HairAccessory
- HatAccessory
- FaceAccessory
- Shirt
- Pants
- JacketAccessory
- body parts
- animations
```

Later checkout phase may improve this by mapping IDs back to item details.

## Acceptance

- After catalog Try-On, Currently Wearing updates.
- After morph, Currently Wearing updates.
- After reset, Currently Wearing updates.

---

# 17. Sub-Phase 7.8 — Route Morph Through AvatarAppearanceService

## Goal

Morph and catalog use the same live source of truth.

Morph flow:

```text
User triggers morph
↓
Server finds source humanoid/model
↓
sourceDescription = sourceHumanoid:GetAppliedDescription()
↓
AvatarAppearanceService.applyDescriptionSnapshot(player, serialize(sourceDescription), "morph")
↓
LiveSnapshot updates
↓
Client receives/syncs LiveSnapshot
```

If catalog is open:

```text
Viewport refreshes to morph LiveSnapshot
Currently Wearing refreshes
```

No prompt.  
No draft preservation.

## Acceptance

- Morph while catalog closed -> catalog later shows morph.
- Morph while catalog open -> viewport updates to morph.
- Morph increments LiveRevision.

---

# 18. Sub-Phase 7.9 — Respawn Reapply

## Goal

Respawn preserves LiveSnapshot.

On CharacterAdded:

```text
if LiveSnapshot exists:
  apply LiveSnapshot
else:
  initialize original/live
```

Recommended:

```text
Respawn reapply does not increment LiveRevision
```

Because appearance did not conceptually change.

## Acceptance

- Try-On item
- Respawn
- Same outfit reapplies
- Open catalog -> same outfit

---

# 19. Sub-Phase 7.10 — Race Guards and Click Lock

## Goal

Prevent spam and race conditions.

## Option A — Simple lock

Client:

```text
If isApplying == true:
  disable catalog cards or ignore clicks
```

Server:

```text
If isApplying == true:
  return APPLY_IN_PROGRESS
```

This is recommended for the first implementation.

## Option B — Future latest-wins queue

Later improvement:

```text
If user clicks while applying:
  store latest pending snapshot
When current apply finishes:
  apply latest pending snapshot
```

Do not implement Option B until Option A is stable.

## Required guards

```text
per-player server apply lock
client requestId
viewport render token
ignore stale server responses
```

## Acceptance

- Spam clicking items does not create mixed appearance.
- Old server response does not overwrite newer LiveSnapshot.
- Server does not run two ApplyDescriptionResetAsync calls for same player concurrently.

---

# 20. Manual Test Matrix

Do not mark Phase 7 complete until all pass.

## Test 1 — Join baseline

```text
User joins
Expected:
OriginalSnapshot saved
LiveSnapshot saved
LiveRevision = 1
```

## Test 2 — Open catalog

```text
Open catalog
Expected:
Viewport shows live character
Currently Wearing shows live character
No Apply button
```

## Test 3 — Try-On hair

```text
Click hair A
Expected:
Live character changes to hair A
Viewport shows hair A
Currently Wearing shows hair A

Click hair B
Expected:
Live character changes to hair B
Viewport shows hair B
Currently Wearing shows hair B
```

## Test 4 — Try-On clothing

```text
Click classic shirt A
Expected:
Live character changes immediately
Viewport syncs
Currently Wearing syncs

Click jacket A
Expected:
Live character changes immediately
Viewport syncs
Currently Wearing syncs
```

## Test 5 — Body bundle

```text
Click body bundle A
Expected:
Live character becomes body A
Viewport becomes body A

Click body bundle B
Expected:
Live character becomes body B
Viewport becomes body B
```

## Test 6 — Morph then catalog

```text
Morph into model A
Open catalog
Expected:
Viewport shows model A
Currently Wearing shows model A
```

## Test 7 — Catalog then morph

```text
Open catalog
Try-On hair A
Morph into model B
Expected:
Live character = model B
Viewport = model B
Currently Wearing = model B
```

## Test 8 — Close and reopen

```text
Open catalog
Try-On hair A
Close catalog
Open catalog
Expected:
Viewport shows live hair A
No draft restore logic
```

## Test 9 — Close without any action

```text
Open catalog
Close catalog
Expected:
No state changes
```

## Test 10 — Spam click

```text
Rapidly click hair A, B, C
Expected with Option A:
Only one apply at a time
No mixed state
Final state is one known completed response
```

## Test 11 — Respawn

```text
Try-On outfit A
Respawn
Expected:
Outfit A reapplies
Catalog opens from outfit A
```

## Test 12 — Reset original

```text
Try-On outfit A
Reset to original
Expected:
Live character returns to OriginalSnapshot
Viewport syncs
Currently Wearing syncs
```

---

# 21. What Not To Do

Do not:

```text
- Keep catalog Apply button for outfit changes.
- Keep persistent DraftSnapshot.
- Keep dirty draft prompt.
- Let catalog viewport use stale local draft.
- Let morph and catalog apply through separate services.
- Update LiveSnapshot before server apply succeeds.
- Let multiple live applies run at once.
- Use raw local character changes as trusted server state.
- Add checkout/purchase logic in this phase.
- Parse Currently Wearing for checkout yet.
```

---

# 22. Final Acceptance Criteria

Phase 7 is complete only if:

1. Catalog has no separate Apply button for try-on.
2. Try-On immediately applies to live character through server.
3. LiveSnapshot is the single source of truth for catalog viewport.
4. LiveSnapshot is the single source of truth for Currently Wearing.
5. Morph updates LiveSnapshot through AvatarAppearanceService.
6. Catalog opens from LiveSnapshot every time.
7. Closing catalog does not preserve draft.
8. Morph while catalog is open refreshes viewport/currently wearing.
9. Respawn reapplies LiveSnapshot.
10. OriginalSnapshot remains available for reset.
11. Apply operations are serialized per player.
12. Manual test matrix passes.

---

# 23. Suggested Commit Plan

Use one small commit per sub-phase:

```text
phase7-0-audit-state
phase7-1-avatar-appearance-service
phase7-2-get-appearance-state-remote
phase7-3-catalog-open-from-live-snapshot
phase7-4-remove-apply-button-and-draft-state
phase7-5-tryon-as-live-apply
phase7-6-viewport-mirror-live-snapshot
phase7-7-currently-wearing-from-live-snapshot
phase7-8-morph-through-appearance-service
phase7-9-respawn-reapply-live-snapshot
phase7-10-race-guards
phase7-11-test-matrix-cleanup
```

---

# 24. Short Instruction for AI Agent

Refactor the catalog into a live-first try-on system.

Core rule:

```text
What the player wears live is what the catalog shows.
```

Remove separate Apply workflow.

Use:

```text
OriginalSnapshot
LiveSnapshot
LiveRevision
```

Do not use persistent catalog draft.

Every appearance-changing system must go through:

```text
AvatarAppearanceService
```

Catalog Try-On, Morph, Reset, and Respawn all update or use the same `LiveSnapshot`.

After every successful Try-On or Morph:

```text
server response LiveSnapshot
↓
client updates ViewportFrame
↓
client updates Currently Wearing
```

The final UX should be:

```text
Click item = character changes now.
Morph = character changes now.
Catalog always mirrors current character.
```
