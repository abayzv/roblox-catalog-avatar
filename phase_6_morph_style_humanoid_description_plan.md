# Phase 6 Technical Plan — Morph-Style HumanoidDescription Apply

Project: `abayzv/roblox-catalog-avatar`  
Baseline checkpoint: Phase 5 clean checkpoint  
Goal: make **Apply result always match ViewportFrame preview** using a simpler Morph-style pipeline.

---

## 0. Core Idea

Previous Phase 6 direction was too complex:

```text
Item entries
↓
Slot resolver
↓
Server resolver
↓
Server normalization
↓
HumanoidDescription builder
↓
Apply
```

For the current goal, that is overkill.

The feature is not checkout/purchase.  
The feature is temporary in-game try-on.

So the better model is closer to a classic Roblox Morph system:

```text
Preview humanoid already has the desired final appearance
↓
Get/copy its HumanoidDescription
↓
Apply the same HumanoidDescription to the real character
```

Because the preview is client-side, the server cannot directly access the ViewportFrame humanoid.  
So the client must send a **serialized HumanoidDescription snapshot** to the server.

---

## 1. Target Flow

```text
User clicks catalog card
↓
Client updates draft HumanoidDescription
↓
Client applies draft HumanoidDescription to ViewportFrame humanoid
↓
User sees preview
↓
User clicks Apply
↓
Client serializes draft HumanoidDescription
↓
Server validates snapshot shape lightly
↓
Server reconstructs HumanoidDescription
↓
Server applies it to real character using ApplyDescriptionResetAsync
↓
Server returns applied HumanoidDescription snapshot
↓
Client hydrates draft/applied state from server response
↓
Preview and live character stay synced
```

Main rule:

```text
Preview and Apply must use the same HumanoidDescription snapshot.
```

This is how we prevent:

```text
"Preview-nya A, tapi yang ke-apply B"
```

---

## 2. What This Phase Is Not

Do not add purchase/checkout logic.

Do not add:

```text
PlayerOwnsAsset checks
Robux validation
PromptPurchase
Price validation
Seller validation
Creator validation
Marketplace cart logic
```

This phase is only for:

```text
temporary in-game outfit apply
```

---

## 3. Non-Negotiable Rules

### Rule 1 — HumanoidDescription is the source of truth

For Phase 6, the source of truth is:

```text
draft HumanoidDescription
```

Not:

```text
itemIds
entries
slot resolver
appliedEntries + previewPayloads
```

Item payloads are still useful for UI and try-on actions, but the final Apply should use the HumanoidDescription snapshot.

### Rule 2 — Try-On mutates draftDescription

When user clicks a card:

```text
PreviewPayload
↓
mutate draftDescription
↓
apply draftDescription to ViewportFrame
```

### Rule 3 — Apply serializes draftDescription

When user clicks Apply:

```text
serialize(draftDescription)
↓
send to server
```

Do not send raw `itemIds` as final apply source.

### Rule 4 — Server reconstructs and applies HumanoidDescription

Server:

```text
deserialize snapshot
↓
Instance.new("HumanoidDescription")
↓
assign whitelisted properties
↓
ApplyDescriptionResetAsync(description, Enum.AssetTypeVerification.Always)
```

### Rule 5 — Server response wins

After server Apply succeeds, server returns the actual applied description snapshot.

Client must hydrate from server response.

If server result differs from client preview, server result wins and preview must refresh.

### Rule 6 — One Apply per player at a time

Do not allow overlapping Apply operations.

If player clicks Apply multiple times quickly:

```text
ignore/reject while applying
```

---

# 4. Phase Breakdown

Do not implement all at once.

Use these sub-phases:

```text
6.0 Add Apply debug logs
6.1 Add HumanoidDescription serializer
6.2 Introduce client draftDescription
6.3 Update Try-On to mutate draftDescription
6.4 Update ViewportFrame preview to render from draftDescription
6.5 Update Apply remote contract to send description snapshot
6.6 Server deserialize + ApplyDescriptionResetAsync
6.7 Server response hydration
6.8 Respawn reapply from applied snapshot
6.9 Manual test matrix
```

