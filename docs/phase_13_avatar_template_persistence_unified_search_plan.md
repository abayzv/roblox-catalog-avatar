# Phase 13 Technical Plan — Avatar Template Persistence & Unified Loader Search

Project: `abayzv/roblox-catalog-avatar`  
Baseline: Phase 12 Avatar Loader MVP  
Goal: persist generated avatar templates with DataStore and add unified Avatar Loader search for template code and Roblox username/userId import.

---

## 0. Core Goal

Phase 12 already introduced Avatar Loader MVP with mock/in-memory template behavior.

Phase 13 makes it persistent and adds a more useful search flow.

This phase implements:

```text
1. DataStore persistence for generated user templates.
2. Unique template code mapping.
3. Recent templates index for Avatar Loader default list.
4. Save Template writes current server LiveSnapshot.
5. Load Template from DataStore.
6. Unified Avatar Loader search:
   - first search template code
   - if not found, fallback to Roblox username/userId outfits
   - if still not found, show empty state
```

---

## 1. Product Scope

### Included

```text
Generated template persistence
Template code lookup
Recent template list
Save Template DataStore write
Load Template DataStore read + apply
Search by code
Fallback search by Roblox username/userId
Roblox outfit list import
Roblox outfit load/apply
Empty/loading/error states
```

### Not Included

```text
Category
Tags
Likes
Recommended templates
Checkout
Template thumbnail generation
Template edit/delete
Load by code separate UI
Roblox current avatar import
Saving Roblox outfit automatically to database
```

Important:

```text
Roblox username outfit import is temporary load/import only.
It does not enter the database unless the user later clicks Save Template.
```

---

# 2. Final User Flow

## 2.1 Avatar Loader default

```text
User opens Avatar Loader
↓
Client requests recent generated templates
↓
Server loads from DataStore index
↓
Cards render:
  thumbnail placeholder
  Template N
  creator username
  Load button
```

---

## 2.2 Save Template

```text
User has current live avatar
↓
User clicks Save Template
↓
Server reads AvatarAppearanceService.LiveSnapshot
↓
Server creates AvatarTemplateRecord
↓
Server writes template to DataStore
↓
Server writes code mapping
↓
Server updates recent index
↓
Server returns saved template card + code
↓
Client adds/refreshes card in Avatar Loader
```

User should only receive a saved code after the persistence write succeeds.

---

## 2.3 Load Template

```text
User clicks Load on database template card
↓
Server fetches template record
↓
Server applies template.descriptionSnapshot through AvatarAppearanceService
↓
LiveSnapshot updates
↓
Client hydrates from server response
↓
Viewport and My Avatar sync
```

---

## 2.4 Unified Search

Search input placeholder:

```text
Enter template code or Roblox username/userId
```

Submit behavior:

```text
1. Normalize input.
2. Try template code lookup.
3. If code exists:
   show matching template card.
4. If code not found:
   treat input as Roblox username or userId.
5. If user found:
   fetch/show that user's saved Roblox outfits.
6. If no code and no user/outfits:
   show empty state.
```

---

## 2.5 Roblox Outfit Import

```text
User searches username/userId
↓
Server resolves userId if needed
↓
Server fetches Roblox saved outfits for that user
↓
Client renders Roblox outfit cards
↓
User clicks Load
↓
Server fetches outfit details
↓
Server converts outfit details to HumanoidDescription snapshot
↓
Server applies snapshot through AvatarAppearanceService
↓
LiveSnapshot updates
```

This load is temporary.

If the user wants to save it into the game database:

```text
User clicks Save Template after loading/modifying it.
```

---

# 3. DataStore Design

Use separate stores.

```text
AvatarTemplateById
CodeToTemplateId
RecentAvatarTemplateIndex
UserAvatarTemplateIndex
```

---

## 3.1 AvatarTemplateById

Purpose:

```text
Primary template record storage.
```

Key:

```text
template:{templateId}
```

Value:

```luau
AvatarTemplateRecord
```

---

## 3.2 CodeToTemplateId

Purpose:

```text
Fast lookup from unique code to templateId.
```

Key:

```text
code:{code}
```

Value:

```luau
{
	templateId = "template_xxx",
	createdAt = 1234567890,
}
```

---

## 3.3 RecentAvatarTemplateIndex

Purpose:

```text
List recent public/generated templates for default Avatar Loader view.
```

Recommended type:

```text
OrderedDataStore
```

Key:

```text
templateId
```

Value:

```text
createdAt timestamp
```

---

## 3.4 UserAvatarTemplateIndex

Purpose:

```text
Optional per-user list for future My Templates.
```

