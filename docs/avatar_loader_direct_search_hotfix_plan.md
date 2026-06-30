# Phase 13 Hotfix — Direct Avatar Loader Search

Goal: simplify Avatar Loader search because fetching Roblox saved outfit lists is too heavy and often rate-limited.

---

## 1. New Search Behavior

Search input now accepts:

```text
template code
or
Roblox username / userId
or
template name
```

Search button behavior:

```text
1. Check if input is a template code.
2. If code exists, immediately load that saved template.
3. If code does not exist, try resolving input as Roblox username/userId.
4. If username/userId exists, immediately load that user's current avatar.
5. If username/userId does not exist, search database template name.
6. If template name found, show matching template cards.
7. If nothing found, show empty state.
```

Important:

```text
Do not fetch Roblox saved outfit list in this phase.
Do not call Roblox outfit list/detail endpoints.
```

---

## 2. Why This Change

Roblox saved outfit import is too slow/heavy for current MVP.

New MVP focuses on fast actions:

```text
code -> load template directly
username/userId -> load current avatar directly
template name -> show database template cards
```

---

## 3. Search Priority

Final priority order:

```text
Code
↓
Roblox username/userId current avatar
↓
Template name
↓
Empty state
```

---

## 4. Code Search

Accept examples:

```text
AVT-8K4P2
8K4P2
```

Flow:

```text
normalize input
lookup CodeToTemplateId
if found:
  fetch template
  apply template through AvatarAppearanceService
  return success
if not found:
  continue to username/userId fallback
```

Result behavior:

```text
Code found = direct load.
No card needed.
```

---

## 5. Username / UserId Search

If code is not found:

```text
if input is numeric:
  treat as userId
else:
  use Players:GetUserIdFromNameAsync(username)
```

Then:

```text
Players:GetHumanoidDescriptionFromUserIdAsync(userId)
↓
serialize HumanoidDescription
↓
AvatarAppearanceService.applyDescriptionSnapshot(player, snapshot, "avatar_loader_username")
↓
return LiveSnapshot
```

Important:

```text
Use pcall.
Cache username -> userId.
Cache userId -> snapshot for short TTL if needed.
```

Result behavior:

```text
Username/userId found = direct load current avatar.
No outfit card list.
```

---

## 6. Template Name Search

Only run this if:

```text
code not found
and
username/userId lookup failed
```

Flow:

```text
search generated templates in database by name
return matching template cards
```

For MVP with dummy names:

```text
Template 1
Template 2
Template 3
```

This can be simple string contains / prefix match depending on current database/index.

Result behavior:

```text
Template name found = show cards with Load button.
```

---

## 7. Loading State

Because search can now run multiple steps, show a centered spinner in the grid/card area.

States:

```text
idle
searching
loading_avatar
showing_template_results
empty
error
```

UI behavior:

```text
When searching:
  clear old grid or dim it
  show centered spinner in grid container

When direct load succeeds:
  hydrate LiveSnapshot
  sync ViewportFrame
  sync My Avatar

When no result:
  show empty state
```

Suggested empty text:

```text
Template atau username tidak ditemukan.
```

---

## 8. Search Remote

Use one remote/action:

```text
SearchAvatarLoaderRemote
```

Request:

```luau
{
	query = "AVT-8K4P2"
}
```

Possible responses:

### Direct template load

```luau
{
	success = true,
	resultType = "loaded_template_code",
	liveSnapshot = {...},
	liveRevision = 12,
}
```

### Direct username avatar load

```luau
{
	success = true,
	resultType = "loaded_username_avatar",
	liveSnapshot = {...},
	liveRevision = 13,
	resolvedUserId = 123456,
	resolvedUsername = "SomeUser",
}
```

### Template name results

```luau
{
	success = true,
	resultType = "template_results",
	templates = {...},
}
```

### Empty

```luau
{
	success = true,
	resultType = "empty",
	message = "Template atau username tidak ditemukan.",
}
```

### Error

```luau
{
	success = false,
	code = "SEARCH_FAILED",
	message = "Gagal mencari avatar.",
}
```

---

## 9. Client Handling

Pseudo-flow:

```luau
function submitAvatarLoaderSearch(query)
	setState("searching")
	showGridSpinner()

	local response = SearchAvatarLoaderRemote:InvokeServer({
		query = query,
	})

	if response.success and response.resultType == "loaded_template_code" then
		AvatarAppearanceClient.hydrate(response.liveSnapshot, response.liveRevision)
		setState("idle")
		return
	end

	if response.success and response.resultType == "loaded_username_avatar" then
		AvatarAppearanceClient.hydrate(response.liveSnapshot, response.liveRevision)
		setState("idle")
		return
	end

	if response.success and response.resultType == "template_results" then
		setTemplateCards(response.templates)
		setState("showing_template_results")
		return
	end

	if response.success and response.resultType == "empty" then
		setState("empty")
		return
	end

	setState("error")
end
```

---

## 10. Server Search Flow

Pseudo-flow:

```luau
function searchAvatarLoader(player, query)
	local normalized = normalizeQuery(query)

	-- 1. Code lookup
	local template = AvatarTemplatePersistenceService.getTemplateByCode(normalized)

	if template then
		return AvatarTemplateLoader.loadTemplateRecord(player, template, "avatar_loader_code")
	end

	-- 2. Username / userId direct avatar load
	local okUser, userId, username = RobloxUserResolver.resolve(normalized)

	if okUser then
		local okDesc, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
		end)

		if okDesc and description then
			local snapshot = HumanoidDescriptionSerializer.serialize(description)

			local applyResult = AvatarAppearanceService.applyDescriptionSnapshot(
				player,
				snapshot,
				"avatar_loader_username"
			)

			return {
				success = true,
				resultType = "loaded_username_avatar",
				liveSnapshot = applyResult.liveSnapshot,
				liveRevision = applyResult.liveRevision,
				resolvedUserId = userId,
				resolvedUsername = username,
			}
		end
	end

	-- 3. Template name fallback
	local templates = AvatarTemplatePersistenceService.searchTemplatesByName(normalized)

	if #templates > 0 then
		return {
			success = true,
			resultType = "template_results",
			templates = templates,
		}
	end

	-- 4. Empty
	return {
		success = true,
		resultType = "empty",
		message = "Template atau username tidak ditemukan.",
	}
end
```

---

## 11. Rate Guards

Add:

```text
search submit cooldown
request token on client
server cooldown per player
username/userId cache
```

Recommended:

```text
client cooldown: 0.7s
server cooldown: 1.0s
username cache TTL: 10 minutes
avatar snapshot cache TTL: 2–5 minutes
```

---

## 12. What To Remove / Disable

Disable from current plan:

```text
Roblox saved outfit list fetch
Roblox outfit detail fetch
Roblox outfit cards
LoadRobloxOutfitRemote
RobloxOutfitConverter
```

Keep these for future only if already partially implemented, but do not use in the current flow.

---

## 13. Manual Test Matrix

### Test 1 — Search valid code

```text
Input saved code
Click Search
Expected:
template loads immediately
live character changes
viewport syncs
```

### Test 2 — Search short code

```text
Input only code body, for example 8K4P2
Click Search
Expected:
normalizes to AVT-8K4P2 and loads if found
```

### Test 3 — Search username

```text
Input valid Roblox username
Click Search
Expected:
current avatar of that username loads immediately
```

### Test 4 — Search userId

```text
Input numeric userId
Click Search
Expected:
current avatar of that userId loads immediately
```

### Test 5 — Template name fallback

```text
Input Template 1
If no code/user matched
Expected:
template card result appears
```

### Test 6 — Empty state

```text
Input invalid code/username/template name
Expected:
empty state appears
```

### Test 7 — Spinner

```text
Search slow username
Expected:
center spinner appears in grid while processing
```

### Test 8 — Existing template card load

```text
Search template name
Click Load card
Expected:
template loads normally
```

---

## 14. Final Acceptance Criteria

Phase is complete only if:

```text
1. Search button no longer fetches Roblox saved outfit list.
2. Code search directly loads template.
3. Username/userId search directly loads current Roblox avatar.
4. Template name search is fallback only.
5. Empty state appears if all sources fail.
6. Grid shows centered spinner while searching/loading.
7. LiveSnapshot, ViewportFrame, and My Avatar sync after direct load.
```