---

# 5. Sub-Phase 6.0 — Debug Logs First

## Goal

Before changing behavior, add logs to see the current flow.

## Client logs

Before preview apply:

```text
[Preview] applying draft description:
HairAccessory=...
JacketAccessory=...
Shirt=...
Pants=...
Head=...
WalkAnimation=...
```

Before server Apply:

```text
[Apply:Client] revision=12 snapshot:
HairAccessory=...
JacketAccessory=...
Shirt=...
Pants=...
```

## Server logs

When receiving Apply:

```text
[Apply:Server] received revision=12
[Apply:Server] description snapshot summary=...
```

After Apply:

```text
[Apply:Server] applied revision=12
[Apply:Server] applied snapshot summary=...
```

## Acceptance

Logs must clearly show:

```text
what preview used
what client sent
what server applied
what server returned
```

---

# 6. Sub-Phase 6.1 — Add HumanoidDescriptionSerializer

Create shared module:

```text
src/shared/avatar/HumanoidDescriptionSerializer.luau
```

This module is used by both client and server.

## API

```luau
local HumanoidDescriptionSerializer = {}

function HumanoidDescriptionSerializer.serialize(description: HumanoidDescription): table
	-- returns plain table
end

function HumanoidDescriptionSerializer.deserialize(snapshot: table): HumanoidDescription
	-- returns Instance.new("HumanoidDescription")
end

function HumanoidDescriptionSerializer.validateSnapshot(snapshot: table): (boolean, string?)
	-- validates shape, property whitelist, numbers, CSV strings
end

return HumanoidDescriptionSerializer
```

---

## 6.1.1 Whitelisted number properties

Support these number properties first:

```luau
local NUMBER_PROPERTIES = {
	-- Body parts
	"Head",
	"Torso",
	"LeftArm",
	"RightArm",
	"LeftLeg",
	"RightLeg",

	-- Classic clothing / face
	"Face",
	"Shirt",
	"Pants",
	"GraphicTShirt",

	-- Body scale
	"BodyTypeScale",
	"DepthScale",
	"HeadScale",
	"HeightScale",
	"ProportionScale",
	"WidthScale",

	-- Animations
	"IdleAnimation",
	"WalkAnimation",
	"RunAnimation",
	"JumpAnimation",
	"FallAnimation",
	"ClimbAnimation",
	"SwimAnimation",
}
```

Note:

```text
Asset ids can be 0 when empty/default.
Scale values are numbers, usually 0-1 or engine-supported ranges.
```

For Phase 6, use light validation:

```text
number property must be number
asset id property must be >= 0
scale property must be reasonable, for example 0 <= value <= 2
```

---

## 6.1.2 Whitelisted accessory CSV string properties

Support these string properties:

```luau
local STRING_PROPERTIES = {
	-- Rigid accessories
	"HatAccessory",
	"HairAccessory",
	"FaceAccessory",
	"NeckAccessory",
	"ShouldersAccessory",
	"ShoulderAccessory",
	"FrontAccessory",
	"BackAccessory",
	"WaistAccessory",

	-- Layered clothing
	"TShirtAccessory",
	"ShirtAccessory",
	"PantsAccessory",
	"JacketAccessory",
	"SweaterAccessory",
	"ShortsAccessory",
	"DressSkirtAccessory",
	"LeftShoeAccessory",
	"RightShoeAccessory",
}
```

Important:

```text
Roblox property may be ShoulderAccessory or ShouldersAccessory depending on usage/version.
Check current project code and Roblox autocomplete.
Support the one that exists in the current environment.
Do not crash if one property is unavailable.
```

Validation:

```text
string must be empty or CSV of numeric asset ids
max length per string property: 300
max ids per property: 10
```

For Phase 6 single-replacement behavior, most properties will contain 0 or 1 id.

---

## 6.1.3 Optional accessory blob / SetAccessories note

Do not edit `AccessoryBlob` manually in Phase 6.

If layered clothing order becomes inaccurate later, create a future phase to use:

```text
HumanoidDescription:GetAccessories(true)
HumanoidDescription:SetAccessories(accessories, true)
```