Key:

```text
user:{creatorUserId}
```

Value:

```luau
{
	templateIds = {
		"template_a",
		"template_b",
	}
}
```

This can be implemented now if easy, but it is not required for Avatar Loader default list.

---

# 4. Template Record Schema

Create or update:

```text
src/shared/types/AvatarTemplateTypes.luau
```

## AvatarTemplateRecord

```luau
export type AvatarTemplateRecord = {
	templateId: string,
	code: string,

	name: string,

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

## AvatarTemplateCardData

```luau
export type AvatarTemplateCardData = {
	templateId: string,
	code: string,

	name: string,
	creatorUsername: string,
	creatorDisplayName: string?,

	thumbnailUrl: string?,
	thumbnailState: string,

	loadCount: number?,
}
```

---

# 5. Template Naming

For this phase, keep dummy names:

```text
Template 1
Template 2
Template 3
```

Name must be generated server-side.

Recommended:

```text
Template {nextNumber}
```

Implementation options:

```text
1. Use recent index count if simple.
2. Use per-server increment for Studio testing.
3. Use per-user count if UserAvatarTemplateIndex is implemented.
```

Do not add user custom name field in this phase.

---

# 6. Unique Code Generation

Code format:

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

local function generateTemplateCode()
	local result = "AVT-"

	for i = 1, 5 do
		local index = math.random(1, #ALPHABET)
		result ..= string.sub(ALPHABET, index, index)
	end

	return result
end
```

Collision handling:

```text
generate code
check CodeToTemplateId
if already exists, generate again
max attempts = 5
```

If still collides:

```text
return error CODE_GENERATION_FAILED
```

---

# 7. Server Services

Create/refactor:

```text
src/server/services/AvatarTemplatePersistenceService.luau
src/server/services/AvatarTemplateSearchService.luau
src/server/services/RobloxOutfitImportService.luau
```

If the project prefers one service, these can be modules under:

```text
src/server/services/AvatarTemplateService.luau
```

---

## 7.1 AvatarTemplatePersistenceService

Responsibilities:

```text
save generated template
get template by id
get template by code
list recent templates
increment load count
update recent index
```

API:

```luau
function AvatarTemplatePersistenceService.saveTemplate(player): SaveTemplateResult
function AvatarTemplatePersistenceService.getTemplate(templateId: string): AvatarTemplateRecord?
function AvatarTemplatePersistenceService.getTemplateByCode(code: string): AvatarTemplateRecord?
function AvatarTemplatePersistenceService.listRecentTemplates(limit: number, cursor: any?): ListTemplatesResult
function AvatarTemplatePersistenceService.incrementLoadCount(templateId: string)
```

---

## 7.2 AvatarTemplateSearchService

Responsibilities:

```text
normalize search query
search code first
fallback to username/userId
return unified result shape
```

API:

```luau
function AvatarTemplateSearchService.search(player, query: string): SearchResult
```

Search result types:

```text
template_code_result
roblox_user_outfits_result
empty
error
```

---

## 7.3 RobloxOutfitImportService

Responsibilities:

```text
resolve username/userId
fetch Roblox saved outfit list
fetch outfit details
convert outfit details to HumanoidDescription snapshot
cache username and outfit responses
```

API:

```luau
function RobloxOutfitImportService.resolveUser(query: string): (boolean, number?, string?)
function RobloxOutfitImportService.listUserOutfits(userId: number): ListRobloxOutfitsResult
function RobloxOutfitImportService.loadUserOutfit(player, userOutfitId: number): LoadRobloxOutfitResult
```

---

# 8. Save Template Implementation

## Flow

```text
SaveTemplateRemote invoked
↓
validate player cooldown
↓
get LiveSnapshot from AvatarAppearanceService
↓
validate snapshot
↓
generate templateId
↓
generate code
↓
generate dummy name
↓
create AvatarTemplateRecord
↓
write TemplateById
↓
write CodeToTemplateId
↓
write RecentAvatarTemplateIndex
↓
return success with card data
```

## Important Rules

```text
Do not accept client snapshot as save source.
Do not return success before primary persistence succeeds.
Do not return code as saved until code mapping succeeds.
```

## Cooldown

Recommended:

```text
SAVE_TEMPLATE_COOLDOWN = 15 seconds
```

## Per-user limit

Recommended:

```text
MAX_TEMPLATES_PER_USER = 25
```

If per-user index is not implemented yet, enforce cooldown at minimum.

---

# 9. Load Template Implementation

## Flow

