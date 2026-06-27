# Phase 8 Technical Plan — My Avatar Tab

Project: `abayzv/roblox-catalog-avatar`  
Baseline: Phase 7 Live-First Catalog Try-On  
Goal: add a new **My Avatar** tab that displays items currently worn by the player, using the same visual style as Item Catalog.

---

## 0. Core Idea

Current tabs:

```text
Item Catalog
Avatar Loader
```

Add new tab:

```text
My Avatar
```

`My Avatar` is not a catalog search page.

It is a viewer for what the player is currently wearing.

Core rule:

```text
My Avatar reads from LiveSnapshot.
```

Not from:

```text
last clicked catalog item
old preview state
old draft state
raw UI selected state
```

This matches the live-first rule:

```text
Apa yang user lihat dan pakai di live character
=
apa yang user lihat di catalog
=
apa yang tampil di My Avatar / Currently Wearing
```

---

## 1. Item Catalog vs My Avatar

### Item Catalog

Purpose:

```text
Search/browse Roblox catalog items.
```

Data source:

```text
Catalog APIs / item search result
```

Card represents:

```text
item that can be tried on
```

Click behavior:

```text
Try-On item -> live character changes
```

### My Avatar

Purpose:

```text
Show items currently worn by live character.
```

Data source:

```text
AvatarAppearanceService.LiveSnapshot
```

Card represents:

```text
item/property currently applied to the player's live HumanoidDescription
```

Click behavior for Phase 8:

```text
View only first.
```

Optional later:

```text
Remove / Unequip
View Details
Checkout
```

---

## 2. Main Data Flow

```text
Open My Avatar tab
↓
Client requests LiveSnapshot from AvatarAppearanceService
↓
Extract worn items from LiveSnapshot
↓
Group worn items by main category/subcategory
↓
Resolve item details for display card
↓
Render using catalog-like UI
```

Whenever LiveSnapshot changes:

```text
catalog try-on
morph
reset original
respawn reapply
```

My Avatar should refresh.

---

## 3. Source of Truth

Use:

```text
LiveSnapshot
```

from Phase 7.

The server should expose or reuse:

```text
GetAppearanceStateRemote
```

Response:

```luau
{
	success = true,
	liveSnapshot = {...},
	liveRevision = 7,
	lastApplySource = "catalog_try_on",
}
```

Client My Avatar state:

```luau
{
	liveSnapshot = {...},
	liveRevision = 7,
	wornItems = {...},
	selectedMainCategory = "all",
	selectedSubCategory = "all",
	isLoading = false,
}
```

---

# 4. Category Behavior

## 4.1 Main Categories

My Avatar main categories:

```text
All
Body
3D Clothing
Classic Clothing
Accessories
Animation
```

Optional later:

```text
Colors / Scales
```

Do not implement Colors/Scales in the first version unless UI already supports it.

---

## 4.2 Default Open Behavior

When user opens **My Avatar** for the first time:

```text
Main Category = All
Sub Category = All
```

Display:

```text
all currently worn items from all categories
```

---

## 4.3 Behavior when Main Category = All

When main category is `All`, subcategories should be high-level groups:

```text
All
Body
3D Clothing
Classic Clothing
Accessories
Animation
```

Examples:

```text
Main: All
Sub: All
=> show everything currently worn

Main: All
Sub: Body
=> show all currently worn body-related items

Main: All
Sub: 3D Clothing
=> show all currently worn layered/3D clothing

Main: All
Sub: Accessories
=> show all currently worn accessories
```

---

## 4.4 Behavior when Main Category is specific

When main category is specific, subcategories should become detailed.

Example:

```text
Main: 3D Clothing
Sub categories:
  All
  T-Shirt
  Shirt
  Pants
  Jacket
  Sweater
  Shorts
  Dress / Skirt
  Left Shoe
  Right Shoe
```

If user selects:

```text
Main: 3D Clothing
Sub: Shirt
```

Show:

```text
only currently worn ShirtAccessory item(s)
```

---

# 5. Category Mapping

Create shared config:

```text
src/shared/avatar/MyAvatarCategoryConfig.luau
```