For now, keep Phase 6 simple and deterministic.

---

## 6.1.4 Serializer pseudo-code

```luau
local function safeRead(description, propertyName)
	local ok, value = pcall(function()
		return description[propertyName]
	end)

	if ok then
		return value
	end

	return nil
end

function HumanoidDescriptionSerializer.serialize(description)
	local snapshot = {}

	for _, propertyName in ipairs(NUMBER_PROPERTIES) do
		local value = safeRead(description, propertyName)
		if value ~= nil then
			snapshot[propertyName] = value
		end
	end

	for _, propertyName in ipairs(STRING_PROPERTIES) do
		local value = safeRead(description, propertyName)
		if value ~= nil then
			snapshot[propertyName] = value
		end
	end

	return snapshot
end
```

Deserialize:

```luau
function HumanoidDescriptionSerializer.deserialize(snapshot)
	local description = Instance.new("HumanoidDescription")

	for _, propertyName in ipairs(NUMBER_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			pcall(function()
				description[propertyName] = value
			end)
		end
	end

	for _, propertyName in ipairs(STRING_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			pcall(function()
				description[propertyName] = value
			end)
		end
	end

	return description
end
```

---

## Acceptance

Manual test:

```text
Get current humanoid applied description
serialize
deserialize
apply to dummy
result should visually match source
```

---

# 7. Sub-Phase 6.2 — Client Draft HumanoidDescription

## Goal

Add one draft HumanoidDescription as the source of truth for preview/apply.

Create or refactor:

```text
src/client/logic/AvatarDescriptionDraft.luau
```

## State

```luau
local originalDescription: HumanoidDescription? = nil
local appliedDescription: HumanoidDescription? = nil
local draftDescription: HumanoidDescription? = nil
```

## API

```luau
AvatarDescriptionDraft.initializeFromCharacter(character)
AvatarDescriptionDraft.getDraftDescription()
AvatarDescriptionDraft.setDraftDescription(description)
AvatarDescriptionDraft.resetDraftToApplied()
AvatarDescriptionDraft.markApplied(description)
AvatarDescriptionDraft.isDirty()
AvatarDescriptionDraft.serializeDraft()
```

## Initialize

When catalog opens or player character loads:

```text
humanoid:GetAppliedDescription()
↓
originalDescription = clone
appliedDescription = clone
draftDescription = clone
```

## Dirty state

For Phase 6 simple dirty state:

```text
dirty = true after any Try-On mutation
dirty = false after successful server apply/hydration
```

Do not implement complex diff yet.

---

# 8. Sub-Phase 6.3 — Try-On Mutates DraftDescription

## Goal

Clicking a ready catalog card should update draftDescription directly.

Input:

```text
PreviewPayload
```

Output:

```text
mutated draftDescription
```

## Payload examples and mutations

### Hair

```luau
draftDescription.HairAccessory = tostring(assetId)
```

### Hat

```luau
draftDescription.HatAccessory = tostring(assetId)
```

### Back accessory

```luau
draftDescription.BackAccessory = tostring(assetId)
```

### Classic shirt

```luau
draftDescription.Shirt = assetId
```

### Classic pants

```luau
draftDescription.Pants = assetId
```

### Classic T-shirt

```luau
draftDescription.GraphicTShirt = assetId
```

### Layered jacket

```luau
draftDescription.JacketAccessory = tostring(assetId)
```

### Layered shirt

```luau
draftDescription.ShirtAccessory = tostring(assetId)
```

### Layered pants

```luau
draftDescription.PantsAccessory = tostring(assetId)
```

### Body bundle

```luau
draftDescription.Head = payload.bodyParts.Head or draftDescription.Head
draftDescription.Torso = payload.bodyParts.Torso or draftDescription.Torso
draftDescription.LeftArm = payload.bodyParts.LeftArm or draftDescription.LeftArm
draftDescription.RightArm = payload.bodyParts.RightArm or draftDescription.RightArm
draftDescription.LeftLeg = payload.bodyParts.LeftLeg or draftDescription.LeftLeg
draftDescription.RightLeg = payload.bodyParts.RightLeg or draftDescription.RightLeg
```

