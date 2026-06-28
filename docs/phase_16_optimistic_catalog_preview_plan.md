# Phase 16 Plan — Optimistic Catalog Preview

Goal: make catalog interactions feel instant using optimistic viewport updates, while keeping server LiveSnapshot as the source of truth.

---

## 1. Core Idea

Current safe flow:

```text
Click Try-On
↓
Wait server apply
↓
Server returns LiveSnapshot
↓
Viewport updates
```

New responsive flow:

```text
Click Try-On
↓
Viewport updates immediately with predicted snapshot
↓
Server applies to live character
↓
Server returns confirmed LiveSnapshot
↓
Client hydrates from server result
```

If server fails:

```text
Rollback viewport to previous LiveSnapshot
Show small warning/print
```

---

## 2. Important Rules

### Rule 1 — Server remains source of truth

Optimistic preview is only temporary.

Final state must always come from:

```text
AvatarAppearanceService.LiveSnapshot
```

### Rule 2 — Optimistic update applies to ViewportFrame first

Do not rely on local real character mutation as final state.

Recommended:

```text
optimistic ViewportFrame update
server-confirmed live character update
```

### Rule 3 — Every optimistic action needs rollback data

Before applying predicted snapshot, store:

```text
previousLiveSnapshot
previousLiveRevision
requestId
```

### Rule 4 — Ignore stale responses

If user clicks item A then item B quickly:

```text
response A must not overwrite response B
```

Use request token / revision.

### Rule 5 — Do not use optimistic success for save/purchase

For save template / checkout / DataStore / purchase:

```text
show "Saving..." only
do not show success/code before server confirms
```

---

## 3. Target Actions

Apply optimistic viewport to:

```text
Catalog Try-On visual items
Avatar Loader template preview/load feedback
Emote Play visual feedback
```

Do not apply optimistic final success to:

```text
Save Template
Checkout
Purchase
DataStore write
```

---

# 4. Data Model

Client appearance state should track:

```luau
local clientLiveSnapshot = nil
local clientLiveRevision = 0

local optimisticState = {
	isOptimistic = false,
	requestId = 0,
	previousSnapshot = nil,
	predictedSnapshot = nil,
	actionType = nil,
}
```

---

# 5. Catalog Try-On Flow

## 5.1 Before

```text
User clicks item
↓
Send request to server
↓
Wait
↓
Render server LiveSnapshot
```

## 5.2 After

```text
User clicks item
↓
Build predicted snapshot from current client LiveSnapshot + item payload
↓
Store previous LiveSnapshot
↓
Render predicted snapshot in ViewportFrame immediately
↓
Send predicted snapshot to server
↓
Server applies through AvatarAppearanceService
↓
Server returns confirmed LiveSnapshot
↓
Client hydrates from server result
```

---

# 6. Pseudo-code

```luau
local applyRequestId = 0

local function tryOnItemOptimistic(itemPayload)
	applyRequestId += 1
	local requestId = applyRequestId

	local previousSnapshot = clientLiveSnapshot
	local predictedSnapshot = AvatarDescriptionMutator.applyItem(
		previousSnapshot,
		itemPayload
	)

	optimisticState = {
		isOptimistic = true,
		requestId = requestId,
		previousSnapshot = previousSnapshot,
		predictedSnapshot = predictedSnapshot,
		actionType = "catalog_try_on",
	}

	-- immediate UI feedback
	AvatarPreviewController.renderSnapshot(predictedSnapshot)
	setCardApplying(itemPayload.key, true)

	task.spawn(function()
		local response = AvatarApplyRemote:InvokeServer({
			requestId = requestId,
			descriptionSnapshot = predictedSnapshot,
			source = "catalog_try_on",
		})

		if requestId ~= applyRequestId then
			return
		end

		setCardApplying(itemPayload.key, false)

		if response.success then
			clientLiveSnapshot = response.liveSnapshot
			clientLiveRevision = response.liveRevision

			optimisticState.isOptimistic = false

			AvatarPreviewController.renderSnapshot(response.liveSnapshot)
			MyAvatarController.refreshFromLiveSnapshot(response.liveSnapshot)
			return
		end

		-- rollback
		optimisticState.isOptimistic = false

		if previousSnapshot then
			AvatarPreviewController.renderSnapshot(previousSnapshot)
		end

		warn("[Catalog] Try-On failed:", response.code or response.message)
	end)
end
```