## 5.1 Config Shape

```luau
export type MyAvatarCategory = {
	id: string,
	label: string,
	subcategories: { MyAvatarSubcategory },
}

export type MyAvatarSubcategory = {
	id: string,
	label: string,
	groupId: string?,
	properties: { string }?,
}
```

---

## 5.2 Suggested Category Config

```luau
local MyAvatarCategoryConfig = {}

MyAvatarCategoryConfig.MainCategories = {
	{
		id = "all",
		label = "All",
		subcategories = {
			{ id = "all", label = "All" },
			{ id = "body", label = "Body", groupId = "body" },
			{ id = "3d_clothing", label = "3D Clothing", groupId = "3d_clothing" },
			{ id = "classic_clothing", label = "Classic Clothing", groupId = "classic_clothing" },
			{ id = "accessories", label = "Accessories", groupId = "accessories" },
			{ id = "animation", label = "Animation", groupId = "animation" },
		},
	},

	{
		id = "body",
		label = "Body",
		subcategories = {
			{ id = "all", label = "All", groupId = "body" },
			{ id = "hair", label = "Hair", properties = { "HairAccessory" } },
			{ id = "head", label = "Head", properties = { "Head" } },
			{ id = "face", label = "Face", properties = { "Face" } },
			{ id = "body_parts", label = "Body Parts", properties = {
				"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
			}},
		},
	},

	{
		id = "3d_clothing",
		label = "3D Clothing",
		subcategories = {
			{ id = "all", label = "All", groupId = "3d_clothing" },
			{ id = "tshirt", label = "T-Shirt", properties = { "TShirtAccessory" } },
			{ id = "shirt", label = "Shirt", properties = { "ShirtAccessory" } },
			{ id = "pants", label = "Pants", properties = { "PantsAccessory" } },
			{ id = "jacket", label = "Jacket", properties = { "JacketAccessory" } },
			{ id = "sweater", label = "Sweater", properties = { "SweaterAccessory" } },
			{ id = "shorts", label = "Shorts", properties = { "ShortsAccessory" } },
			{ id = "dress_skirt", label = "Dress / Skirt", properties = { "DressSkirtAccessory" } },
			{ id = "left_shoe", label = "Left Shoe", properties = { "LeftShoeAccessory" } },
			{ id = "right_shoe", label = "Right Shoe", properties = { "RightShoeAccessory" } },
		},
	},

	{
		id = "classic_clothing",
		label = "Classic Clothing",
		subcategories = {
			{ id = "all", label = "All", groupId = "classic_clothing" },
			{ id = "classic_tshirt", label = "Classic T-Shirt", properties = { "GraphicTShirt" } },
			{ id = "classic_shirt", label = "Classic Shirt", properties = { "Shirt" } },
			{ id = "classic_pants", label = "Classic Pants", properties = { "Pants" } },
		},
	},

	{
		id = "accessories",
		label = "Accessories",
		subcategories = {
			{ id = "all", label = "All", groupId = "accessories" },
			{ id = "hats", label = "Hats", properties = { "HatAccessory" } },
			{ id = "face", label = "Face", properties = { "FaceAccessory" } },
			{ id = "neck", label = "Neck", properties = { "NeckAccessory" } },
			{ id = "shoulder", label = "Shoulder", properties = { "ShoulderAccessory", "ShouldersAccessory" } },
			{ id = "front", label = "Front", properties = { "FrontAccessory" } },
			{ id = "back", label = "Back", properties = { "BackAccessory" } },
			{ id = "waist", label = "Waist", properties = { "WaistAccessory" } },
		},
	},

	{
		id = "animation",
		label = "Animation",
		subcategories = {
			{ id = "all", label = "All", groupId = "animation" },
			{ id = "idle", label = "Idle", properties = { "IdleAnimation" } },
			{ id = "walk", label = "Walk", properties = { "WalkAnimation" } },
			{ id = "run", label = "Run", properties = { "RunAnimation" } },
			{ id = "jump", label = "Jump", properties = { "JumpAnimation" } },
			{ id = "fall", label = "Fall", properties = { "FallAnimation" } },
			{ id = "climb", label = "Climb", properties = { "ClimbAnimation" } },
			{ id = "swim", label = "Swim", properties = { "SwimAnimation" } },
		},
	},
}

return MyAvatarCategoryConfig
```