### Animation bundle

```luau
draftDescription.IdleAnimation = payload.animations.IdleAnimation or draftDescription.IdleAnimation
draftDescription.WalkAnimation = payload.animations.WalkAnimation or draftDescription.WalkAnimation
draftDescription.RunAnimation = payload.animations.RunAnimation or draftDescription.RunAnimation
draftDescription.JumpAnimation = payload.animations.JumpAnimation or draftDescription.JumpAnimation
draftDescription.FallAnimation = payload.animations.FallAnimation or draftDescription.FallAnimation
draftDescription.ClimbAnimation = payload.animations.ClimbAnimation or draftDescription.ClimbAnimation
draftDescription.SwimAnimation = payload.animations.SwimAnimation or draftDescription.SwimAnimation
```

### Emote

Emote should stay preview-only unless explicitly designed as equipped emote.

For Phase 6:

```text
Click emote -> play animation on ViewportFrame only
Do not mutate draftDescription for emote
Do not include emote in Apply snapshot
```

---

## Important

Do not call catalog APIs during Try-On.

Try-On can call:

```text
PreviewPayloadCache read
draftDescription mutation
ViewportFrame apply
```

Try-On must not call:

```text
SearchCatalogAsync
GetItemDetailsAsync
GetBatchItemDetailsAsync
bundle parsing APIs
```

---

## Acceptance

Try these in preview:

```text
Hair A -> Hair B -> Hair C
Expected: draftDescription.HairAccessory == C only

Body A -> Body B -> Body C
Expected: draftDescription body properties == C only

Jacket A -> Jacket B
Expected: draftDescription.JacketAccessory == B only

Hair C + Shirt A
Expected: draftDescription has Hair C and Shirt A
```

---

# 9. Sub-Phase 6.4 — ViewportFrame Renders From DraftDescription

## Goal

Preview must be built from the same draftDescription that will be serialized for Apply.

Flow:

```text
Try-On mutates draftDescription
↓
ViewportPreviewController.applyDraftDescription(draftDescription)
```

Use request/revision token to avoid stale async apply:

```luau
local previewRevision = 0

function applyDraftDescription(description)
	previewRevision += 1
	local currentRevision = previewRevision

	task.spawn(function()
		local ok, err = pcall(function()
			previewHumanoid:ApplyDescriptionResetAsync(
				description,
				Enum.AssetTypeVerification.Always
			)
		end)

		if currentRevision ~= previewRevision then
			return
		end

		if not ok then
			warn("[ViewportPreview] apply failed:", err)
		end
	end)
end
```

Important:

```text
If user clicks multiple items quickly, older preview apply result must not overwrite newer apply result.
```

## Acceptance

Spam click hair/body/clothing:

```text
final viewport result equals latest draftDescription
no old item comes back
```

---

# 10. Sub-Phase 6.5 — Apply Remote Contract Uses Description Snapshot

## New request shape

```luau
{
	action = "ApplyDescription",
	revision = 12,
	description = {
		HairAccessory = "123",
		JacketAccessory = "456",
		Shirt = 789,
		Pants = 111,
		Head = 222,
		WalkAnimation = 333,
	}
}
```

## Client apply flow

```luau
local snapshot = HumanoidDescriptionSerializer.serialize(
	AvatarDescriptionDraft.getDraftDescription()
)

ApplyRemote:InvokeServer({
	action = "ApplyDescription",
	revision = revision,
	description = snapshot,
})
```

## Remove/avoid

Do not use this as primary apply path anymore:

```luau
itemIds
entries
server slot resolver
server bundle resolver for final apply
```

Those may still exist for UI/cache/future checkout, but not for Phase 6 Apply.

---

# 11. Sub-Phase 6.6 — Server Deserialize + Apply

## Server flow

```text
receive payload
↓
check per-player apply lock
↓
validate payload.description
↓
deserialize to HumanoidDescription
↓
ApplyDescriptionResetAsync(description, Enum.AssetTypeVerification.Always)
↓
GetAppliedDescription
↓
serialize applied description
↓
return to client
```