```text
LoadAvatarTemplateRemote invoked with templateId
↓
fetch template record
↓
validate descriptionSnapshot
↓
AvatarAppearanceService.applyDescriptionSnapshot(player, snapshot, "avatar_loader")
↓
increment load count
↓
return server-confirmed LiveSnapshot
```

## Response

```luau
{
	success = true,
	liveSnapshot = {...},
	liveRevision = 12,
	templateId = "...",
}
```

---

# 10. Unified Search Implementation

## Input normalization

```text
trim spaces
uppercase for code lookup
preserve original for username lookup
remove duplicate spaces
```

## Search order

```text
1. Try code lookup.
2. If not found, try Roblox username/userId lookup.
3. If not found, return empty.
```

---

## 10.1 Code Lookup

Accept:

```text
AVT-8K4P2
8K4P2
```

If user enters short code without prefix:

```text
normalize to AVT-8K4P2
```

Pseudo:

```luau
local function normalizeCode(query)
	local q = string.upper(trim(query))
	q = string.gsub(q, "%s+", "")

	if string.match(q, "^AVT%-[%w]+$") then
		return q
	end

	if string.match(q, "^[A-Z2-9]+$") and #q == 5 then
		return "AVT-" .. q
	end

	return q
end
```

If code exists:

```text
return template_code_result
```

---

## 10.2 Username/UserId Fallback

If code lookup returns nil:

```text
if query is numeric:
  treat as userId
else:
  resolve username using Players:GetUserIdFromNameAsync
```

Then:

```text
fetch saved Roblox outfits for that user
```

If user not found or has no outfits:

```text
return empty
```

---

# 11. Roblox Outfit Import

## 11.1 List saved outfits

Input:

```text
userId
```

Output card shape:

```luau
export type RobloxOutfitCardData = {
	sourceType: "roblox_outfit",
	userOutfitId: number,
	name: string,

	ownerUserId: number,
	ownerUsername: string?,

	thumbnailUrl: string?,
	thumbnailState: string,

	canLoad: boolean,
}
```

## 11.2 Load saved outfit

Flow:

```text
user clicks Load on Roblox outfit card
↓
server fetches outfit detail
↓
RobloxOutfitConverter converts detail to HumanoidDescription snapshot
↓
AvatarAppearanceService.applyDescriptionSnapshot(player, snapshot, "roblox_outfit_import")
↓
return LiveSnapshot
```

## 11.3 Database rule

Roblox outfit import does not save to database automatically.

If user wants to save it:

```text
user clicks Save Template after loading/modifying avatar
```

---

# 12. HTTP / Proxy Adapter

Create adapter:

```text
src/server/services/RobloxAvatarApiClient.luau
```

Responsibilities:

```text
fetch user outfits
fetch outfit details
fetch outfit thumbnails if needed
```

Use one abstraction so implementation can be swapped:

```text
direct HttpService call
or backend/proxy call
```

API:

```luau
function RobloxAvatarApiClient.getUserOutfits(userId: number)
function RobloxAvatarApiClient.getOutfitDetails(userOutfitId: number)
function RobloxAvatarApiClient.getOutfitThumbnails(userOutfitIds: { number })
```

If direct Roblox endpoint requests are not available in-game, replace internals with project-owned backend/proxy endpoint.

Do not spread raw HTTP calls throughout Avatar Loader code.

---

# 13. Roblox Outfit Converter

Create:

```text
src/server/services/RobloxOutfitConverter.luau
```

Purpose:

```text
Roblox outfit detail JSON
↓
HumanoidDescription snapshot
```

Output must match:

```text
HumanoidDescriptionSerializer snapshot format
```

Responsibilities:

```text
map assets to HumanoidDescription properties
map body colors
map scales
map avatar type if available
ignore unsupported fields safely
```

If a field is unknown:

```text
log warning
skip field
do not crash
```

---

# 14. Client UI

## 14.1 Avatar Loader default

```text
show recent generated templates
```

Card:

```text
thumbnail placeholder
Template N
creator username
Load button
```

---

## 14.2 Unified search toolbar

Reuse Avatar Loader search area.

Placeholder:

```text
Enter template code or Roblox username/userId
```

Submit button:

```text
Search
```

Search result modes:

```text
template_result
roblox_outfits_result
empty
loading
error
```

---

## 14.3 Code result UI

If code found:

```text
show one template card
```

Button:

```text
Load
```

---

## 14.4 Username/userId result UI

If username/userId found:

```text
show Roblox outfit cards
```

Card:

```text
thumbnail
outfit name
owner username
Load button
```

---

## 14.5 Empty state

If code not found and username/userId not found or no outfits:

```text
Template atau outfit Roblox tidak ditemukan.
```