---

# 7. Fast Click Handling

Use one of these policies.

## Option A — Lock while applying

Simpler:

```text
Click item
↓
disable try-on buttons until server responds
```

Pros:

```text
stable and easy
```

Cons:

```text
less fluid if server is slow
```

## Option B — Latest wins

Recommended after Option A is stable.

```text
Click A
↓
optimistic A
↓
Click B before A server response
↓
optimistic B
↓
response A ignored
↓
response B hydrates final state
```

Use requestId to ignore stale response.

For this phase:

```text
Implement latest-wins for viewport response.
Keep server apply lock as safety.
```

---

# 8. Rollback Behavior

Rollback when:

```text
server rejects request
apply fails
snapshot invalid
remote errors
request times out
```

Rollback target:

```text
previousLiveSnapshot
```

UI feedback:

```text
warn/print for now
optional small toast later
```

Example warning:

```text
Gagal mencoba item. Avatar dikembalikan ke tampilan sebelumnya.
```

---

# 9. Avatar Loader Behavior

For Avatar Loader template card:

```text
Click Load
↓
optional: preview selected template in ViewportFrame immediately
↓
server applies template
↓
hydrate server LiveSnapshot
```

If load fails:

```text
rollback ViewportFrame to previous LiveSnapshot
```

Do not mark template as loaded until server confirms.

---

# 10. Emote Play Behavior

Emote Play is already a temporary action.

Flow:

```text
Click Play
↓
play animation on viewport immediately
↓
play animation on local live character immediately
```

No LiveSnapshot mutation.

If later server replication is added:

```text
local play first
server replication second
```

---

# 11. Save Template / Checkout Rule

Do not use optimistic success for these.

## Save Template

Allowed:

```text
Click Save
↓
show Saving...
```

Not allowed:

```text
show Saved/code before server confirms
```

## Checkout / Purchase

Allowed:

```text
show loading / opening checkout
```

Not allowed:

```text
pretend purchase succeeded before Roblox confirms
```

---

# 12. Sub-Phase Breakdown

```text
16.0 Audit current try-on/apply client flow
16.1 Add optimistic state/requestId helper
16.2 Build predicted snapshot before server request
16.3 Render predicted snapshot immediately in ViewportFrame
16.4 Hydrate from server-confirmed LiveSnapshot
16.5 Rollback on failure
16.6 Ignore stale responses
16.7 Add Avatar Loader optimistic preview/load feedback
16.8 Manual test matrix
```

---

# 13. Manual Test Matrix

## Test 1 — Normal Try-On

```text
Click accessory
Expected:
Viewport changes immediately
Live character updates after server response
```

## Test 2 — Server success hydrate

```text
Click jacket
Expected:
server LiveSnapshot replaces predicted snapshot after response
My Avatar updates
```

## Test 3 — Server failure rollback

```text
Force apply failure
Click item
Expected:
Viewport initially changes
Then rolls back to previous LiveSnapshot
```

## Test 4 — Fast click latest wins

```text
Click hair A
Immediately click hair B
Expected:
Viewport ends on hair B
Response A does not overwrite B
```

## Test 5 — Avatar Loader load

```text
Click Load template
Expected:
Viewport can preview immediately
Final state only confirmed after server response
```

## Test 6 — Save Template unaffected

```text
Click Save Template
Expected:
shows Saving...
does not show Saved/code until server success
```

## Test 7 — Emote unaffected

```text
Click Play emote
Expected:
animation plays immediately
LiveSnapshot unchanged
```

---

# 14. What Not To Do

Do not:

```text
- Treat optimistic snapshot as final LiveSnapshot.
- Let old server responses overwrite newer actions.
- Use optimistic success for save/purchase.
- Mutate real character locally as trusted final state.
- Remove server validation/apply pipeline.
- Skip rollback handling.
```

---

# 15. Final Acceptance Criteria

Complete when:

```text
1. Catalog Try-On updates ViewportFrame immediately.
2. Server LiveSnapshot still becomes final state.
3. Failed server apply rolls back viewport.
4. Fast clicks do not cause stale response overwrite.
5. Avatar Loader load has immediate visual feedback.
6. Save Template and checkout remain server-confirmed only.
7. Existing live-first architecture stays intact.
```
