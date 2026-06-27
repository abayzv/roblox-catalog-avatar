# Phase 12 Technical Plan — Avatar Loader MVP

Project: `abayzv/roblox-catalog-avatar`  
Baseline: Phase 7 Live-First Try-On + Phase 8 My Avatar + Phase 11 Search Optimization  
Goal: implement the first usable version of **Avatar Loader**.

---

## 0. Core Idea

`Avatar Loader` is a feature for loading outfit/avatar templates.

For this MVP, Avatar Loader default content comes only from the game database:

```text
Generated User Templates
```

These templates are created when a player saves their current live avatar.

Roblox username outfit search/import can be added later, but it is **not the default database source**.

---

## 1. MVP Scope

### Included in this phase

```text
1. Avatar Loader tab displays template cards from database.
2. Template names use dummy names:
   Template 1
   Template 2
   Template 3
   ...
3. Card displays:
   - thumbnail
   - template name
   - creator username
   - Load button
4. Load button applies template to live character.
5. Save Template button appears in the ViewportFrame area.
6. Save Template saves the player's current LiveSnapshot into database.
7. Saved template receives generated unique code.
8. Newly saved template can appear in Avatar Loader list.
```

### Not included in this phase

```text
1. Category template.
2. Tags.
3. Likes.
4. Recommended templates.
5. Total price display.
6. Username Roblox outfit search/import.
7. Load by code UI.
8. Perfect generated static thumbnail.
9. Checkout.
```

These can be future phases.

---

## 2. Product Rules

### Rule 1 — Database templates are the default Avatar Loader content

When opening Avatar Loader:

```text
Load templates from game database
Render template cards
```

Do not fetch Roblox username outfits by default.

---

### Rule 2 — Template name is dummy for now

Use generated display names:

```text
Template 1
Template 2
Template 3
```

For testing, do not require user-entered template name yet.

The real name form can be added later.

---

### Rule 3 — Save Template uses the live character

Because the project is live-first:

```text
LiveSnapshot = source of truth
```

When player saves a template:

```text
Server reads AvatarAppearanceService.LiveSnapshot
Server saves that snapshot
```

Do not trust a client-provided HumanoidDescription snapshot for saving.

---

### Rule 4 — Player should load/apply an outfit before Save button is useful

Save button should be placed in the ViewportFrame area.

Recommended visibility for MVP:

```text
Show if LiveSnapshot exists and not currently applying.
```

Better future visibility:

```text
Show after player has changed/loaded avatar at least once in current session.
```

---

### Rule 5 — Load goes through AvatarAppearanceService

When user clicks template Load:

```text
Template descriptionSnapshot
↓
AvatarAppearanceService.applyDescriptionSnapshot(player, snapshot, "avatar_loader")
↓
LiveSnapshot updates
↓
ViewportFrame syncs
↓
My Avatar syncs
```

Do not apply HumanoidDescription outside the central service.

---

### Rule 6 — Thumbnail can be placeholder in MVP

For database-generated templates, static thumbnail generation is not required yet.

Card thumbnail may use:

```text
placeholder image
creator avatar thumbnail
simple default avatar icon
```

Do not render a ViewportFrame for every card.

---

# 3. Data Model

## 3.1 AvatarTemplateRecord

Create template record shape:

```luau
export type AvatarTemplateRecord = {
	templateId: string,
	code: string,

	name: string, -- "Template 1", "Template 2", etc.

	creatorUserId: number,
	creatorUsername: string,
	creatorDisplayName: string?,

	descriptionSnapshot: { [string]: any },

	thumbnail: {
		imageUrl: string?,
		state: "Placeholder" | "Ready" | "Failed",
	},

	loadCount: number,

	createdAt: number,
	updatedAt: number,
	version: number,
}
```

For MVP, do not include required category/tags/likes/price.

---

## 3.2 AvatarTemplateCardData

Client display shape:

```luau
export type AvatarTemplateCardData = {
	templateId: string,
	code: string,

	name: string,
	creatorUsername: string,

	thumbnailUrl: string?,
	thumbnailState: string,

	loadCount: number?,
}
```

