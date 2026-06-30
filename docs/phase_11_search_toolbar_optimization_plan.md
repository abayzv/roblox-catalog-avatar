# Phase 11 Technical Plan — Search Toolbar Optimization

Project: `abayzv/roblox-catalog-avatar`  
Baseline: Phase 10 Emote/Animation Loading Optimization completed  
Goal: optimize catalog search so it does **not request on every input change**, and repurpose the existing `SearchToolbar` filter button into a Search button.

---

## 0. Problem Summary

Current behavior:

```text
User types in search input
↓
onChange fires
↓
catalog request happens for every typed character
```

This can cause:

```text
too many requests
slow catalog
throttling
stale results
card skeleton stuck
bad live-server performance
```

Search should be intentional.

New behavior:

```text
User types keyword
↓
no request yet
↓
User clicks Search button or presses Enter
↓
catalog request starts
```

---

## 1. Core Decision

Use the existing component:

```text
SearchToolbar
```

Repurpose the current filter button into:

```text
Search button
```

If filter functionality is still needed later, it should become a separate future feature.

For now:

```text
Filter button icon/action -> Search submit
```

---

## 2. New UX Rules

### Rule 1 — Typing does not request

`onChange` should only update local input state.

```text
onChange = update searchInput only
```

Do not call:

```text
SearchCatalogAsync
loadCatalog
fetchPage
warmupQueue
```

inside `onChange`.

### Rule 2 — Search request only happens on submit

Submit triggers:

```text
Search button click
Enter key
```

Optional:

```text
Clear button resets search
```

### Rule 3 — Search button uses debounce/cooldown

Even with button submit, add cooldown to avoid spam clicking.

Recommended:

```text
SEARCH_SUBMIT_COOLDOWN = 0.5 - 0.8 seconds
```

Use `0.7 seconds` as default.

### Rule 4 — Use request token

If the user submits a new search while the previous request is still running:

```text
old response must be ignored
```

Use:

```text
searchRequestId
```

or existing request token system.

### Rule 5 — Search cache

If same query/category is searched again:

```text
use cached result
or avoid duplicate request
```

Cache key should include:

```text
main category
subcategory
search query
sort/filter if any
page index/cursor
```

### Rule 6 — Minimum query length

Recommended:

```text
MIN_SEARCH_LENGTH = 2
```

Behavior:

```text
empty query = browse category normally
1 character = do not search, show warning/print for now
2+ characters = valid search
```

### Rule 7 — Search result pagination should be limited

Search mode should have smaller max pages than browse mode.

Recommended:

```text
BROWSE_MAX_PAGES = 3
SEARCH_MAX_PAGES = 2
PAGE_LIMIT = 30
```

If user wants a specific item, they should refine keyword.

---

# 3. State Model

Separate these two states:

```luau
local searchInput = ""
local submittedQuery = ""
```

Meaning:

```text
searchInput
= what user is typing right now

submittedQuery
= query currently used by catalog result
```

Request should only happen when:

```text
submittedQuery changes through submit
```

not when:

```text
searchInput changes
```

---

# 4. SearchToolbar Behavior

## 4.1 Input onChange

New behavior:

```luau
onSearchInputChanged(newText)
	searchInput = newText
	-- no request
end
```

Allowed UI updates:

```text
show dirty state
enable Search button
show "Press Enter to search" hint
```

Not allowed:

```text
fetch catalog
clear current results immediately
warmup items
reset infinite scroll
```

## 4.2 Search button

Current filter button should become:

```text
Search
```

Recommended button states:

```text
Search
Searching...
Disabled
```

Button disabled when:

```text
isSearching == true
query invalid
cooldown active
```

Button action:

```text
submitSearch()
```

## 4.3 Enter key

When input is focused and user presses Enter:

```text
submitSearch()
```

Same path as Search button.

Do not duplicate logic.

## 4.4 Clear button

If `SearchToolbar` already has a clear button, use it.

If not, optional.

Behavior:

```text
searchInput = ""
submittedQuery = ""
reset page cursor
load default category browse result
```

---

# 5. Submit Search Flow

Pseudo-code:

```luau
local SEARCH_SUBMIT_COOLDOWN = 0.7
local MIN_SEARCH_LENGTH = 2

local searchInput = ""
local submittedQuery = ""
local lastSearchSubmitAt = 0
local searchRequestId = 0
local isSearching = false

local function normalizeQuery(value)
	value = tostring(value or "")

	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")
	value = string.gsub(value, "%s+", " ")

	return value
end

local function submitSearch()
	local now = os.clock()

	if now - lastSearchSubmitAt < SEARCH_SUBMIT_COOLDOWN then
		return
	end

	lastSearchSubmitAt = now

	local query = normalizeQuery(searchInput)

	if query ~= "" and #query < MIN_SEARCH_LENGTH then
		warn("[Search] Query minimal 2 karakter")
		return
	end

	if query == submittedQuery then
		return
	end

	submittedQuery = query

	searchRequestId += 1
	local requestId = searchRequestId

	isSearching = true
	showSearchSkeleton()

	task.spawn(function()
		local ok, result = pcall(function()
			return CatalogService.fetchFirstPage({
				categoryId = selectedCategoryId,
				subCategoryId = selectedSubCategoryId,
				searchKeyword = submittedQuery,
			})
		end)

		if requestId ~= searchRequestId then
			return
		end

		isSearching = false

		if not ok then
			showSearchError(result)
			return
		end

		setCatalogItems(result.items)
		setNextCursor(result.nextCursor)
		resetScrollState()
	end)
end
```

---

# 6. CatalogService Requirements

CatalogService should accept:

```luau
{
	categoryId = string,
	subCategoryId = string,
	searchKeyword = string?,
	cursor = any?,
	pageIndex = number?,
}
```

When `searchKeyword` is empty:

```text
browse mode
```

When `searchKeyword` is non-empty:

```text
search mode
```

## 6.1 Search cache key

Example:

```luau
local function makeCatalogCacheKey(params)
	return table.concat({
		params.categoryId or "none",
		params.subCategoryId or "none",
		params.searchKeyword or "",
		params.sortType or "default",
		tostring(params.pageIndex or 1),
	}, "|")
end
```

## 6.2 Cache behavior

```text
before request:
  check cache

after request:
  save result to cache
```

Do not cache failed responses unless intentionally adding short error TTL.

---

# 7. Infinite Scroll Behavior With Search

## Browse mode

```text
PAGE_LIMIT = 30
MAX_PAGES = 3
```

## Search mode

```text
PAGE_LIMIT = 30
MAX_PAGES = 2
```

When max pages reached in search mode:

```text
show message:
"Coba kata kunci yang lebih spesifik untuk hasil lainnya."
```

## Scroll guard

Load next page only if:

```text
not isLoadingNextPage
not isSearching
not reachedMaxPages
hasNextCursor
scroll near bottom
scroll debounce passed
```

Recommended scroll debounce:

```text
0.5 - 0.75 seconds
```

---

# 8. Category Change Behavior

Choose one policy after inspecting current UX.

## Policy A — Keep input, require submit again

Behavior:

```text
User searched "black"
Switch category
Input still says "black"
Results load category default, or Search button becomes available for the new category
```

This avoids surprise requests.

## Policy B — Search follows category

Behavior:

```text
User searched "black"
Switch category
Automatically search "black" in new category
```

This is more aggressive but may feel convenient.

## Recommended for this project

Use Policy A unless current UI clearly expects search to persist across category changes.

If Policy B is used, it must still use:

```text
request token
cache
pagination limit
loading lock
```

---

# 9. SearchToolbar UI Copy

Filter button becomes:

```text
Search
```

If only icon button is used:

```text
magnifying glass icon
```

Tooltip:

```text
Search
```

Loading label:

```text
Searching...
```

Invalid query warning:

```text
Masukkan minimal 2 karakter.
```

Empty result:

```text
Tidak ada item ditemukan.
```

Search hint optional:

```text
Tekan Enter atau tombol Search untuk mencari.
```

---

# 10. Sub-Phase Breakdown

Do not implement all at once.

Use this order:

```text
11.0 Audit current SearchToolbar and catalog search flow
11.1 Split searchInput and submittedQuery state
11.2 Remove request from onChange
11.3 Repurpose filter button into Search submit
11.4 Add Enter key submit
11.5 Add submit debounce/cooldown
11.6 Add request token/stale result guard
11.7 Add search cache
11.8 Adjust infinite scroll max pages for search
11.9 Add clear/search empty/error states
11.10 Manual test matrix
```

---

# 11. Sub-Phase 11.0 — Audit

Inspect:

```text
SearchToolbar component
Catalog page/container
CatalogService
useCatalogItems hook
infinite scroll handler
category/subcategory selector
warmup queue caller
```

Find:

```text
where onChange triggers request
where filter button is wired
where search query state is stored
where page/cursor resets
where request token exists or should be added
```

Acceptance:

```text
Agent can explain the current request flow before refactor.
```

---

# 12. Sub-Phase 11.1 — Split Search State

Add:

```text
searchInput
submittedQuery
```

Acceptance:

```text
Typing changes searchInput only.
Catalog result still uses submittedQuery.
```

---

# 13. Sub-Phase 11.2 — Remove Request From onChange

Update SearchToolbar/onChange.

Acceptance:

```text
Typing does not call CatalogService.
Typing does not reset item grid.
Typing does not start warmup queue.
```

---