Important:

```text
Support both ShoulderAccessory and ShouldersAccessory defensively.
Use whichever exists in current serialized snapshot.
```

---

# 6. Worn Item Extraction

Create shared module:

```text
src/shared/avatar/WornItemExtractor.luau
```

Purpose:

```text
LiveSnapshot -> WornItem[]
```

---

## 6.1 WornItem Type

```luau
export type WornItem = {
	key: string,
	id: number,
	itemType: "Asset" | "Unknown",
	property: string,

	mainCategory: string,
	subCategory: string,
	groupId: string,

	source: "HumanoidDescription",
}
```

For Phase 8, most worn items can be represented as `Asset`.

Bundles are not reliably reconstructable from HumanoidDescription alone.

If an item originally came from a body bundle or animation bundle, the LiveSnapshot may only contain individual body/animation asset IDs.

Do not try to infer original bundle in Phase 8.

---

## 6.2 Extraction Rules

### CSV accessory properties

Properties like:

```text
HairAccessory = "123,456"
JacketAccessory = "789"
```

must be split into individual items.

Pseudo-code:

```luau
local function extractCsvIds(value)
	local ids = {}

	if typeof(value) ~= "string" or value == "" then
		return ids
	end

	for token in string.gmatch(value, "[^,]+") do
		local id = tonumber(token)
		if id and id > 0 then
			table.insert(ids, id)
		end
	end

	return ids
end
```

Each ID becomes one WornItem.

---

### Single asset number properties

Properties like:

```text
Shirt = 123
Pants = 456
Head = 789
WalkAnimation = 111
```

become one WornItem if value is:

```text
number > 0
```

Ignore:

```text
0
nil
empty string
```

---

## 6.3 Property Classification

Create mapping:

```luau
local PROPERTY_CLASSIFICATION = {
	-- Body
	HairAccessory = { mainCategory = "body", subCategory = "hair", groupId = "body" },
	Head = { mainCategory = "body", subCategory = "head", groupId = "body" },
	Face = { mainCategory = "body", subCategory = "face", groupId = "body" },
	Torso = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },
	LeftArm = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },
	RightArm = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },
	LeftLeg = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },
	RightLeg = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },

	-- 3D Clothing
	TShirtAccessory = { mainCategory = "3d_clothing", subCategory = "tshirt", groupId = "3d_clothing" },
	ShirtAccessory = { mainCategory = "3d_clothing", subCategory = "shirt", groupId = "3d_clothing" },
	PantsAccessory = { mainCategory = "3d_clothing", subCategory = "pants", groupId = "3d_clothing" },
	JacketAccessory = { mainCategory = "3d_clothing", subCategory = "jacket", groupId = "3d_clothing" },
	SweaterAccessory = { mainCategory = "3d_clothing", subCategory = "sweater", groupId = "3d_clothing" },
	ShortsAccessory = { mainCategory = "3d_clothing", subCategory = "shorts", groupId = "3d_clothing" },
	DressSkirtAccessory = { mainCategory = "3d_clothing", subCategory = "dress_skirt", groupId = "3d_clothing" },
	LeftShoeAccessory = { mainCategory = "3d_clothing", subCategory = "left_shoe", groupId = "3d_clothing" },
	RightShoeAccessory = { mainCategory = "3d_clothing", subCategory = "right_shoe", groupId = "3d_clothing" },

	-- Classic Clothing
	GraphicTShirt = { mainCategory = "classic_clothing", subCategory = "classic_tshirt", groupId = "classic_clothing" },
	Shirt = { mainCategory = "classic_clothing", subCategory = "classic_shirt", groupId = "classic_clothing" },
	Pants = { mainCategory = "classic_clothing", subCategory = "classic_pants", groupId = "classic_clothing" },

	-- Accessories
	HatAccessory = { mainCategory = "accessories", subCategory = "hats", groupId = "accessories" },
	FaceAccessory = { mainCategory = "accessories", subCategory = "face", groupId = "accessories" },
	NeckAccessory = { mainCategory = "accessories", subCategory = "neck", groupId = "accessories" },
	ShoulderAccessory = { mainCategory = "accessories", subCategory = "shoulder", groupId = "accessories" },
	ShouldersAccessory = { mainCategory = "accessories", subCategory = "shoulder", groupId = "accessories" },
	FrontAccessory = { mainCategory = "accessories", subCategory = "front", groupId = "accessories" },
	BackAccessory = { mainCategory = "accessories", subCategory = "back", groupId = "accessories" },
	WaistAccessory = { mainCategory = "accessories", subCategory = "waist", groupId = "accessories" },

	-- Animation
	IdleAnimation = { mainCategory = "animation", subCategory = "idle", groupId = "animation" },
	WalkAnimation = { mainCategory = "animation", subCategory = "walk", groupId = "animation" },
	RunAnimation = { mainCategory = "animation", subCategory = "run", groupId = "animation" },
	JumpAnimation = { mainCategory = "animation", subCategory = "jump", groupId = "animation" },
	FallAnimation = { mainCategory = "animation", subCategory = "fall", groupId = "animation" },
	ClimbAnimation = { mainCategory = "animation", subCategory = "climb", groupId = "animation" },
	SwimAnimation = { mainCategory = "animation", subCategory = "swim", groupId = "animation" },
}
```