Card should display only:

```text
thumbnail
name
creator username
Load button
```

---

# 4. Database / Storage Design

This phase can use any existing database abstraction if the project already has one.

If using Roblox DataStore, use simple MVP stores:

```text
AvatarTemplateById
AvatarTemplateIndex
UserAvatarTemplateIndex:{userId}
CodeToTemplateId
```

## 4.1 AvatarTemplateById

Key:

```text
templateId
```

Value:

```text
AvatarTemplateRecord
```

## 4.2 AvatarTemplateIndex

A simple global list of template IDs.

For MVP:

```text
recent templates only
```

This is enough to render default Avatar Loader list.

Do not build category/tag index yet.

## 4.3 UserAvatarTemplateIndex

Optional for MVP.

Key:

```text
UserAvatarTemplateIndex:{creatorUserId}
```

Value:

```text
{ templateId1, templateId2, ... }
```

Useful later for "My Templates".

## 4.4 CodeToTemplateId

Key:

```text
generated code
```

Value:

```text
templateId
```

Load-by-code UI is future, but saving the code mapping now is useful.

---

# 5. Unique Code Generation

Every saved template needs a unique code.

Example code format:

```text
AVT-8K4P2
```

Allowed characters:

```text
ABCDEFGHJKLMNPQRSTUVWXYZ23456789
```

Avoid ambiguous characters:

```text
O, 0, I, 1
```

Pseudo-code:

```luau
local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

local function generateCode()
	local result = "AVT-"

	for i = 1, 5 do
		local index = math.random(1, #ALPHABET)
		result ..= string.sub(ALPHABET, index, index)
	end

	return result
end
```

Collision guard:

```text
generate code
check CodeToTemplateId
if exists, generate again
max attempts 5
```

---

# 6. Dummy Template Naming

Template names for MVP:

```text
Template 1
Template 2
Template 3
```

Name should be generated server-side when saving.

Recommended:

```text
Template {globalTemplateCount + 1}
```

If global count is hard to maintain safely in DataStore, use per-user count:

```text
Template {userTemplateCount + 1}
```

For Studio testing, sequential numbering is preferred.

---

# 7. Server Services

Create or refactor:

```text
src/server/services/AvatarTemplateService.luau
```

## API

```luau
local AvatarTemplateService = {}

function AvatarTemplateService.listTemplates(player, params)
end

function AvatarTemplateService.saveCurrentAvatarAsTemplate(player)
end

function AvatarTemplateService.loadTemplate(player, templateId)
end

function AvatarTemplateService.getTemplate(templateId)
end

return AvatarTemplateService
```

---

## 7.1 listTemplates

For MVP:

```text
read recent template ids from AvatarTemplateIndex
fetch template records
return card data
```

Response:

```luau
{
	success = true,
	templates = {
		{
			templateId = "...",
			code = "AVT-8K4P2",
			name = "Template 1",
			creatorUsername = "Abay",
			thumbnailUrl = nil,
			thumbnailState = "Placeholder",
		}
	}
}
```

---

## 7.2 saveCurrentAvatarAsTemplate

Flow:

```text
1. Get player's LiveSnapshot from AvatarAppearanceService.
2. Validate snapshot exists.
3. Generate templateId.
4. Generate unique code.
5. Generate dummy name:
   Template N
6. Create AvatarTemplateRecord.
7. Save to AvatarTemplateById.
8. Add templateId to AvatarTemplateIndex.
9. Add templateId to user's template index if implemented.
10. Save CodeToTemplateId mapping.
11. Return saved template card data.
```

Important:

```text
Do not accept client snapshot as source of truth.
```

Client can call:

```luau
SaveTemplateRemote:InvokeServer()
```

No payload required for MVP except optional future fields.

---

## 7.3 loadTemplate

Flow:

```text
1. Fetch template by templateId.
2. Validate template exists.
3. Read descriptionSnapshot.
4. AvatarAppearanceService.applyDescriptionSnapshot(player, snapshot, "avatar_loader").
5. Increment loadCount.
6. Return updated LiveSnapshot from AvatarAppearanceService.
```

