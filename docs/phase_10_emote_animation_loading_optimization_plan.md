# Phase 10 Technical Plan — Emote & Animation Catalog Loading Optimization

Project: `abayzv/roblox-catalog-avatar`  
Baseline: Phase 8 My Avatar + Phase 9 Emote Play / Viewport Stability  
Goal: fix slow skeleton/loading behavior for **Emote** and **Animation Bundle** catalog cards.

---

## 0. Problem Summary

Current observed behavior:

```text
Body / accessory / clothing cards:
  appear quickly and progressively

Body bundle cards:
  acceptable

Emote cards:
  skeleton can stay for 5–10 seconds
  cards appear all at once, not progressively

Animation bundle:
  can also feel slower than normal items
```

Main UX issue:

```text
User may think the catalog is heavy or broken,
even though the delay is mostly from expensive emote/animation resolving.
```

---

## 1. Likely Root Cause

The current pipeline likely treats **card ready** and **action ready** as the same thing.

For normal visual items:

```text
Catalog metadata
↓
simple payload mapping
↓
card ready
```

For emotes:

```text
Catalog metadata
↓
resolve actual animation id
↓
possibly RemoteFunction to server
↓
possibly InsertService:LoadAsset
↓
scan Animation object
↓
card ready
```

This is too expensive to block card rendering.

The result:

```text
Card waits for expensive resolver
batch waits for many emotes
cards appear late and all at once
```

---

## 2. Core Decision

Separate these two readiness concepts:

```text
Display Ready
= card can be shown to user

Action Ready
= item can be played/applied instantly
```

For Emote:

```text
Display Ready:
  name, thumbnail, price, catalog id

Action Ready:
  actual animation id resolved
```

Card must appear when **Display Ready**, not when **Action Ready**.

---

## 3. Non-Negotiable Rules

### Rule 1 — Emote cards must not wait for full animation resolve

Emote card can render with lightweight payload:

```luau
{
	key = item.key,
	id = item.id,
	itemType = "Asset",
	kind = "Emote",

	emoteAssetId = item.id,
	emoteAnimationId = nil,
	resolveState = "pending",
}
```

### Rule 2 — Resolve emote animation id lazily

When user clicks `Play`:

```text
if emoteAnimationId exists:
  play immediately

else:
  show loading on Play button
  resolve this single emote
  cache result
  play after resolved
```

### Rule 3 — Do not block 30-card batch on emote resolving

Do not resolve 30 emotes in one blocking request before showing cards.

If background resolving is used:

```text
max concurrent = 1–2
chunk size = 1–3
update cache per item as soon as resolved
```

### Rule 4 — Animation bundles should not require physical/content prewarm before card render

Animation bundle cards should appear after metadata/bundled-items parsing.

Do not prewarm animation bundle assets just to show cards.

### Rule 5 — Body/accessory/clothing behavior should remain unchanged

Do not break the fast path for:

```text
body
body bundle
hair
accessory
classic clothing
3D clothing
```

### Rule 6 — No retry loop

If resolving emote animation id fails:

```text
mark resolveState = "failed"
show card anyway
Play button can show failed/disabled state
do not retry repeatedly in a tight loop
```

---

# 4. Target UX

## Before

```text
Open Emote category
↓
Skeleton for 5–10 seconds
↓
Many cards appear all at once
```

## After

```text
Open Emote category
↓
Cards appear quickly from catalog metadata
↓
Play button may show loading only when clicked
↓
After first resolve, future Play is instant from cache
```

Optional background behavior:

```text
Cards appear quickly
Visible emotes resolve quietly in background
Play becomes instant for resolved cards
```

---

# 5. Required State Model

## PreviewPayload for Emote

Use lightweight payload first:

```luau
export type EmotePreviewPayload = {
	key: string,
	id: number,
	itemType: "Asset",
	kind: "Emote",

	emoteAssetId: number,
	emoteAnimationId: number?,

	resolveState: "pending" | "resolving" | "ready" | "failed",
	resolveError: string?,
}
```

## PreviewPayloadCache

Cache should support update/patch:

```luau
PreviewPayloadCache.set(key, payload)
PreviewPayloadCache.patch(key, partial)
PreviewPayloadCache.get(key)
PreviewPayloadCache.has(key)
```

If `patch` does not exist, implement simple patching:

```luau
local payload = PreviewPayloadCache.get(itemKey)
for key, value in pairs(partial) do
	payload[key] = value
end
PreviewPayloadCache.set(itemKey, payload)
```

---

# 6. CatalogWarmupQueue Changes

## Current issue

Warmup may do:

```text
collect up to 30 items
resolveBatch(30)
wait until resolveBatch completes
set cache for all
then cards appear
```

For emote, this causes late bulk appearance.

## Target behavior

For every catalog item:

```text
if normal visual item:
  existing warmup behavior is okay

if emote:
  create lightweight payload immediately
  set cache immediately
  do not wait for full animation resolve
```

Pseudo-flow:

```luau
for _, item in ipairs(itemsToWarmup) do
	if itemIsEmote(item) then
		local payload = createLightweightEmotePayload(item)
		PreviewPayloadCache.set(item.key, payload)
		markCardReady(item.key)

		-- optional background low-priority resolve
		EmoteAnimationResolveQueue.enqueue(item)
	else
		-- existing resolver path
	end
end
```

Important:

```text
markCardReady should happen immediately for emote lightweight payload.
```

---

# 7. PreviewPayloadResolver Changes

## Add lightweight emote resolver

```luau
function PreviewPayloadResolver.createLightweightEmotePayload(item)
	return {
		key = item.key,
		id = item.id,
		itemType = item.itemType or "Asset",
		kind = "Emote",

		emoteAssetId = item.id,
		emoteAnimationId = nil,

		resolveState = "pending",
	}
end
```

## Do not call heavy resolve for emote in generic resolveBatch

Avoid this in batch path:

```text
ResolveEmotesRemote:InvokeServer(30 emotes)
```

Instead:

```text
generic resolveBatch returns lightweight payload for emotes
```

Then heavy resolve is handled by:

```text
EmoteAnimationResolver
```

---

# 8. EmoteAnimationResolver

Create client service:

```text
src/client/services/EmoteAnimationResolver.luau
```

Purpose:

```text
Resolve emote catalog asset id into playable animation id.
```

## API

```luau
local EmoteAnimationResolver = {}

function EmoteAnimationResolver.resolveOne(emoteAssetId: number): (boolean, number?, string?)
end

function EmoteAnimationResolver.resolvePayload(payload): (boolean, EmotePreviewPayload, string?)
end

return EmoteAnimationResolver
```

## Behavior

```text
1. Check local cache by emoteAssetId
2. If cached ready, return animationId
3. If not cached, call ResolveEmotesRemote for this id or small chunk
4. Store result in cache
5. Return
```

Cache shape:

```luau
local cache = {
	[emoteAssetId] = {
		state = "ready",
		animationId = 123456,
	},
}
```

Failed cache:

```luau
local cache = {
	[emoteAssetId] = {
		state = "failed",
		error = "NO_ANIMATION_FOUND",
	}
}
```

Do not repeatedly retry failed item during the same session unless user explicitly retries.

---

# 9. ResolveEmotesRemote Changes

## Current problem

If it accepts big arrays and loads many assets, caller blocks too long.

## Target

Allow small input:

```luau
ResolveEmotesRemote:InvokeServer({ 123456 })
```

Keep max per request small:

```luau
MAX_EMOTES_PER_RESOLVE_REQUEST = 3
```

If client sends more:

```text
server rejects or truncates
```

## Server throttling

Add simple in-flight guard:

```text
one ResolveEmotes request per player at a time
```

Or throttle:

```text
max one resolve request every 0.25–0.5 seconds
```

## Server cache

Server should cache resolved emote ids:

```luau
local resolvedEmoteCache = {
	[emoteAssetId] = {
		success = true,
		animationId = 123456,
	}
}
```

This avoids repeated `InsertService:LoadAsset`.

---

# 10. Play Button Flow

When user clicks Play:

```text
payload = PreviewPayloadCache.get(item.key)

if payload.emoteAnimationId exists:
  ViewportAnimationController.playEmote(payload.emoteAnimationId)
  return

if payload.resolveState == "resolving":
  show Play loading
  return

set resolveState = "resolving"
show Play loading

ok, animationId = EmoteAnimationResolver.resolveOne(payload.emoteAssetId)

if ok:
  patch payload:
    emoteAnimationId = animationId
    resolveState = "ready"
  ViewportAnimationController.playEmote(animationId)

else:
  patch payload:
    resolveState = "failed"
    resolveError = reason
  warn("[Emote] Failed to resolve animation:", reason)
```

