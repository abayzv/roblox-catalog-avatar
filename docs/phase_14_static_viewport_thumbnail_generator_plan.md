# Phase 14 Technical Plan — Static Viewport Thumbnail Generator

Project: `abayzv/roblox-catalog-avatar`  
Baseline: Avatar Loader template save/load already works  
Goal: generate lightweight static avatar previews for template cards without keeping many active Humanoids/Animators.

---

## 0. Core Idea

Template cards need avatar thumbnails.

Do not create 10 active humanoid rigs in 10 ViewportFrames.

Instead use one generator pipeline:

```text
Template descriptionSnapshot
↓
1 temporary generator rig with Humanoid
↓
ApplyDescriptionResetAsync
↓
clone generated result
↓
sanitize clone into lightweight static avatar model
↓
render static clone inside card ViewportFrame
```

The card should contain an **enteng/static model**, not a live Humanoid character.

---

## 1. Target Behavior

Avatar Loader page shows max 10 templates per page.

For each visible template card:

```text
1. Card shows placeholder first.
2. Thumbnail generation job is queued.
3. Generator rig renders template one by one.
4. Static sanitized avatar clone is inserted into card ViewportFrame.
5. Old page thumbnails are cleaned up when page changes.
```

Important:

```text
Generate thumbnails sequentially, not all at once.
```

---

## 2. Non-Negotiable Rules

### Rule 1 — Only one active generator rig at a time

Do not run 10 `ApplyDescriptionResetAsync` calls in parallel.

Use a queue:

```text
one thumbnail job at a time
```

### Rule 2 — Card thumbnail model must not contain Humanoid/Animator

After generation, sanitize the clone.

Remove:

```text
Humanoid
Animator
AnimationController
Animation
Script
LocalScript
```

Keep:

```text
BasePart
MeshPart
Accessory
Attachment
Motor6D
Weld
WeldConstraint
WrapLayer
WrapTarget
SurfaceAppearance
SpecialMesh
Decal
Texture
```

Do not break accessories/body joints that are needed to keep the avatar visually assembled.

### Rule 3 — All parts must be static

For every `BasePart`:

```luau
Anchored = true
CanCollide = false
CanTouch = false
CanQuery = false
Massless = true
```

### Rule 4 — Thumbnail generation must be cancelable by page/session

If user changes Avatar Loader page/tab:

```text
cancel pending jobs for old page
clear old card Viewports
do not insert old thumbnail into new page
```

### Rule 5 — Cache generated static models carefully

Cache by:

```text
templateId
```

But limit cache size.

Recommended:

```text
MAX_STATIC_THUMBNAIL_CACHE = 20
```

---

# 3. Architecture

Create client service:

```text
src/client/services/TemplateThumbnailGenerator.luau
```

Responsibilities:

```text
queue thumbnail jobs
create temporary generator rig
apply HumanoidDescription snapshot
clone generated result
sanitize clone
render static clone to ViewportFrame
cache sanitized static models
cancel jobs by page/session
cleanup ViewportFrame contents
```

---

## 3.1 Suggested API

```luau
local TemplateThumbnailGenerator = {}

function TemplateThumbnailGenerator.renderTemplateCard(
	templateId: string,
	descriptionSnapshot: table,
	viewportFrame: ViewportFrame,
	options: table?
)
end

function TemplateThumbnailGenerator.cancelPage(pageToken: string)
end

function TemplateThumbnailGenerator.clearViewport(viewportFrame: ViewportFrame)
end

function TemplateThumbnailGenerator.clearCache()
end

return TemplateThumbnailGenerator
```

---

## 3.2 Internal State

```luau
local queue = {}
local isProcessing = false

local staticModelCache = {}
local cacheOrder = {}

local activePageToken = nil
local jobCounter = 0
```

Each job:

```luau
{
	jobId = 1,
	pageToken = "avatar-loader-page-3",
	templateId = "...",
	descriptionSnapshot = {...},
	viewportFrame = viewportFrame,
}
```

---

# 4. Generation Flow

## 4.1 Enqueue

When template card becomes visible:

```text
show placeholder
enqueue render job
```

Pseudo:

```luau
TemplateThumbnailGenerator.renderTemplateCard(
	template.templateId,
	template.descriptionSnapshot,
	cardViewportFrame,
	{
		pageToken = currentPageToken,
	}
)
```

If cached static model exists:

```text
clone cached static model
render immediately
```

No generator rig needed.

---

## 4.2 Process Queue

Pseudo:

```luau
local function processQueue()
	if isProcessing then
		return
	end

	isProcessing = true

	while #queue > 0 do
		local job = table.remove(queue, 1)

		if job.pageToken == activePageToken then
			processJob(job)
			task.wait(0.08)
		end
	end

	isProcessing = false
end
```

Recommended delay:

```text
0.05 - 0.15 seconds between jobs
```

Use:

```text
0.08 seconds
```

as default.

---

# 5. Generator Rig Strategy

## 5.1 Base Rig

Use one clean base R15 rig.

Possible sources:

```text
ReplicatedStorage.Assets.BaseThumbnailRig
or
Players:CreateHumanoidModelFromDescription() if available/appropriate
```

Recommended for consistency:

```text
provide a clean BaseThumbnailRig in ReplicatedStorage
```

The base rig should have:

```text
R15 body
Humanoid
HumanoidRootPart
standard body parts
no scripts
```

---

## 5.2 Generate Job

Pseudo:

```luau
local function generateStaticModel(descriptionSnapshot)
	local generatorRig = BaseThumbnailRig:Clone()
	generatorRig.Parent = hiddenWorldModel

	local humanoid = generatorRig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		generatorRig:Destroy()
		return nil, "NO_HUMANOID"
	end

	local description = HumanoidDescriptionSerializer.deserialize(descriptionSnapshot)

	local ok, err = pcall(function()
		humanoid:ApplyDescriptionResetAsync(
			description,
			Enum.AssetTypeVerification.Always
		)
	end)

	if not ok then
		generatorRig:Destroy()
		return nil, err
	end

	local staticModel = generatorRig:Clone()
	generatorRig:Destroy()

	sanitizeStaticAvatar(staticModel)

	return staticModel
end
```

Important:

```text
Destroy generatorRig after every job.
```

This prevents stale accessories/body parts from previous templates.

---

# 6. Sanitization

Create helper:

```luau
local function sanitizeStaticAvatar(model: Model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("Humanoid") then
			inst:Destroy()

		elseif inst:IsA("Animator") then
			inst:Destroy()

		elseif inst:IsA("AnimationController") then
			inst:Destroy()

		elseif inst:IsA("Animation") then
			inst:Destroy()

		elseif inst:IsA("Script") or inst:IsA("LocalScript") then
			inst:Destroy()

		elseif inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanTouch = false
			inst.CanQuery = false
			inst.Massless = true
		end
	end
end
```

Important:

```text
Do not call BreakJoints by default.
```

Reason:

```text
BreakJoints may detach accessories/body parts depending on how the generated avatar is assembled.
Anchoring all parts while keeping Motor6D/Weld/Attachment data is safer.
```

Only test BreakJoints behind a config flag:

```luau
ENABLE_BREAK_JOINTS_FOR_STATIC_THUMBNAIL = false
```

---

# 7. Render Static Model to Card Viewport

Each card ViewportFrame should contain:

```text
ViewportFrame
  WorldModel
    StaticAvatarModel
  Camera
```

Pseudo:

```luau
local function renderStaticModelToViewport(viewportFrame, staticModel)
	clearViewport(viewportFrame)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewportFrame

	staticModel.Parent = worldModel

	local camera = Instance.new("Camera")
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	positionModelForThumbnail(staticModel)
	positionCamera(camera, staticModel)
end
```

---

## 7.1 Camera Position

Simple MVP:

```luau
local cf, size = staticModel:GetBoundingBox()
local center = cf.Position

local distance = math.max(size.X, size.Y, size.Z) * 1.5

camera.CFrame = CFrame.new(
	center + Vector3.new(0, size.Y * 0.15, distance),
	center + Vector3.new(0, size.Y * 0.05, 0)
)
```

For front view, align model facing camera consistently.

---

# 8. Cache Strategy

Cache sanitized static model:

```luau
staticModelCache[templateId] = staticModel
```

When rendering from cache:

```luau
local clone = staticModelCache[templateId]:Clone()
renderStaticModelToViewport(viewportFrame, clone)
```

Limit cache:

```luau
MAX_STATIC_THUMBNAIL_CACHE = 20
```

Evict oldest:

```luau
if #cacheOrder > MAX_STATIC_THUMBNAIL_CACHE then
	local oldestTemplateId = table.remove(cacheOrder, 1)
	local cached = staticModelCache[oldestTemplateId]
	if cached then
		cached:Destroy()
	end
	staticModelCache[oldestTemplateId] = nil
end
```

---

# 9. Pagination Integration

Avatar Loader should render max:

```text
10 templates per page
```

When page changes:

```text
1. create new pageToken
2. cancel old page jobs
3. clear old ViewportFrames
4. render placeholders
5. enqueue new page thumbnail jobs
```

---

# 10. Cleanup Rules

Call cleanup on:

```text
Avatar Loader tab closed
page changed
template list refreshed
UI destroyed
```

Cleanup should:

```text
cancel jobs
clear card viewport content
destroy unused static clones
optionally keep small cache
```

---

# 11. Fallback Behavior

If thumbnail generation fails:

```text
show placeholder
do not block card
do not block Load button
warn once
```

Fallback state:

```text
thumbnailState = "Failed"
```

---

# 12. Performance Guards

Use config:

```luau
local TEMPLATE_CARD_PAGE_SIZE = 10
local THUMBNAIL_JOB_DELAY = 0.08
local MAX_STATIC_THUMBNAIL_CACHE = 20
local ENABLE_TEMPLATE_VIEWPORT_THUMBNAILS = true
local ENABLE_BREAK_JOINTS_FOR_STATIC_THUMBNAIL = false
```

If performance is bad on low-end device:

```text
disable ENABLE_TEMPLATE_VIEWPORT_THUMBNAILS
fallback to placeholder thumbnail
```

---

# 13. Sub-Phase Breakdown

Implement in small steps:

```text
14.0 Audit Avatar Loader card UI
14.1 Add TemplateThumbnailGenerator service
14.2 Add BaseThumbnailRig source
14.3 Generate one static thumbnail from one template
14.4 Sanitize static avatar clone
14.5 Render static clone into card ViewportFrame
14.6 Add queue one-job-at-a-time
14.7 Add pagination/pageToken cancellation
14.8 Add static model cache + eviction
14.9 Add cleanup/fallback states
14.10 Manual test matrix
```

---

# 14. Manual Test Matrix

## Test 1 — One thumbnail

```text
Open Avatar Loader with one template
Expected:
card placeholder appears first
static avatar thumbnail appears after generation
```

## Test 2 — Ten thumbnails

```text
Open page with 10 templates
Expected:
thumbnails appear progressively
no big freeze
```

## Test 3 — Page switch

```text
Open page 1
Immediately switch to page 2
Expected:
old page jobs do not insert thumbnails into page 2
```

## Test 4 — Cache

```text
Open page 1
Switch page
Return to page 1
Expected:
cached thumbnails render faster
```

## Test 5 — Cleanup

```text
Open Avatar Loader
Close Avatar Loader
Expected:
ViewportFrame contents cleared
no accumulating WorldModels/Cameras
```

## Test 6 — No active Humanoid in card

```text
Inspect card viewport model
Expected:
no Humanoid
no Animator
no scripts
parts anchored
```

## Test 7 — Appearance correctness

```text
Save outfit with hair/accessory/clothing/body
Generate thumbnail
Expected:
static thumbnail visually matches template enough
```

## Test 8 — Generation failure

```text
Force invalid snapshot
Expected:
card remains usable with placeholder
no crash
```

---

# 15. What Not To Do

Do not:

```text
- Create 10 active Humanoid rigs at the same time.
- Run 10 ApplyDescriptionResetAsync calls in parallel.
- Keep Humanoid/Animator inside card thumbnails.
- Render ViewportFrame thumbnail for every template in entire database.
- Forget cleanup on page change/tab close.
- Let old page generation jobs affect new page.
- Block Load button while thumbnail is generating.
- Enable BreakJoints by default before visual testing.
```

---

# 16. Final Acceptance Criteria

Phase 14 is complete only if:

```text
1. Template cards use ViewportFrame static thumbnails.
2. Thumbnail generation uses one generator job at a time.
3. Card thumbnail models are sanitized and lightweight.
4. Card thumbnails do not contain Humanoid/Animator/scripts.
5. Pagination renders max 10 thumbnails per page.
6. Page change cancels old thumbnail jobs.
7. Cache works with a safe memory limit.
8. Placeholder fallback works if generation fails.
9. Avatar Loader remains responsive.
```

---

# 17. Short Instruction for AI Agent

Implement lightweight template card thumbnails.

Use one temporary generator rig to apply each template HumanoidDescription, then clone the result and sanitize it into a static model.

Render the static model inside each card ViewportFrame.

Do not keep active Humanoids or Animators inside card thumbnails.

Generate thumbnails one-by-one through a queue, support pagination cancellation, and clean up ViewportFrame contents when page/tab changes.