Response:

```luau
{
	success = true,
	liveSnapshot = {...},
	liveRevision = 12,
	templateId = "...",
}
```

---

# 8. Remotes

Create remotes:

```text
ListAvatarTemplatesRemote
SaveAvatarTemplateRemote
LoadAvatarTemplateRemote
```

Or use one remote with an action field if project pattern prefers.

## 8.1 ListAvatarTemplatesRemote

Request:

```luau
{
	limit = 30,
	cursor = nil,
}
```

Response:

```luau
{
	success = true,
	templates = {...},
	nextCursor = nil,
}
```

## 8.2 SaveAvatarTemplateRemote

Request:

```luau
{}
```

Response:

```luau
{
	success = true,
	template = {
		templateId = "...",
		code = "AVT-8K4P2",
		name = "Template 4",
		creatorUsername = "Abay",
		thumbnailState = "Placeholder",
	},
}
```

## 8.3 LoadAvatarTemplateRemote

Request:

```luau
{
	templateId = "...",
}
```

Response:

```luau
{
	success = true,
	liveSnapshot = {...},
	liveRevision = 12,
	templateId = "...",
}
```

---

# 9. Client UI

## 9.1 Avatar Loader default page

When opening Avatar Loader tab:

```text
show skeleton
call ListAvatarTemplatesRemote
render template cards
```

Card layout:

```text
[Thumbnail]
Template 1
by Abay
[Load]
```

## 9.2 Save Template button in ViewportFrame

Save button should appear in or near the ViewportFrame area.

Label:

```text
Save Template
```

Visibility for MVP:

```text
show if LiveSnapshot exists and player is not currently applying
```

Optional better visibility:

```text
show after player has changed/loaded avatar in current session
```

## 9.3 Save button behavior

```text
Click Save Template
↓
disable button / show Saving...
↓
SaveAvatarTemplateRemote:InvokeServer()
↓
on success:
  show saved code/print
  add new template card to list
↓
on fail:
  warn/print error
```

For MVP, notification can be:

```luau
print("[AvatarLoader] Template saved:", response.template.code)
```

Later replace with toast/modal.

## 9.4 Load button behavior

```text
Click Load
↓
disable this card button / show Loading...
↓
LoadAvatarTemplateRemote:InvokeServer(templateId)
↓
server applies template
↓
client receives liveSnapshot
↓
AvatarAppearanceClient hydrate live state
↓
ViewportFrame syncs
↓
My Avatar syncs
```

---

# 10. Thumbnail Strategy

For MVP, use placeholder.

```luau
thumbnail = {
	imageUrl = nil,
	state = "Placeholder",
}
```

UI should render:

```text
default avatar silhouette
or generic placeholder image
```

Do not render live ViewportFrame per card.

Future thumbnail options:

```text
1. Render selected template in detail ViewportFrame.
2. Generate static thumbnail service.
3. Use creator avatar thumbnail as placeholder.
```

Do not implement future thumbnail system in this phase.

---

# 11. Save Button Source of Truth

The player must already have a live avatar state before saving.

Server should save:

```text
AvatarAppearanceService.getLiveSnapshot(player)
```

not:

```text
client current UI state
client preview data
client supplied snapshot
```

This guarantees saved template matches what player is currently wearing.

---

# 12. Load Template Source of Truth

Template load should apply:

```text
template.descriptionSnapshot
```

through:

```text
AvatarAppearanceService.applyDescriptionSnapshot
```

This ensures:

```text
LiveSnapshot updates
Viewport updates
My Avatar updates
Respawn reapply works
```

---

# 13. Basic Validation

## Save validation

```text
player has LiveSnapshot
snapshot passes HumanoidDescriptionSerializer.validateSnapshot
player save cooldown passed
user template limit not exceeded
```

Recommended MVP values:

```text
SAVE_COOLDOWN = 5 seconds
MAX_TEMPLATES_PER_USER = 25
```

If user limit is not implemented yet, implement cooldown at least.