Important:

```text
Only Play button should show loading.
The whole card should not go back to skeleton.
```

---

# 11. Optional Background Resolve Queue

After lightweight emote cards appear, optionally resolve visible emotes quietly.

Create:

```text
src/client/services/EmoteAnimationResolveQueue.luau
```

Config:

```luau
local MAX_CONCURRENT = 1
local MAX_PER_CATEGORY_OPEN = 8
local RESOLVE_DELAY_SECONDS = 0.2
```

Behavior:

```text
Only enqueue visible cards or first few cards
Do not resolve all 30 immediately
Do not block card rendering
Update payload cache per item when resolved
```

Recommended implementation order:

```text
First: lazy resolve on Play
Later: background resolve visible emotes
```

---

# 12. ContentPrewarmQueue Changes

Inspect:

```text
src/client/services/ContentPrewarmQueue.luau
```

If it prewarms payloads with:

```text
kind == "Emote"
kind == "AnimationBundle"
payload.animations
```

change it.

## Rule

Skip content prewarm for:

```text
Emote
AnimationBundle
```

Pseudo:

```luau
if payload.kind == "Emote" or payload.kind == "AnimationBundle" then
	return
end
```

Reason:

```text
Animation playback/loading should not block visual card display.
```

Do not skip prewarm for visual items unless existing prewarm causes issues.

---

# 13. Animation Bundle Handling

Animation bundle should be display-ready when:

```text
catalog metadata is ready
bundle details are parsed enough to know animation properties
```

It should not wait for:

```text
physical animation playback preloading
hidden dummy ApplyDescription
content prewarm
```

If animation bundle card is still slow, inspect whether it waits for `ContentPrewarmQueue`.

Fix:

```text
card ready after parsed payload
skip physical prewarm
```

If parsing bundle details is still slow, show card with metadata first and mark action state loading, same as emote.

---

# 14. Card Rendering Rules

## For normal visual items

```text
Card visible when preview payload ready.
```

## For emotes

```text
Card visible when catalog metadata + lightweight payload ready.
Play button state depends on emoteAnimationId/resolveState.
```

## For animation bundles

```text
Card visible when bundle payload parsed.
Do not require content prewarm.
```

---

# 15. Sub-Phase Breakdown

Do not implement everything at once.

Use this order:

```text
10.0 Audit current emote/animation loading path
10.1 Add lightweight emote payload
10.2 Make emote cards display-ready immediately
10.3 Add lazy EmoteAnimationResolver on Play
10.4 Limit ResolveEmotesRemote batch size + add cache
10.5 Skip ContentPrewarmQueue for Emote/AnimationBundle
10.6 Optional background visible-emote resolve queue
10.7 Add loading/failed state on Play button
10.8 Manual test matrix
```

---

# 16. Sub-Phase 10.0 — Audit

Inspect:

```text
CatalogWarmupQueue
PreviewPayloadResolver
PreviewPayloadCache
ResolveEmotesRemote
ResolveEmotesService
ContentPrewarmQueue
Catalog item card component
Emote Play button handler
Animation bundle resolver
```

Document:

```text
where emote card waits
where resolveBatch blocks
where ResolveEmotesRemote is called
where PreviewPayloadCache is set
where card is marked ready
where ContentPrewarmQueue is called
```

Acceptance:

```text
Agent can explain why emote cards appear late and in bulk before changing code.
```

---

# 17. Sub-Phase 10.1 — Lightweight Emote Payload

Add lightweight payload creation.

Acceptance:

```text
Emote item can produce payload without ResolveEmotesRemote.
Payload has resolveState = pending.
```

---

# 18. Sub-Phase 10.2 — Emote Cards Display Immediately

Update warmup/render condition.

Acceptance:

```text
Open Emote category
Cards appear quickly/progressively like normal items
Cards do not wait for animation id
```

---

# 19. Sub-Phase 10.3 — Lazy Resolve on Play

Add resolver call only when Play is clicked.

Acceptance:

```text
Click Play first time:
  button loading
  resolve animation id
  play after resolved

Click Play second time:
  instant from cache
```

---

# 20. Sub-Phase 10.4 — ResolveEmotesRemote Limits + Cache

