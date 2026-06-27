# Phase 9 Technical Plan — Emote Play Simplification & Viewport Stability

Project: `abayzv/roblox-catalog-avatar`  
Baseline: Phase 8 My Avatar tab + Phase 7 Live-First Try-On flow  
Goal: simplify emote behavior and fix ViewportFrame bugs caused by animation playback conflicting with appearance apply/reset/render.

---

## 0. Why This Phase Exists

Previous Phase 9 idea was Emote Wheel Integration:

```text
Click emote
Preview emote
Equip to emote wheel
Show in My Avatar > Animation
Remove from wheel
```

After testing, this is too complicated for users.

New decision:

```text
Emote is an action, not a worn avatar item.
```

So:

```text
Item Catalog > Emote button = Play
Play = play animation on ViewportFrame and live character
My Avatar does not show Animation tab
Emote does not mutate HumanoidDescription
Emote does not enter emote wheel
```

This aligns with the project rule:

```text
Live character is the source of truth.
```

For appearance items:

```text
Click item = live appearance changes
```

For emotes:

```text
Click Play = live character performs the emote
```

---

## 1. Current Bugs To Fix

### Bug 1 — Body bundle remove restores wrong body

Current issue:

```text
Try-on body bundle
Remove body/body bundle
Expected: body returns to original body from first join
Actual: wrong/empty/stale body may happen
```

Correct behavior:

```text
Remove body bundle
= restore original body-related fields from OriginalSnapshot
```

---

### Bug 2 — Viewport bugs after emote preview then switching tabs/applying item

Current issue:

```text
Try-on/play emote in Animation tab
Viewport plays animation
Switch to another tab
Apply accessory / jacket / body
Viewport bugs / blanks
```

Likely cause:

```text
AnimationTrack is still running while viewport rig/description is being reset/re-rendered.
```

---

### Bug 3 — Viewport bugs when reset character while animation is playing

Current issue:

```text
Play animation/emote
Reset character
Viewport bugs / blanks
```

Likely cause:

```text
AnimationTrack references old humanoid/animator/rig after reset or re-render.
```

---

### Bug 4 — Animation bundle + visual item apply causes blank viewport

Current issue:

```text
Try-on animation bundle or play animation
Then try-on accessory/jacket/body
Viewport may blank
```

Likely cause:

```text
Animation playback and ApplyDescriptionResetAsync/renderSnapshot are not serialized/cleaned up.
```

---

# 2. New UX Rules

## 2.1 My Avatar

Remove/hide this tab/category:

```text
My Avatar > Animation
```

My Avatar should only show appearance items:

```text
Body
3D Clothing
Classic Clothing
Accessories
```

Do not show:

```text
IdleAnimation
WalkAnimation
RunAnimation
JumpAnimation
Emote wheel
Equipped emotes
```

in My Avatar for this phase.

---

## 2.2 Item Catalog > Emote

For emote items:

```text
Button label = Play
```

Behavior:

```text
Click Play
↓
Play emote on ViewportFrame mannequin
↓
Play emote on live character
```

Important:

```text
Do not mutate LiveSnapshot.
Do not mutate HumanoidDescription.
Do not equip to emote wheel.
Do not show in My Avatar.
```

Emote is temporary playback/action.

---

## 2.3 Appearance item behavior remains live-first

For normal items:

```text
hair
accessory
jacket
classic shirt/pants
body bundle
```

Behavior remains:

```text
Click Try-On
↓
LiveSnapshot changes through server
↓
Viewport mirrors server-confirmed LiveSnapshot
```

Before any appearance apply/render:

```text
Stop all active emote/animation preview tracks.
```

---

# 3. Non-Negotiable Technical Rules

### Rule 1 — Animation playback must be separated from appearance rendering

Do not mix animation track logic inside appearance render logic.

Create a dedicated controller:

```text
ViewportAnimationController
```

Appearance rendering remains in:

```text
AvatarPreviewController
```

---

### Rule 2 — Stop animations before any viewport appearance operation

Before these operations:

```text
render LiveSnapshot
apply description to viewport humanoid
apply body bundle
apply accessory/clothing
reset character
morph
switch catalog tab
close catalog
rebuild viewport clone
```

Always call:

```text
ViewportAnimationController.stopAll()
```

---

### Rule 3 — Emote Play must not change LiveSnapshot

Emote Play is not a worn item state.

Do not serialize emote into:

```text
LiveSnapshot
HumanoidDescription
My Avatar data
```

---

### Rule 4 — One animation playback at a time

If user plays a new emote:

```text
stop previous emote track
play new emote
```

Do not let multiple emote tracks stack.

---

### Rule 5 — Viewport render must use token/cancellation

If a previous async viewport render finishes late, it must not overwrite the latest render.

Use:

```text
viewportRenderRevision
```

---

### Rule 6 — Live character animation must be safely stopped/cleared

If live character resets, respawns, or humanoid changes:

```text
clear live animation track references
```

Use `pcall` when stopping tracks that may belong to destroyed instances.

---

# 4. Target Architecture

## 4.1 Controllers

### AvatarPreviewController

Responsible for:

```text
renderSnapshot(liveSnapshot)
rebuild viewport clone if needed
apply HumanoidDescription to viewport humanoid
sync viewport from LiveSnapshot
```

Before rendering appearance, it must call:

```text
ViewportAnimationController.stopViewportAnimation()
```

or:

```text
ViewportAnimationController.stopAll()
```

---

### ViewportAnimationController

New controller responsible for:

```text
play emote on viewport mannequin
play emote on live character
stop viewport animation
stop live animation
stop all animations
clear references on reset/respawn
```

Suggested API:

```luau
local ViewportAnimationController = {}

function ViewportAnimationController.playEmote(assetId: number)
	-- plays on viewport and live character
end

function ViewportAnimationController.playViewportEmote(assetId: number)
end

function ViewportAnimationController.playLiveEmote(assetId: number)
end

function ViewportAnimationController.stopViewportAnimation()
end

function ViewportAnimationController.stopLiveAnimation()
end

function ViewportAnimationController.stopAll()
end

function ViewportAnimationController.onViewportRigRebuilt()
end

function ViewportAnimationController.onLiveCharacterRemoving()
end

return ViewportAnimationController
```

---

## 4.2 State inside ViewportAnimationController

```luau
local currentViewportTrack = nil
local currentLiveTrack = nil
local currentAnimationAssetId = nil
local playbackRevision = 0
```

Do not keep stale track references after:

```text
viewport clone rebuild
character reset
character respawn
tab switch
catalog close
```

---

# 5. Emote Play Flow

## User clicks Play on emote catalog card

```text
1. Validate selected item is emote
2. Extract emote animation asset id
3. Stop previous viewport/live emote tracks
4. Play emote in ViewportFrame mannequin
5. Play emote in live character
6. Do not update LiveSnapshot
7. Do not update My Avatar
```

Pseudo-flow:

```luau
function onEmotePlayClicked(emotePayload)
	local assetId = emotePayload.assetId
	if not assetId then
		warn("[EmotePlay] Missing emote assetId")
		return
	end

	ViewportAnimationController.playEmote(assetId)
end
```

---

## Play on viewport

```luau
function ViewportAnimationController.playViewportEmote(assetId)
	stopViewportAnimation()

	local humanoid = AvatarPreviewController.getViewportHumanoid()
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(assetId)

	local track = animator:LoadAnimation(animation)
	currentViewportTrack = track

	track:Play()
end
```

Important:

```text
Destroy or let temporary Animation instance be cleaned up after loading.
Stop previous track before loading new one.
```

---

## Play on live character

```luau
function ViewportAnimationController.playLiveEmote(assetId)
	stopLiveAnimation()

	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(assetId)

	local track = animator:LoadAnimation(animation)
	currentLiveTrack = track

	track:Play()
end
```

Note:

```text
Live local animation playback is acceptable for user-facing emote play.
If server replication is required later, make a separate server-authorized PlayEmoteRemote.
Do not add server emote replication complexity in this phase unless necessary.
```