## Load validation

```text
templateId must be string
template exists
descriptionSnapshot valid
```

---

# 14. Sub-Phase Breakdown

Do not implement all at once.

Use this order:

```text
12.0 Audit Avatar Loader tab and current services
12.1 Add AvatarTemplateRecord types/config
12.2 Add AvatarTemplateService server module
12.3 Add template list remote
12.4 Add Avatar Loader card UI with dummy data
12.5 Wire list remote to Avatar Loader UI
12.6 Add load template remote + apply via AvatarAppearanceService
12.7 Add Save Template button in ViewportFrame
12.8 Add save current LiveSnapshot as template
12.9 Add unique code generation
12.10 Add cooldown/validation/error states
12.11 Manual test matrix
```

---

# 15. Sub-Phase 12.0 — Audit

Inspect:

```text
Avatar Loader tab/page
Tab navigation component
ViewportFrame container/component
AvatarAppearanceService
AvatarAppearanceClient
HumanoidDescriptionSerializer
DataStore/database abstraction if any
Existing remotes folder/pattern
```

Find:

```text
where Avatar Loader placeholder currently exists
where ViewportFrame buttons are placed
how client hydrates LiveSnapshot after server apply
how server services are initialized
how remotes are created
```

Acceptance:

```text
Agent knows where to add Avatar Loader UI and server template service.
```

---

# 16. Sub-Phase 12.1 — Add Types/Config

Add shared types if project uses typed Luau:

```text
src/shared/types/AvatarTemplateTypes.luau
```

Include:

```text
AvatarTemplateRecord
AvatarTemplateCardData
ListTemplatesResponse
SaveTemplateResponse
LoadTemplateResponse
```

Acceptance:

```text
Types compile and do not affect runtime.
```

---

# 17. Sub-Phase 12.2 — AvatarTemplateService

Implement server service with in-memory mock first if database abstraction is not ready.

Recommended MVP approach:

```text
Start with in-memory store for Studio testing.
Then swap to DataStore/database wrapper.
```

If using in-memory for first commit, clearly mark:

```text
TODO: replace with persistent store
```

Acceptance:

```text
Can save/list/load templates in the same server session.
```

---

# 18. Sub-Phase 12.3 — Template List Remote

Implement:

```text
ListAvatarTemplatesRemote
```

Acceptance:

```text
Client can request template list.
Returns empty list gracefully.
```

---

# 19. Sub-Phase 12.4 — Avatar Loader Card UI with Dummy Data

Before wiring database, render dummy cards:

```text
Template 1
Template 2
Template 3
```

Card fields:

```text
thumbnail placeholder
template name
creator username
Load button
```

Acceptance:

```text
Avatar Loader tab visually works.
```

---

# 20. Sub-Phase 12.5 — Wire List Remote

Replace dummy local list with remote response.

Acceptance:

```text
Avatar Loader renders templates from service.
Empty state works.
Loading skeleton works.
```

---

# 21. Sub-Phase 12.6 — Load Template

Implement Load button.

Flow:

```text
click Load
↓
LoadAvatarTemplateRemote(templateId)
↓
server applies template through AvatarAppearanceService
↓
client hydrates live state from response
```

Acceptance:

```text
Loading template changes live character.
Viewport syncs.
My Avatar syncs.
```

---

# 22. Sub-Phase 12.7 — Save Template Button

Add button near ViewportFrame.

Label:

```text
Save Template
```

Visibility:

```text
visible when LiveSnapshot exists
```

Optional better:

```text
visible after player has changed/loaded avatar in current session
```

Acceptance:

```text
Button appears in ViewportFrame area.
Clicking calls save remote.
```

---

# 23. Sub-Phase 12.8 — Save Current LiveSnapshot

Server saves:

```text
AvatarAppearanceService.getLiveSnapshot(player)
```

Generate name:

```text
Template N
```

Acceptance:

```text
Click Save Template
New template is created from current live avatar.
New template appears in Avatar Loader list.
```

---

# 24. Sub-Phase 12.9 — Unique Code Generation

Generate code for saved template.