---

# 7. Filtering Logic

Create function:

```luau
function WornItemExtractor.filterItems(wornItems, mainCategoryId, subCategoryId)
	return filteredItems
end
```

Rules:

## Case 1 — Main = All, Sub = All

```text
return all worn items
```

## Case 2 — Main = All, Sub = group

Example:

```text
mainCategoryId = "all"
subCategoryId = "body"
```

Return:

```text
all worn items where groupId == "body"
```

## Case 3 — Main = specific, Sub = All

Example:

```text
mainCategoryId = "3d_clothing"
subCategoryId = "all"
```

Return:

```text
all worn items where mainCategory == "3d_clothing"
```

## Case 4 — Main = specific, Sub = specific

Example:

```text
mainCategoryId = "3d_clothing"
subCategoryId = "shirt"
```

Return:

```text
all worn items where mainCategory == "3d_clothing" and subCategory == "shirt"
```

---

# 8. Item Details Resolver

My Avatar cards need:

```text
thumbnail
name
price
creator
type label
```

LiveSnapshot only has IDs.

Create:

```text
src/client/services/WornItemDetailsService.luau
```

or reuse catalog item detail service if it already exists.

## Data flow

```text
WornItem[]
↓
dedupe IDs
↓
check local cache
↓
fetch missing details in batch
↓
merge WornItem + details
↓
render cards
```

## Cache key

```text
Asset:{id}
```

For Phase 8, treat extracted worn items as assets.

Do not infer bundles yet.

## Important

Number of worn items should be small, so this must be much lighter than Item Catalog infinite scroll.

Still use:

```text
batching
cache
no retry loop
```

## Failed detail

If detail fetch fails:

```text
show fallback card with asset id and property name
```

Do not hide the item entirely, because user is actually wearing it.

Fallback card:

```text
Unknown Item
Asset ID: 123456
Type: Hair
```

---

# 9. UI Plan

## 9.1 Add new tab

Tabs:

```text
Item Catalog
Avatar Loader
My Avatar
```

Default selected tab can remain existing one.

## 9.2 Reuse catalog UI components

Reuse:

```text
category sidebar / category tabs
subcategory row
grid card layout
skeleton card
empty state
```

Do not duplicate large UI components if existing components can be generalized.

Recommended component names:

```text
CatalogItemGrid
AvatarItemCard
CategorySelector
SubcategorySelector
```

My Avatar may use the same grid/card component but pass different data.

---

## 9.3 My Avatar page states

```text
loading live snapshot
loading item details
ready
empty category
error
```

## Loading

Show skeleton cards.

## Empty

Text:

```text
Kamu belum memakai item di kategori ini.
```

For All/All empty, use:

```text
Belum ada item yang bisa ditampilkan.
```

This should rarely happen because player usually has at least body/head/clothing data.

## Error

Text:

```text
Gagal memuat item yang sedang kamu pakai.
```

Add retry button:

```text
Refresh
```

---

# 10. Live Update Behavior

My Avatar must refresh when LiveSnapshot changes.

Sources that change LiveSnapshot:

```text
Catalog Try-On
Morph
Reset Original
Respawn Reapply
```

Implementation options:

## Option A — Pull on tab open

Simplest:

```text
Every time My Avatar tab opens:
  GetAppearanceStateRemote
  extract worn items
  resolve details
```

## Option B — Subscribe to client live state

Better if Phase 7 already has `AvatarAppearanceClient`:

```text
AvatarAppearanceClient.OnLiveSnapshotChanged
↓
My Avatar recomputes wornItems
```

Recommended:

```text
Use Option A first.
Add Option B if live state client service already exists.
```

## Acceptance

- If user try-ons a catalog item, then opens My Avatar, item appears.
- If user morphs, then opens My Avatar, morph items appear.
- If My Avatar is already open and LiveSnapshot changes, refresh if event system exists.

---

# 11. Optional Remove / Unequip Action

Not required for first Phase 8.

If added later:

```text
User clicks remove on a worn item
↓
mutate LiveSnapshot property to empty/0
↓
send TryOnDescription / ApplySnapshot request
↓
server updates LiveSnapshot
↓
My Avatar refreshes
```

Do not implement remove in first pass unless specifically requested.

Reason:

```text
Remove behavior for body parts/animations/bundles can be tricky.
Need default fallback values.
```

Phase 8 should be view-only first.

---

# 12. Optional Checkout Preparation

Not part of this phase.

Important note:

```text
My Avatar extracted from LiveSnapshot does not always know original bundle source.
```

Example:

```text
Body bundle becomes individual Head/Torso/Arm/Leg asset ids.
Animation bundle becomes individual animation asset ids.
```

For checkout later, keep separate source cart when items are tried on from Item Catalog.

Do not make Phase 8 checkout-aware yet.

---

# 13. Sub-Phase Breakdown

Do not implement all at once.

Use this order:

```text
8.0 Audit existing tab/page structure
8.1 Add My Avatar tab shell
8.2 Add MyAvatarCategoryConfig
8.3 Add WornItemExtractor
8.4 Render extracted worn items without details
8.5 Add details resolver/cache
8.6 Reuse catalog card/grid UI
8.7 Add category/subcategory filtering
8.8 Add live snapshot refresh behavior
8.9 Add fallback/empty/error states
8.10 Manual test matrix
```

---

# 14. Sub-Phase 8.0 — Audit Existing UI Structure

## Goal

Understand current tabs and reusable UI components.

Inspect:

```text
src/client/components
src/client/components/catalog
src/client/controllers
src/client/hooks
src/client/services
```

Find:

```text
where Item Catalog tab is defined
where Avatar Loader tab is defined
where category selector is implemented
where item grid/card is implemented
where catalog item details are resolved
```

## Acceptance

Agent must know which components to reuse before coding.

---

# 15. Sub-Phase 8.1 — Add My Avatar Tab Shell

## Goal

Add third tab without implementing data logic yet.

Tabs:

```text
Item Catalog
Avatar Loader
My Avatar
```

My Avatar shell should display placeholder:

```text
My Avatar
Items you are currently wearing will appear here.
```

## Acceptance

- New tab appears.
- Switching tabs works.
- Existing tabs still work.

---

# 16. Sub-Phase 8.2 — Add MyAvatarCategoryConfig

## Goal

Add category/subcategory definitions.

File:

```text
src/shared/avatar/MyAvatarCategoryConfig.luau
```

Use config from Section 5.

## Acceptance

- My Avatar page can render main categories.
- Selecting a main category updates available subcategories.
- Main All shows high-level group subcategories.

---

# 17. Sub-Phase 8.3 — Add WornItemExtractor

## Goal

Convert LiveSnapshot into WornItem[].

File:

```text
src/shared/avatar/WornItemExtractor.luau
```

Required functions:

```luau
WornItemExtractor.extract(snapshot)
WornItemExtractor.filterItems(items, mainCategoryId, subCategoryId)
```

## Acceptance

Given snapshot:

```luau
{
	HairAccessory = "111",
	Shirt = 222,
	JacketAccessory = "333",
	WalkAnimation = 444,
}
```

extract returns:

```text
Hair item 111
Classic shirt 222
Jacket 333
Walk animation 444
```

---

# 18. Sub-Phase 8.4 — Render Worn Items Without Details

## Goal

First render extracted items using fallback data only.

Card content:

```text
Property label
Asset ID
Category
```

Example:

```text
Hair
Asset ID: 111
Body / Hair
```

Do not fetch details yet.

## Acceptance

- Open My Avatar.
- Items from LiveSnapshot appear as basic cards.
- Category filters work with basic data.

---

# 19. Sub-Phase 8.5 — Add Worn Item Details Resolver

## Goal

Resolve asset details for nicer cards.

File:

```text
src/client/services/WornItemDetailsService.luau
```

Inputs:

```text
WornItem[]
```

Outputs:

```text
WornDisplayItem[]
```

Where display item includes:

```text
name
thumbnail/image
price
creator
asset type label
```

Use cache.

## Important

If detail fails:

```text
fallback card remains visible
```

## Acceptance

- Cards show name/image when details are resolved.
- Failed item still shows fallback card.
- Cache prevents repeated fetch on tab switch.

---

# 20. Sub-Phase 8.6 — Reuse Catalog Card/Grid UI

## Goal

Make My Avatar visually match Item Catalog.

Use same card/grid skeleton style.

Differences:

```text
My Avatar cards are worn item cards.
No Try-On button needed in first pass.
```

Optional card action:

```text
View Details
```

Do not add remove/unequip yet.

## Acceptance

- My Avatar visually matches catalog style.
- No broken layout.
- Skeleton and empty states look consistent.

---

# 21. Sub-Phase 8.7 — Category/Subcategory Filtering

## Goal

Implement final category behavior.

Test cases:

```text
All / All -> all worn items
All / Body -> all body group worn items
All / 3D Clothing -> all 3d clothing worn items
3D Clothing / All -> all 3d clothing worn items
3D Clothing / Shirt -> only ShirtAccessory
Classic Clothing / Classic Shirt -> only Shirt
Accessories / Back -> only BackAccessory
Animation / Walk -> only WalkAnimation
```

## Acceptance

All filters return expected items.

---

# 22. Sub-Phase 8.8 — Live Snapshot Refresh Behavior

## Goal

My Avatar updates when live appearance changes.

Minimum implementation:

```text
On My Avatar tab open:
  fetch latest LiveSnapshot
```

Better implementation if available:

```text
AvatarAppearanceClient.OnLiveSnapshotChanged:
  recompute wornItems
  refresh UI if My Avatar is mounted/open
```

## Acceptance

- Try-On item in catalog.
- Switch to My Avatar.
- New item appears.

- Morph character.
- Switch to My Avatar.
- Morph items appear.

---

# 23. Sub-Phase 8.9 — Empty/Error/Fallback States

## Goal

Handle real-world imperfect data.

Required states:

```text
loading
empty
error
fallback item card
```

## Empty text

Specific category:

```text
Kamu belum memakai item di kategori ini.
```

All category:

```text
Belum ada item yang bisa ditampilkan.
```

## Error text

```text
Gagal memuat item yang sedang kamu pakai.
```

## Acceptance

- Empty categories do not crash.
- Failed item details do not hide worn item.
- Retry works if implemented.

---

# 24. Manual Test Matrix

Do not mark Phase 8 complete until these pass.

## Test 1 — Tab exists

```text
Open UI
Expected:
Item Catalog, Avatar Loader, My Avatar tabs visible
```

## Test 2 — Default My Avatar

```text
Open My Avatar
Expected:
Main = All
Sub = All
Shows all currently worn extracted items
```

## Test 3 — Body group