---

# 6. Stop/Cleanup Rules

## stopViewportAnimation

```luau
local function stopTrack(track)
	if not track then
		return
	end

	pcall(function()
		track:Stop(0)
	end)

	pcall(function()
		track:Destroy()
	end)
end

function ViewportAnimationController.stopViewportAnimation()
	stopTrack(currentViewportTrack)
	currentViewportTrack = nil
end
```

## stopLiveAnimation

```luau
function ViewportAnimationController.stopLiveAnimation()
	stopTrack(currentLiveTrack)
	currentLiveTrack = nil
end
```

## stopAll

```luau
function ViewportAnimationController.stopAll()
	stopViewportAnimation()
	stopLiveAnimation()
	currentAnimationAssetId = nil
	playbackRevision += 1
end
```

Call `stopAll()` on:

```text
catalog close
tab switch away from Emote/Animation catalog
before visual item try-on
before body bundle try-on
before reset original
before morph render sync
before viewport renderSnapshot
before viewport clone rebuild
on character removing/respawn
```

---

# 7. Viewport Render Stability

## AvatarPreviewController.renderSnapshot

Before applying description:

```luau
function AvatarPreviewController.renderSnapshot(snapshot)
	ViewportAnimationController.stopViewportAnimation()

	viewportRenderRevision += 1
	local revision = viewportRenderRevision

	task.spawn(function()
		local humanoid = getViewportHumanoid()
		if not humanoid then
			return
		end

		local description = HumanoidDescriptionSerializer.deserialize(snapshot)

		local ok, err = pcall(function()
			humanoid:ApplyDescriptionResetAsync(
				description,
				Enum.AssetTypeVerification.Always
			)
		end)

		if revision ~= viewportRenderRevision then
			return
		end

		if not ok then
			warn("[AvatarPreviewController] renderSnapshot failed:", err)
			rebuildViewportFromLiveSnapshot()
		end
	end)
end
```

Important:

```text
Do not let old render finish after new render and overwrite viewport.
```

---

# 8. Remove Body Bundle Behavior

## Goal

When removing body bundle/body-related shape, restore original body from first join.

Use:

```text
OriginalSnapshot
```

not empty values.

## Body fields to restore

Restore these from OriginalSnapshot if available:

```text
Head
Torso
LeftArm
RightArm
LeftLeg
RightLeg
```

Also restore body scale fields:

```text
BodyTypeScale
DepthScale
HeadScale
HeightScale
ProportionScale
WidthScale
```

If serializer supports body colors, also restore:

```text
HeadColor
TorsoColor
LeftArmColor
RightArmColor
LeftLegColor
RightLegColor
```

If serializer does not support body colors yet, do not add body colors in this phase unless needed.

---

## Remove body flow

```text
User removes body/body bundle from My Avatar
↓
Client requests/uses OriginalSnapshot
↓
nextSnapshot = clone LiveSnapshot
↓
copy body fields from OriginalSnapshot to nextSnapshot
↓
send nextSnapshot through live appearance apply pipeline
↓
server applies
↓
server returns LiveSnapshot
↓
viewport syncs
```

Pseudo:

```luau
local BODY_RESTORE_FIELDS = {
	"Head",
	"Torso",
	"LeftArm",
	"RightArm",
	"LeftLeg",
	"RightLeg",

	"BodyTypeScale",
	"DepthScale",
	"HeadScale",
	"HeightScale",
	"ProportionScale",
	"WidthScale",
}

local function restoreOriginalBody(liveSnapshot, originalSnapshot)
	local nextSnapshot = deepClone(liveSnapshot)

	for _, propertyName in ipairs(BODY_RESTORE_FIELDS) do
		if originalSnapshot[propertyName] ~= nil then
			nextSnapshot[propertyName] = originalSnapshot[propertyName]
		end
	end

	return nextSnapshot
end
```

---

# 9. My Avatar Animation Tab Removal

## Goal

Remove Animation tab/category from My Avatar.