Acceptance:

```text
Saved template response includes unique code.
Duplicate code collision is handled.
```

For MVP, code can be printed:

```text
Template saved: AVT-8K4P2
```

No Load Code UI yet.

---

# 25. Sub-Phase 12.10 — Cooldown/Error States

Implement:

```text
save cooldown
load in-progress state
empty list state
server error handling
```

Acceptance:

```text
Spam Save does not create too many templates.
Load button disables while loading.
Errors print/warn cleanly.
```

---

# 26. Manual Test Matrix

Do not mark Phase 12 complete until these pass.

## Test 1 — Avatar Loader tab opens

```text
Open Avatar Loader
Expected:
template list area appears
empty state or templates appear
```

## Test 2 — Dummy/database templates render

```text
Have templates in service
Open Avatar Loader
Expected:
cards show thumbnail placeholder, Template N, creator username, Load button
```

## Test 3 — Save current avatar

```text
Use Item Catalog or Morph to change avatar
Click Save Template
Expected:
new template saved with name Template N
code generated
creator username saved
```

## Test 4 — New template appears

```text
After save
Open/refresh Avatar Loader
Expected:
new template card appears
```

## Test 5 — Load template

```text
Click Load on template
Expected:
live character changes to template
Viewport syncs
My Avatar syncs
```

## Test 6 — Save loaded template

```text
Load template A
Click Save Template
Expected:
new template created from currently loaded avatar
```

## Test 7 — Save cooldown

```text
Click Save repeatedly
Expected:
cooldown prevents spam
```

## Test 8 — Empty database

```text
No templates exist
Open Avatar Loader
Expected:
empty state, no crash
```

## Test 9 — Invalid template

```text
Try load missing templateId
Expected:
server returns error
client warns/prints
```

## Test 10 — Respawn after load

```text
Load template
Respawn
Expected:
loaded template remains applied through LiveSnapshot reapply
```

---

# 27. What Not To Do

Do not:

```text
- Add category/tags form in this phase.
- Add likes/recommendations.
- Add Roblox username outfit import yet.
- Add Load Code UI yet.
- Render ViewportFrame for every template card.
- Trust client-provided snapshot when saving.
- Apply template outside AvatarAppearanceService.
- Require total price calculation for MVP.
```

---

# 28. Final Acceptance Criteria

Phase 12 is complete only if:

1. Avatar Loader tab displays database template cards.
2. Template names are dummy sequential names like Template 1, Template 2.
3. Card displays thumbnail placeholder, template name, creator username, Load button.
4. Load button applies template through AvatarAppearanceService.
5. Save Template button exists in ViewportFrame area.
6. Save Template saves current server LiveSnapshot.
7. Saved template generates unique code.
8. Saved template appears in Avatar Loader list.
9. Save/load have basic loading/error/cooldown handling.
10. Existing Item Catalog, My Avatar, Morph, and LiveSnapshot flow still work.
11. Manual test matrix passes.

---

# 29. Suggested Commit Plan

```text
phase12-0-audit-avatar-loader
phase12-1-template-types-config
phase12-2-avatar-template-service
phase12-3-list-templates-remote
phase12-4-avatar-loader-card-ui-dummy
phase12-5-wire-list-remote
phase12-6-load-template-remote
phase12-7-save-template-button
phase12-8-save-current-live-snapshot
phase12-9-unique-code-generation
phase12-10-cooldown-error-states
phase12-11-test-matrix-cleanup
```

---

# 30. Short Instruction for AI Agent

Implement Avatar Loader MVP.

Default Avatar Loader content comes from database templates generated by users.

For now:

```text
Template names are dummy:
Template 1, Template 2, Template 3, ...
```

Card shows:

```text
thumbnail placeholder
template name
creator username
Load button
```

Save Template button appears near ViewportFrame.

Save Template must save the player's current server LiveSnapshot from AvatarAppearanceService.

Load Template must apply the saved descriptionSnapshot through AvatarAppearanceService.

Do not add category, tags, likes, recommendations, Roblox username import, or load-code UI in this phase.
