# Phase 15 Plan — Avatar Loader My Template / All Template

Goal: add simple template ownership filtering and basic share-code action.

---

## 1. Add Avatar Loader Categories

Add two categories in Avatar Loader:

```text
All Template
My Template
```

Behavior:

```text
All Template
= show all generated templates from database / recent index

My Template
= show only templates created by the current player
```

Implementation:

```text
- Add selectedTemplateCategory state.
- Default can stay All Template.
- When user selects My Template, call server to list templates by creatorUserId == player.UserId.
- Reuse the same card UI for both categories.
```

Server requirement:

```text
ListAvatarTemplatesRemote should accept mode:
  "all"
  "mine"
```

Example request:

```luau
{
	mode = "mine",
	limit = 30,
	cursor = nil,
}
```

---

## 2. Save Template Only In My Template

Change Save Template behavior:

```text
Save Template button only works/appears when selected category is My Template.
```

Recommended UI behavior:

```text
If category = My Template:
  show Save Template button

If category = All Template:
  hide Save Template button
```

When save succeeds:

```text
1. Save current server LiveSnapshot as template.
2. Add template to current player's template index.
3. Refresh My Template list automatically.
4. Keep selected category as My Template.
```

Important:

```text
Do not save client snapshot.
Save must still use AvatarAppearanceService.LiveSnapshot on the server.
```

---

## 3. Add Share Template Button

Each template card should have:

```text
Load
Share Template
```

For now, Share Template only prints the code.

Temporary behavior:

```luau
print("[AvatarLoader] Share Template Code:", template.code)
```

Future behavior:

```text
Open popup/modal with input text containing the template code.
User copies manually from the input.
```

No clipboard support is required in this phase.

---

## 4. Card UI

Template card should show:

```text
thumbnail
template name
creator username
Load button
Share Template button
```

For My Template cards:

```text
Share Template button should use that template's generated code.
```

For All Template cards:

```text
Share Template button can also be shown because every template has a code.
```

---

## 5. Server Changes

Ensure saved template updates:

```text
TemplateById
CodeToTemplateId
RecentTemplateIndex
UserTemplateIndex:{creatorUserId}
```

For `mode = "mine"`:

```text
read UserTemplateIndex:{player.UserId}
fetch template records
return cards
```

For `mode = "all"`:

```text
read RecentTemplateIndex
fetch template records
return cards
```

---

## 6. Manual Test

### Test 1 — Category switch

```text
Open Avatar Loader
Click All Template
Expected: all templates appear

Click My Template
Expected: only current player's templates appear
```

### Test 2 — Save visibility

```text
In All Template
Expected: Save Template button hidden

In My Template
Expected: Save Template button visible
```

### Test 3 — Save refresh

```text
Go to My Template
Click Save Template
Expected:
new template saved
My Template list refreshes
new card appears
```

### Test 4 — Share Template

```text
Click Share Template
Expected:
template code is printed
```

### Test 5 — Load still works

```text
Click Load from All Template or My Template
Expected:
template applies to live character
Viewport/My Avatar sync
```

---

## 7. Final Acceptance Criteria

Complete when:

```text
1. Avatar Loader has All Template and My Template categories.
2. My Template only shows templates created by current player.
3. Save Template is only available in My Template.
4. Save Template refreshes My Template after success.
5. Template cards have Share Template button.
6. Share Template prints the template code for now.
7. Existing Load behavior still works.
```