Update:

```text
MyAvatarCategoryConfig
WornItemExtractor
MyAvatar UI
```

Remove/hide:

```text
Animation main category
Animation subcategory
Idle/Walk/Run/etc worn item extraction
Emote wheel extraction if it was added
```

My Avatar categories should be:

```text
All
Body
3D Clothing
Classic Clothing
Accessories
```

For `All` subcategories:

```text
All
Body
3D Clothing
Classic Clothing
Accessories
```

No Animation.

---

# 10. Catalog Emote Button Label Change

For catalog item type:

```text
EmoteAnimation
```

or payload kind:

```text
Emote
```

button label should be:

```text
Play
```

Not:

```text
Try On
Apply
Equip
```

Behavior:

```text
Play animation only.
Do not alter appearance snapshot.
```

---

# 11. Sub-Phase Breakdown

Do not implement everything at once.

Use this order:

```text
9.0 Audit animation/emote/viewport code
9.1 Add ViewportAnimationController
9.2 Stop animation before viewport render/apply/reset
9.3 Change catalog emote action to Play
9.4 Play emote on viewport + live character
9.5 Remove Animation from My Avatar
9.6 Fix body bundle remove to restore OriginalSnapshot body
9.7 Add viewport render token / stale render guard
9.8 Add cleanup on tab switch/catalog close/character reset
9.9 Manual test matrix
```

---

# 12. Sub-Phase 9.0 — Audit

Inspect:

```text
AvatarPreviewController
AvatarAppearanceClient
Catalog Try-On controller
Catalog item card/button component
MyAvatarCategoryConfig
WornItemExtractor
My Avatar page
Reset character/original flow
Morph flow
CharacterAdded/CharacterRemoving handling
```

Find:

```text
where emote preview is played
where viewport ApplyDescriptionResetAsync is called
where catalog tab switch is handled
where character reset is handled
where body remove is handled
```

Acceptance:

```text
Agent knows all call sites that must call ViewportAnimationController.stopAll().
```

---

# 13. Sub-Phase 9.1 — Add ViewportAnimationController

Implement controller with:

```text
playEmote
playViewportEmote
playLiveEmote
stopViewportAnimation
stopLiveAnimation
stopAll
onViewportRigRebuilt
onLiveCharacterRemoving
```

Acceptance:

```text
Can play one emote in viewport.
Playing second emote stops first.
stopAll clears both viewport and live tracks.
```

---

# 14. Sub-Phase 9.2 — Stop Before Appearance Operations

Add calls before:

```text
visual item try-on
body bundle try-on
accessory/clothing try-on
renderSnapshot
reset original
morph sync
viewport clone rebuild
```

Acceptance:

```text
Playing emote then applying accessory no longer blanks viewport.
```

---

# 15. Sub-Phase 9.3 — Emote Button Becomes Play

Update UI:

```text
Emote card button label = Play
```

Acceptance:

```text
Normal item still says Try On or existing label.
Emote item says Play.
```

---

# 16. Sub-Phase 9.4 — Play Emote on Viewport + Live

Click Play:

```text
plays on viewport mannequin
plays on live character
does not mutate LiveSnapshot
does not call appearance apply remote
```

Acceptance:

```text
Click Play -> viewport animates
Click Play -> live avatar animates
My Avatar does not change
```

---

# 17. Sub-Phase 9.5 — Remove Animation from My Avatar

Remove/hide Animation category.

Acceptance:

```text
My Avatar categories no longer include Animation.
All subcategories do not include Animation.
```

---

# 18. Sub-Phase 9.6 — Body Bundle Remove Restores Original Body

Update body remove behavior.

Acceptance:

```text
Try-on body bundle A
Remove body
Expected:
body returns to original body from first join
not empty body
not stale previous body
```

---

# 19. Sub-Phase 9.7 — Viewport Render Token

Add stale render guard.

Acceptance:

```text
Rapidly apply body/accessory/jacket while animations are stopped
Viewport ends on latest LiveSnapshot
No old render overwrites new render
```