## Server pseudo-code

```luau
local applyingByUserId = {}

local function handleApplyDescription(player, payload)
	if applyingByUserId[player.UserId] then
		return {
			success = false,
			code = "APPLY_IN_PROGRESS",
			message = "Apply is already running",
			revision = payload.revision,
		}
	end

	applyingByUserId[player.UserId] = true

	local ok, result = pcall(function()
		local valid, reason = HumanoidDescriptionSerializer.validateSnapshot(payload.description)
		if not valid then
			return {
				success = false,
				code = "INVALID_DESCRIPTION",
				message = reason,
				revision = payload.revision,
			}
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not humanoid then
			return {
				success = false,
				code = "NO_HUMANOID",
				message = "Character humanoid not found",
				revision = payload.revision,
			}
		end

		local description = HumanoidDescriptionSerializer.deserialize(payload.description)

		humanoid:ApplyDescriptionResetAsync(
			description,
			Enum.AssetTypeVerification.Always
		)

		local appliedDescription = humanoid:GetAppliedDescription()
		local appliedSnapshot = HumanoidDescriptionSerializer.serialize(appliedDescription)

		-- cache for respawn
		PlayerAppliedDescriptions[player.UserId] = appliedSnapshot

		return {
			success = true,
			revision = payload.revision,
			description = appliedSnapshot,
		}
	end)

	applyingByUserId[player.UserId] = nil

	if not ok then
		warn("[AvatarApplyService] ApplyDescription error:", result)
		return {
			success = false,
			code = "APPLY_ERROR",
			message = "Apply failed",
			revision = payload.revision,
		}
	end

	return result
end
```

## Validation

Keep validation light:

```text
payload must be table
action == "ApplyDescription"
revision must be number
description must be table
only whitelisted properties allowed
number properties must be number
asset id numbers must be >= 0
scale values must be reasonable
string properties must be empty or CSV numeric ids
max string length per accessory property: 300
max ids per accessory property: 10
```

## Acceptance

Server can apply the exact snapshot sent by client.

---

# 12. Sub-Phase 6.7 — Server Response Hydration

## Goal

After server apply, client must sync from server-confirmed result.

Client response handling:

```luau
if response.success then
	local appliedDescription = HumanoidDescriptionSerializer.deserialize(response.description)

	AvatarDescriptionDraft.markApplied(appliedDescription)
	ViewportPreviewController.applyDraftDescription(appliedDescription)
else
	warn("[Apply] failed:", response.code, response.message)
end
```

Important:

```text
Server response wins.
```

If server strips/rejects/changes anything, client must reflect server state.

## Acceptance

After Apply:

```text
draftDescription == server applied description
appliedDescription == server applied description
viewport refreshes from server applied description
dirty=false
```

---

# 13. Sub-Phase 6.8 — Respawn Reapply

## Goal

Temporary outfit should persist during the game session after respawn.

Server stores:

```luau
local PlayerAppliedDescriptions = {
	[userId] = snapshot,
}
```

On `CharacterAdded`:

```luau
local snapshot = PlayerAppliedDescriptions[player.UserId]
if snapshot then
	local description = HumanoidDescriptionSerializer.deserialize(snapshot)
	humanoid:ApplyDescriptionResetAsync(
		description,
		Enum.AssetTypeVerification.Always
	)
end
```

## Acceptance

```text
Apply outfit
Reset character
Expected: same outfit reapplies
```

---

# 14. Sub-Phase 6.9 — Optional Preview/Apply Parity Check

## Goal

Detect if preview and apply are drifting.

Before Apply, client can compute:

```text
previewSnapshot = serialize(draftDescription)
applySnapshot = serialize(draftDescription)
```

They should be identical because they come from the same object.

Add debug:

```text
[Parity] preview snapshot hash=abc
[Parity] apply snapshot hash=abc
```

A simple hash can be made by concatenating sorted key/value pairs.

This is optional but helpful for debugging.

---

# 15. Manual Test Matrix

Do not mark Phase 6 complete until this passes.

## Hair replacement