---

# 15. Caching

## 15.1 Code lookup cache

TTL:

```text
60 seconds
```

Cache not-found briefly:

```text
30 seconds
```

## 15.2 Username to userId cache

TTL:

```text
10 minutes
```

## 15.3 Roblox outfits list cache

TTL:

```text
5 minutes
```

## 15.4 Outfit details cache

TTL:

```text
10 minutes
```

Do not permanently store Roblox outfit data unless user saves template.

---

# 16. Rate Limits & Guards

## Save Template

```text
cooldown per player
max templates per user if implemented
server-side validation
```

## Search

```text
search submit only
minimum query length 2
cooldown 0.7 seconds
request token/stale result guard
```

## Roblox API

```text
cache responses
avoid repeat fetch on same query
limit outfit results per page
handle errors gracefully
```

---

# 17. Remotes

Add or update:

```text
ListAvatarTemplatesRemote
SaveAvatarTemplateRemote
LoadAvatarTemplateRemote
SearchAvatarLoaderRemote
LoadRobloxOutfitRemote
```

## SearchAvatarLoaderRemote

Request:

```luau
{
	query = "AVT-8K4P2" -- or username/userId
}
```

Response for template:

```luau
{
	success = true,
	resultType = "template",
	template = AvatarTemplateCardData,
}
```

Response for Roblox outfits:

```luau
{
	success = true,
	resultType = "roblox_outfits",
	owner = {
		userId = 123,
		username = "SomeUser",
	},
	outfits = { RobloxOutfitCardData },
}
```

Response empty:

```luau
{
	success = true,
	resultType = "empty",
	message = "Template or outfits not found.",
}
```

---

# 18. Sub-Phase Breakdown

Implement in small steps.

```text
13.0 Audit Avatar Loader MVP implementation
13.1 Add DataStore stores/config
13.2 Implement AvatarTemplatePersistenceService
13.3 Persist Save Template to DataStore
13.4 Load templates from DataStore default list
13.5 Add CodeToTemplateId lookup
13.6 Add unified search code-first path
13.7 Add RobloxAvatarApiClient adapter
13.8 Add Roblox username/userId outfit search
13.9 Add RobloxOutfitConverter
13.10 Add LoadRobloxOutfitRemote
13.11 Add caching/rate guards/error states
13.12 Manual test matrix
```

---

# 19. Sub-Phase 13.0 — Audit

Inspect:

```text
AvatarTemplateService mock/in-memory implementation
Avatar Loader UI
Save Template button
Load Template remote
AvatarAppearanceService
HumanoidDescriptionSerializer
existing DataStore utilities
existing search toolbar patterns
```

Acceptance:

```text
Agent knows which mock code will be replaced by DataStore-backed code.
```

---

# 20. Sub-Phase 13.1 — DataStore Stores/Config

Add config:

```text
STORE_TEMPLATE_BY_ID
STORE_CODE_TO_TEMPLATE_ID
ORDERED_STORE_RECENT_TEMPLATES
STORE_USER_TEMPLATE_INDEX
```

Acceptance:

```text
Stores initialize without errors.
Studio mode can use mock fallback if DataStore disabled.
```

---

# 21. Sub-Phase 13.2 — Persistence Service

Implement:

```text
saveTemplate
getTemplate
getTemplateByCode
listRecentTemplates
```

Acceptance:

```text
Service can save and fetch template records.
```

---

# 22. Sub-Phase 13.3 — Persist Save Template

Replace mock save.

Acceptance:

```text
Click Save Template
DataStore record created
code mapping created
recent index updated
response includes code
```

---

# 23. Sub-Phase 13.4 — Default List From DataStore

Replace mock/default list.

Acceptance:

```text
Open Avatar Loader
recent templates from DataStore show as cards
```

---

# 24. Sub-Phase 13.5 — Code Lookup

Implement:

```text
getTemplateByCode
```

Acceptance:

```text
Input AVT-XXXXX finds saved template
Input XXXXX also works if normalized
```

---

# 25. Sub-Phase 13.6 — Unified Search Code-First

Implement search remote code path.

Acceptance:

```text
Search valid code -> shows template result
Search invalid code -> continues to username fallback
```

---

# 26. Sub-Phase 13.7 — RobloxAvatarApiClient Adapter

Add centralized API client.

Acceptance:

```text
No raw Roblox avatar HTTP code outside adapter.
Adapter can be swapped to backend/proxy implementation.
```

---

# 27. Sub-Phase 13.8 — Username/UserId Outfit Search

Implement fallback search.

Acceptance:

```text
Search username -> outfit cards
Search numeric userId -> outfit cards
Unknown user -> empty state
```

---

# 28. Sub-Phase 13.9 — RobloxOutfitConverter

Convert outfit detail response into snapshot.

Acceptance:

```text
Fetch outfit details
Convert to HumanoidDescription snapshot
Snapshot validates
```

---

# 29. Sub-Phase 13.10 — Load Roblox Outfit

Implement:

```text
LoadRobloxOutfitRemote
```

Acceptance:

```text
Click Load on Roblox outfit result
live avatar changes
Viewport/My Avatar sync
Template is not saved automatically
```

---

# 30. Sub-Phase 13.11 — Caching/Error States

Add:

```text
username cache
outfit list cache
outfit details cache
search loading state
empty state
error state
```

Acceptance:

```text
Repeated search is fast
Failed Roblox API call does not crash UI
```

---

# 31. Manual Test Matrix

Do not mark complete until all pass.

## Test 1 — Save template persists

```text
Change avatar
Click Save Template
Expected:
DataStore record saved
code returned
```

## Test 2 — Rejoin/server restart

```text
Save template
Restart server/rejoin
Open Avatar Loader
Expected:
saved template still appears
```

## Test 3 — Load persisted template

```text
Click Load on saved template
Expected:
live avatar changes
Viewport/My Avatar sync
```

## Test 4 — Search code

```text
Search saved code
Expected:
template card appears
Load works
```

## Test 5 — Short code normalization

```text
Search only XXXXX part of AVT-XXXXX
Expected:
template is found
```

## Test 6 — Search username

```text
Search Roblox username
Expected:
Roblox outfit cards appear
```

## Test 7 — Search userId

```text
Search numeric Roblox userId
Expected:
Roblox outfit cards appear
```

## Test 8 — Unknown search

```text
Search invalid code/username
Expected:
empty state
```

## Test 9 — Load Roblox outfit

```text
Search username
Load one outfit
Expected:
live avatar changes
template is not saved automatically
```

## Test 10 — Save imported outfit

```text
Load Roblox outfit
Click Save Template
Expected:
new generated template saved to database
```

## Test 11 — Search cache

```text
Search same username twice
Expected:
second search uses cache if TTL valid
```

## Test 12 — Save cooldown

```text
Click Save repeatedly
Expected:
cooldown prevents spam
```

---

# 32. What Not To Do

Do not:

```text
- Keep template data only in memory.
- Return saved code before persistence succeeds.
- Store Roblox username outfit imports automatically.
- Add category/tags/likes/recommendations in this phase.
- Build separate Load Code UI in this phase.
- Fetch Roblox current avatar by username.
- Scatter raw HTTP calls across services.
- Trust client snapshot for Save Template.
- Apply avatar outside AvatarAppearanceService.
```

---

# 33. Final Acceptance Criteria

Phase 13 is complete only if:

1. Generated templates persist in DataStore.
2. Avatar Loader default list reads from DataStore recent index.
3. Save Template saves server LiveSnapshot.
4. Saved template returns a unique code after persistence succeeds.
5. Code search loads saved template.
6. Search fallback resolves Roblox username/userId.
7. Roblox outfit search displays saved outfits from that user.
8. Roblox outfit Load applies temporarily through AvatarAppearanceService.
9. Imported Roblox outfit is not saved unless user clicks Save Template.
10. Basic caching/rate guard/error states exist.
11. Existing Avatar Loader load/save flow still works.
12. Manual test matrix passes.

---

# 34. Suggested Commit Plan

```text
phase13-0-audit-avatar-loader-persistence
phase13-1-datastore-config
phase13-2-template-persistence-service
phase13-3-save-template-datastore
phase13-4-list-recent-templates-datastore
phase13-5-code-lookup
phase13-6-unified-search-code-first
phase13-7-roblox-avatar-api-client
phase13-8-username-userid-outfit-search
phase13-9-roblox-outfit-converter
phase13-10-load-roblox-outfit
phase13-11-cache-error-states
phase13-12-test-matrix-cleanup
```

---

# 35. Short Instruction for AI Agent

Implement Phase 13.

Persist generated templates using DataStore.

Save Template must save the server LiveSnapshot from AvatarAppearanceService and return a code only after persistence succeeds.

Avatar Loader default list must read generated templates from DataStore.

Unified search behavior:

```text
Search input
↓
try template code first
↓
if not found, fallback to Roblox username/userId outfits
↓
if still not found, empty state
```

Roblox outfit import is temporary. It should only become a database template if the user later clicks Save Template.

Do not add category, tags, likes, recommendations, or a separate load-code UI in this phase.