---

# 20. Sub-Phase 9.8 — Cleanup Hooks

Call stopAll on:

```text
switch away from emote category/tab
catalog close
reset character
character removing
viewport rig rebuilt
```

Acceptance:

```text
Play emote
Switch tab
Expected:
animation stops cleanly

Play emote
Reset character
Expected:
no viewport blank
no errors from destroyed tracks
```

---

# 21. Manual Test Matrix

Do not mark Phase 9 complete until all pass.

## Test 1 — Emote Play

```text
Open catalog emote category
Click Play on emote A
Expected:
viewport plays emote A
live character plays emote A
LiveSnapshot unchanged
```

## Test 2 — Emote then accessory

```text
Play emote A
Click accessory Try-On
Expected:
emote stops
accessory applies
viewport renders accessory
no blank viewport
```

## Test 3 — Emote then body bundle

```text
Play emote A
Try-on body bundle
Expected:
emote stops
body applies
viewport renders body
no blank viewport
```

## Test 4 — Emote then reset

```text
Play emote A
Reset character
Expected:
emote stops
character resets
viewport renders reset character
no blank viewport
```

## Test 5 — Switch tab

```text
Play emote A
Switch to clothing/accessory tab
Expected:
emote stops or at least does not break next render
```

## Test 6 — Multiple emote clicks

```text
Play emote A
Play emote B
Expected:
emote A stops
emote B plays
no stacked tracks
```

## Test 7 — My Avatar categories

```text
Open My Avatar
Expected:
No Animation category
All subcategories do not include Animation
```

## Test 8 — Body remove

```text
Join with original body O
Try-on body bundle A
Remove body
Expected:
body returns to O
```

## Test 9 — Animation bundle then visual item

```text
Use animation/emote flow
Try-on jacket/accessory/body
Expected:
viewport does not blank
```

## Test 10 — Live-first still works

```text
Try-on hair
Expected:
live character changes
viewport syncs
My Avatar updates
```

---

# 22. What Not To Do

Do not:

```text
- Continue Phase 9 emote wheel integration.
- Add Equip button.
- Add Remove emote in My Avatar.
- Add Animation category in My Avatar.
- Mutate HumanoidDescription for emote Play.
- Add emote to emote wheel.
- Let animation track continue while applying/resetting viewport appearance.
- Let old viewport render overwrite newer render.
- Empty body fields when removing body bundle.
```

---

# 23. Final Acceptance Criteria

Phase 9 is complete only if:

1. My Avatar no longer shows Animation category.
2. Emote catalog button says Play.
3. Play emote animates ViewportFrame mannequin.
4. Play emote animates live character.
5. Play emote does not change LiveSnapshot/HumanoidDescription.
6. Active animation tracks stop before appearance apply/render/reset.
7. Viewport no longer blanks after emote + accessory/body/jacket apply.
8. Viewport no longer blanks after emote + reset character.
9. Body bundle remove restores original body from OriginalSnapshot.
10. Manual test matrix passes.

---

# 24. Suggested Commit Plan

```text
phase9-0-audit-viewport-animation-flow
phase9-1-add-viewport-animation-controller
phase9-2-stop-animation-before-appearance-render
phase9-3-emote-button-play-label
phase9-4-play-emote-viewport-live
phase9-5-remove-animation-from-my-avatar
phase9-6-body-remove-restores-original
phase9-7-viewport-render-token
phase9-8-cleanup-hooks
phase9-9-test-matrix-cleanup
```

---

# 25. Short Instruction for AI Agent

Implement Phase 9 as animation simplification and viewport stability.

New behavior:

```text
Emote = Play action only.
Play animates viewport and live character.
Emote does not change LiveSnapshot.
Emote does not go to My Avatar.
```

Remove:

```text
My Avatar > Animation
Emote wheel equip/remove flow
```

Fix:

```text
Stop all animation tracks before any viewport appearance render/apply/reset.
Use render tokens to prevent stale viewport renders.
Body remove restores original body from OriginalSnapshot.
```