```text
Select Main All, Sub Body
Expected:
Hair/head/face/body-related items visible
No classic shirt/pants unless classified as body accidentally
```

## Test 4 — 3D Clothing group

```text
Wear jacket
Open My Avatar
Select All / 3D Clothing
Expected:
Jacket appears
```

## Test 5 — 3D Clothing specific subcategory

```text
Wear layered shirt
Select Main 3D Clothing, Sub Shirt
Expected:
Only ShirtAccessory appears
```

## Test 6 — Classic Clothing

```text
Wear classic shirt and pants
Select Classic Clothing / All
Expected:
Classic shirt and pants visible

Select Classic Clothing / Classic Shirt
Expected:
Only Shirt property item visible
```

## Test 7 — Accessories

```text
Wear hair and back accessory
Select Accessories / All
Expected:
Back accessory appears
Hair should appear under Body / Hair, not Accessories, based on current config

Select Accessories / Back
Expected:
Back accessory visible
```

## Test 8 — Animation

```text
Wear walk animation
Select Animation / Walk
Expected:
WalkAnimation asset visible
```

## Test 9 — After catalog try-on

```text
Use Item Catalog to try-on hair A
Open My Avatar
Expected:
Hair A visible
```

## Test 10 — After morph

```text
Morph into model
Open My Avatar
Expected:
Items from current morph LiveSnapshot visible
```

## Test 11 — Detail failure fallback

```text
Force detail resolver to fail for one id
Expected:
Fallback card still shows asset id/property
```

## Test 12 — Cache

```text
Open My Avatar
Switch away
Open My Avatar again
Expected:
Cached details reused when possible
No excessive detail requests
```

---

# 25. What Not To Do

Do not:

```text
- Use catalog search result as My Avatar source.
- Use last clicked item state as My Avatar source.
- Use old draft/preview state.
- Infer original bundle from HumanoidDescription in Phase 8.
- Add checkout logic in Phase 8.
- Add remove/unequip unless specifically requested.
- Hide worn items just because details failed to load.
- Break Item Catalog UI while reusing components.
```

---

# 26. Final Acceptance Criteria

Phase 8 is complete only if:

1. My Avatar tab exists.
2. My Avatar reads from LiveSnapshot.
3. My Avatar extracts worn items from HumanoidDescription snapshot.
4. Main category/subcategory behavior matches this plan.
5. Default All/All shows all worn items.
6. All + group subcategory shows that group.
7. Specific category + specific subcategory shows only that item type.
8. Item details resolve with cache.
9. Fallback card appears if details fail.
10. My Avatar updates after catalog try-on.
11. My Avatar updates after morph.
12. Existing Item Catalog and Avatar Loader still work.
13. Manual test matrix passes.

---

# 27. Suggested Commit Plan

Use small commits:

```text
phase8-0-audit-tabs-and-components
phase8-1-add-my-avatar-tab-shell
phase8-2-add-my-avatar-category-config
phase8-3-add-worn-item-extractor
phase8-4-render-basic-worn-items
phase8-5-add-worn-item-details-cache
phase8-6-reuse-catalog-card-grid
phase8-7-category-subcategory-filtering
phase8-8-live-snapshot-refresh
phase8-9-empty-error-fallback-states
phase8-10-test-matrix-cleanup
```

---

# 28. Short Instruction for AI Agent

Implement a new `My Avatar` tab.

It should look like Item Catalog, but its data source is not catalog search.

Data source:

```text
AvatarAppearanceService.LiveSnapshot
```

Process:

```text
LiveSnapshot
↓
WornItemExtractor.extract()
↓
filter by main category/subcategory
↓
resolve item details/cache
↓
render cards
```

Default behavior:

```text
My Avatar opens with All / All
Shows all items currently worn by the player
```

Category behavior:

```text
All / Body = all body worn items
All / 3D Clothing = all layered clothing worn items
3D Clothing / Shirt = only ShirtAccessory worn item
Accessories / Back = only BackAccessory worn item
Animation / Walk = only WalkAnimation worn item
```

Do not implement checkout or remove/unequip in this phase.

The goal is simple:

```text
My Avatar displays what the player is currently wearing now.
```