```text
Try-On hair A
Preview expected: hair A
Apply
Live character expected: hair A

Try-On hair B
Preview expected: hair B only
Apply
Live character expected: hair B only

Try-On hair C
Preview expected: hair C only
Apply
Live character expected: hair C only
```

## Body bundle replacement

```text
Try-On body bundle A
Preview expected: body A
Apply
Live character expected: body A

Try-On body bundle B
Preview expected: body B only
Apply
Live character expected: body B only

Try-On body bundle C
Preview expected: body C only
Apply
Live character expected: body C only
```

## Clothing + hair

```text
Try-On hair A
Apply
Live expected: hair A

Try-On classic shirt A
Preview expected: hair A + shirt A
Apply
Live expected: hair A + shirt A

Try-On hair B
Preview expected: hair B + shirt A
Apply
Live expected: hair B + shirt A
```

## Layered clothing

```text
Try-On jacket A
Preview expected: jacket A
Apply
Live expected: jacket A

Try-On jacket B
Preview expected: jacket B only
Apply
Live expected: jacket B only

Try-On layered pants A
Preview expected: jacket B + pants A
Apply
Live expected: jacket B + pants A
```

## Animation bundle

```text
Try-On animation bundle A
Preview expected: animation A
Apply
Live expected: animation A

Try-On animation bundle B
Preview expected: animation B
Apply
Live expected: animation B
```

## Emote

```text
Click emote A
Preview expected: viewport plays emote

Apply
Expected: emote does not mutate outfit unless explicitly designed
```

## Fast clicking

```text
Spam Try-On hair/body/clothing
Expected: final preview equals latest draftDescription

Click Apply twice quickly
Expected: second apply is rejected/ignored while first is running
Expected: no stale outfit overwrites result
```

## Respawn

```text
Apply outfit A
Reset character
Expected: outfit A reapplies exactly
```

---

# 16. What Not To Do

Do not:

```text
- Reintroduce complex slot resolver in Phase 6.
- Use raw itemIds as final apply source.
- Build server HumanoidDescription from stale appliedEntries.
- Merge appliedEntries + previewPayloads to decide final apply.
- Let preview use one state and apply use another state.
- Add purchase/ownership logic.
- Let multiple Apply operations overlap.
- Trust arbitrary non-whitelisted description properties.
- Edit AccessoryBlob manually.
- Preload all physical assets aggressively.
```

---

# 17. Final Acceptance Criteria

Phase 6 is complete only if:

1. Client has a single draft HumanoidDescription source of truth.
2. Try-On mutates draftDescription.
3. Viewport preview renders from draftDescription.
4. Apply sends serialized draftDescription.
5. Server reconstructs HumanoidDescription from the snapshot.
6. Server applies with `ApplyDescriptionResetAsync(..., Enum.AssetTypeVerification.Always)`.
7. Server returns applied HumanoidDescription snapshot.
8. Client hydrates draft/applied state from server response.
9. Preview and live character match after Apply.
10. Old hair/body/clothing no longer randomly comes back.
11. Respawn reapplies the last applied temporary outfit.
12. Manual test matrix passes.

---

# 18. Suggested Commit Plan

```text
phase6-0-debug-logs
phase6-1-humanoid-description-serializer
phase6-2-client-description-draft
phase6-3-tryon-mutates-draft-description
phase6-4-viewport-renders-from-draft-description
phase6-5-apply-description-remote-contract
phase6-6-server-deserialize-and-apply-description
phase6-7-server-response-hydration
phase6-8-respawn-reapply-description
phase6-9-test-matrix-cleanup
```

---

# 19. Short Instruction for AI Agent

Implement Phase 6 using a Morph-style HumanoidDescription pipeline.

The goal is simple:

```text
The HumanoidDescription used by the ViewportFrame preview must be the same HumanoidDescription sent to the server for Apply.
```

Do not make server rebuild the outfit from item ids.

Do not add slot resolver complexity in this phase.

Use:

```text
draft HumanoidDescription
↓
serialize
↓
server deserialize
↓
ApplyDescriptionResetAsync
↓
server returns applied snapshot
↓
client hydrates
```

This is the simplest way to make:

```text
preview result == live character result
```