# 14. Sub-Phase 11.3 — Filter Button Becomes Search Button

Repurpose existing filter button.

Acceptance:

```text
Clicking button triggers submitSearch.
Button visual/label represents Search.
Old filter action is removed or disabled.
```

---

# 15. Sub-Phase 11.4 — Enter Key Submit

Add Enter key handler.

Acceptance:

```text
Typing query and pressing Enter triggers same submitSearch path as button.
```

---

# 16. Sub-Phase 11.5 — Submit Debounce/Cooldown

Add cooldown:

```text
0.7 seconds
```

Acceptance:

```text
Spam clicking Search does not spam requests.
```

---

# 17. Sub-Phase 11.6 — Request Token Guard

Add `searchRequestId` or reuse existing request token.

Acceptance:

```text
Search "black"
Immediately search "red"
If black result returns last, it is ignored.
UI shows red result only.
```

---

# 18. Sub-Phase 11.7 — Search Cache

Add cache by:

```text
category
subcategory
query
sort
page
```

Acceptance:

```text
Search same query/category twice
Second search uses cache or avoids duplicate request.
```

---

# 19. Sub-Phase 11.8 — Search Infinite Scroll Limits

Set:

```text
MAX_PAGES_SEARCH = 2
MAX_PAGES_BROWSE = existing value, recommended 3
```

Acceptance:

```text
Search result does not infinitely request pages.
Max reached message appears or loading stops cleanly.
```

---

# 20. Sub-Phase 11.9 — UI States

Add/verify:

```text
Searching...
Invalid query
No results
Clear search
```

Acceptance:

```text
Invalid 1-character query does not request.
Empty results show friendly message.
Clear search returns to default category.
```

---

# 21. Manual Test Matrix

Do not mark complete until all pass.

## Test 1 — Typing does not request

```text
Type "black hair"
Expected:
no CatalogService request until Search/Enter
```

## Test 2 — Search button

```text
Type "black hair"
Click Search
Expected:
one request
skeleton appears
results show
```

## Test 3 — Enter key

```text
Type "red jacket"
Press Enter
Expected:
same behavior as Search button
```

## Test 4 — Spam click

```text
Click Search 5 times quickly
Expected:
only one request or cooldown-limited requests
```

## Test 5 — Short query

```text
Type "a"
Click Search
Expected:
no request
warning minimal 2 characters
```

## Test 6 — Clear search

```text
Search "black"
Clear input
Expected:
default category browse result loads
```

## Test 7 — Stale response

```text
Search "black"
Immediately search "red"
Expected:
red result stays
black result ignored if it returns later
```

## Test 8 — Search cache

```text
Search "black"
Switch away and back or search "black" again
Expected:
cache used when possible
no unnecessary duplicate request
```

## Test 9 — Search pagination

```text
Search "black"
Scroll down
Expected:
loads next page with debounce
stops at MAX_PAGES_SEARCH
```

## Test 10 — Existing browse unaffected

```text
Clear search
Browse category
Expected:
normal infinite scroll behavior still works
```

---

# 22. What Not To Do

Do not:

```text
- Request on every onChange.
- Debounce auto-search as the main search mechanism.
- Fire search request from both onChange and button.
- Let stale search results overwrite newer results.
- Reset catalog grid on every typed character.
- Remove existing skeleton/loading UX.
- Break infinite scroll for browse mode.
- Re-enable old filter behavior unless explicitly requested.
```

---

# 23. Final Acceptance Criteria

Phase 11 is complete only if:

1. Typing in SearchToolbar does not request catalog.
2. Existing filter button is now Search button.
3. Pressing Enter triggers search.
4. Search submit has debounce/cooldown.
5. Minimum query length is enforced.
6. Stale response guard exists.
7. Search cache exists or duplicate request prevention exists.
8. Search pagination is limited.
9. Clear search returns to default category browsing.
10. Existing category browsing still works.
11. Manual test matrix passes.

---

# 24. Suggested Commit Plan

```text
phase11-0-audit-search-flow
phase11-1-split-search-input-submitted-query
phase11-2-remove-onchange-request
phase11-3-filter-button-to-search-button
phase11-4-enter-key-submit
phase11-5-submit-cooldown
phase11-6-request-token-guard
phase11-7-search-cache
phase11-8-search-pagination-limits
phase11-9-ui-states
phase11-10-test-matrix-cleanup
```

---

# 25. Short Instruction for AI Agent

Optimize SearchToolbar.

Current problem:

```text
onChange requests on every typed character.
```

New behavior:

```text
onChange updates searchInput only.
Search button / Enter submits search.
```

Use the existing filter button as the Search button.

Add:

```text
submit cooldown
minimum query length
request token guard
search cache
search pagination limit
clear search behavior
```

Do not break normal category browsing or infinite scroll.