Server-side:

```text
limit request size
cache resolved emote animation ids
avoid repeated InsertService:LoadAsset
```

Acceptance:

```text
same emote resolved once
repeated Play does not LoadAsset again
oversized request rejected/truncated
```

---

# 21. Sub-Phase 10.5 — Skip ContentPrewarm for Emote/AnimationBundle

Acceptance:

```text
Emote and animation bundle card display is not blocked by prewarm
visual items still work
```

---

# 22. Sub-Phase 10.6 — Optional Background Resolve Visible Emotes

Only implement after lazy Play works.

Acceptance:

```text
first visible 6–8 emotes resolve quietly
cards remain visible while resolving
no large request spike
```

---

# 23. Sub-Phase 10.7 — Play Button States

Button states:

```text
Play
Loading...
Failed
```

Do not skeleton the whole card after it is displayed.

Acceptance:

```text
Resolve failure does not hide card
Play button shows failed/disabled or prints warning
```

---

# 24. Manual Test Matrix

Do not mark complete until these pass.

## Test 1 — Emote category first load

```text
Open Emote category
Expected:
cards appear quickly
not 5–10 seconds skeleton
not all at once after long delay
```

## Test 2 — Emote Play lazy resolve

```text
Click Play on first emote
Expected:
button loading only
then animation plays
card stays visible
```

## Test 3 — Cached second Play

```text
Click same emote Play again
Expected:
plays immediately from cache
no new server LoadAsset
```

## Test 4 — Multiple emotes

```text
Click Play on emote A
Click Play on emote B
Expected:
each resolves individually
no huge batch blocking
```

## Test 5 — Resolve failure

```text
Force resolve failure
Expected:
card remains visible
Play button failed/warn
no retry loop
```

## Test 6 — Animation bundle category

```text
Open Animation Bundle category
Expected:
cards display after metadata/bundle parse
not blocked by content prewarm
```

## Test 7 — Visual items unaffected

```text
Open accessories/clothing/body
Expected:
loading speed unchanged or better
try-on still works
```

## Test 8 — No request spike

```text
Open Emote category
Expected:
ResolveEmotesRemote not called with 30 items immediately
no Too Many Requests caused by emote resolving
```

## Test 9 — Studio vs live check

```text
Test in Studio:
emote cards should no longer skeleton 5–10 seconds

Test in live server:
behavior should remain smooth
```

---

# 25. What Not To Do

Do not:

```text
- Make emote card wait for InsertService:LoadAsset.
- Resolve 30 emotes in one blocking batch before showing cards.
- Put card back to skeleton while resolving Play.
- Retry failed emote resolve in tight loop.
- Prewarm Emote or AnimationBundle physical content before card display.
- Break body/accessory/clothing fast path.
- Reintroduce emote wheel equip/remove.
```

---

# 26. Final Acceptance Criteria

Phase 10 is complete only if:

1. Emote cards render quickly from catalog metadata/lightweight payload.
2. Emote animation id resolves lazily on Play or low-priority background queue.
3. Play button has loading/failed state independent of card skeleton.
4. ResolveEmotesRemote is not called for 30 emotes at once.
5. Server caches resolved emote animation ids.
6. ContentPrewarmQueue skips Emote and AnimationBundle.
7. Animation bundle cards are not blocked by physical prewarm.
8. Normal visual item catalog performance is unchanged.
9. Manual test matrix passes.

---

# 27. Suggested Commit Plan

```text
phase10-0-audit-emote-loading-path
phase10-1-lightweight-emote-payload
phase10-2-emote-card-display-ready
phase10-3-lazy-resolve-on-play
phase10-4-resolve-emotes-cache-and-limits
phase10-5-skip-prewarm-emote-animationbundle
phase10-6-optional-visible-emote-background-resolve
phase10-7-play-button-states
phase10-8-test-matrix-cleanup
```

---

# 28. Short Instruction for AI Agent

Fix slow emote and animation bundle catalog loading.

Core rule:

```text
Card visibility must not wait for expensive animation resolve.
```

For Emote:

```text
Show card from catalog metadata immediately.
Resolve actual animation id only when Play is clicked,
or low-priority for visible cards.
```

For AnimationBundle:

```text
Show card after bundle payload parse.
Do not content-prewarm before showing card.
```

Do not break the fast path for body/accessory/clothing.
