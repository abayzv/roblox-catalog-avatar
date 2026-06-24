# Implementation Plan: Server-Authoritative Desired Outfit State

Plan ini mengganti pendekatan lama `addedIds/removedIds` dari client menjadi **desired final state** yang divalidasi dan diterapkan server. Tujuannya:

- Item yang sudah di-apply bisa di-remove.
- Outfit/accessory yang sudah dipakai player saat join game juga bisa di-remove.
- Tidak ada duplicate accessory/clothing.
- Client tidak menjadi source of truth untuk live character.
- Viewport tetap client-only, server apply tetap server-authoritative.

## Core Decision

Client boleh menyimpan state UI:

- `appliedItems`: snapshot outfit terakhir yang disetujui server.
- `previewItems`: state outfit yang sedang dipreview di `ViewportFrame`.
- `isDirty`: hasil compare `previewItems` vs `appliedItems`.

Tapi server tetap source of truth untuk outfit live character.

Saat user klik `Apply`, client **tidak mengirim delta** seperti `addedIds` dan `removedIds`. Client mengirim **desired final item ids** dari `previewItems`.

Server yang bertugas:

1. membaca current/cached server state,
2. validasi desired ids,
3. membangun `HumanoidDescription` final,
4. apply ke live character,
5. cache state terbaru,
6. mengembalikan snapshot terbaru ke client.

## Why Not Client Delta

Delta payload:

```lua
{
	addedIds = { ... },
	removedIds = { ... },
}
```

terlihat simpel, tapi rawan desync:

- `appliedItems` client bisa stale.
- Client bisa mengirim removed id yang tidak pernah server anggap equipped.
- Retry request bisa menghasilkan hasil berbeda jika delta diproses dua kali.
- Outfit bawaan saat join sulit direpresentasikan kalau client tidak punya snapshot server yang benar.

Desired state lebih idempotent:

```lua
{
	itemIds = { 128159229, 123456789, ... }
}
```

Jika request yang sama dikirim ulang, hasil final tetap sama.

## Data Model

### Client `CatalogItem`

```lua
export type CatalogItem = {
	id: string,
	name: string,
	price: number | string,
	image: string,
	assetId: number?,
}
```

### Client State

```lua
type PreviewState = {
	appliedItems: { [string]: CatalogItem },
	previewItems: { [string]: CatalogItem },
	isDirty: boolean,
}
```

Rules:

- `appliedItems` adalah snapshot terakhir dari server.
- `previewItems` adalah state yang sedang dilihat di viewport.
- Saat catalog dibuka pertama kali, `previewItems = copy(appliedItems)`.
- `Try On` menambah item ke `previewItems`.
- `Remove` menghapus item dari `previewItems`.
- `Apply` aktif hanya jika `isDirty == true`.
- Setelah apply sukses, client mengganti `appliedItems` dengan snapshot dari server.

### Server Equipped State

Server menyimpan state per player:

```lua
type EquippedState = {
	itemIds: { number },
	description: HumanoidDescription,
}
```

`itemIds` adalah supported wearable asset ids yang sedang dianggap equipped oleh sistem catalog.

`description` adalah `HumanoidDescription` final yang akan dipakai ulang saat respawn.

## Initial Outfit Sync

Saat player join atau character load:

1. Ambil `HumanoidDescription` aktif.
2. Parse field yang didukung dari `CatalogConfig.AssetTypeToProperty`.
3. Ambil semua asset id dari:
   - CSV accessory properties, contoh `HatAccessory`, `HairAccessory`, `BackAccessory`.
   - number clothing properties, contoh `Shirt`, `Pants`, `GraphicTShirt`.
4. Simpan sebagai server `EquippedState`.
5. Kirim snapshot ke client saat client meminta initial applied state.

Ini penting supaya item yang sudah dipakai player sebelum masuk game bisa muncul sebagai applied/previewed item, lalu bisa di-remove.

## Remote Contract

Gunakan remote apply sebagai request desired final state.

### Request

```lua
{
	itemIds = { number },
}
```

Notes:

- `itemIds` adalah desired final wearable ids.
- Tidak ada `addedIds`.
- Tidak ada `removedIds`.
- Client tidak mengirim `HumanoidDescription`.
- Client tidak mengirim instance/accessory.

### Success Response

```lua
{
	success = true,
	message = string,
	equippedItemIds = { number },
}
```

Client action setelah success:

1. Convert `equippedItemIds` ke `appliedItems`.
2. Set `previewItems = copy(appliedItems)`.
3. `isDirty = false`.

### Error Response

```lua
{
	success = false,
	message = string,
}
```

Client action setelah error:

- Jangan update `appliedItems`.
- Biarkan `previewItems` tetap seperti user pilih.
- Tampilkan feedback error nanti saat UI toast tersedia.

## Server Apply Algorithm

Pseudo flow:

```lua
ApplyAvatarRemote.OnServerInvoke = function(player, payload)
	validatePayloadShape(payload)

	local desiredIds = normalizeAndDedupe(payload.itemIds)
	enforceMaxItems(desiredIds)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return errorResponse("Character not ready")
	end

	local baseDescription = getBaseDescriptionForPlayer(player, humanoid)
	local finalDescription = buildDescriptionFromDesiredIds(player, baseDescription, desiredIds)

	humanoid:ApplyDescription(finalDescription)

	local equippedIds = extractSupportedIds(finalDescription)
	cache[player.UserId] = {
		itemIds = equippedIds,
		description = finalDescription,
	}

	return {
		success = true,
		message = "Outfit applied",
		equippedItemIds = equippedIds,
	}
end
```

## Building Final HumanoidDescription

Server harus membangun final description dari desired ids, bukan hanya menambahkan ke current description.

Recommended:

1. Start dari base description yang aman.
2. Clear all supported catalog fields.
3. Untuk setiap desired id:
   - `MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)`.
   - Ambil `AssetTypeId`.
   - Map ke property via `CatalogConfig.AssetTypeToProperty`.
   - Validasi property supported.
   - Validasi ownership jika `RequireOwnership == true`.
   - Tambahkan ke property yang sesuai.
4. Apply final description.

Kenapa clear supported fields dulu:

- Remove jadi natural. Jika item tidak ada di desired ids, field-nya tidak akan ditambahkan lagi.
- Initial outfit item bisa dihapus.
- Duplicate lebih mudah dicegah.

Important:

- Clear hanya field yang sistem catalog dukung.
- Jangan reset body scale/body color/face/animation yang belum didukung kalau tidak masuk scope.
- Untuk CSV accessory property: build CSV dari desired ids.
- Untuk number property: set asset id atau `0` jika tidak ada desired id untuk field itu.

## Supported Field Helpers

Butuh helper di server:

```lua
local function splitCsv(csv: string?): { string }
	-- trim, ignore "", ignore "0"
end

local function joinCsv(ids: { number }): string
	-- dedupe then table.concat
end

local function clearSupportedFields(description: HumanoidDescription)
	for _, propertyName in pairs(CatalogConfig.AssetTypeToProperty) do
		local current = description[propertyName]
		if type(current) == "string" then
			description[propertyName] = ""
		elseif type(current) == "number" then
			description[propertyName] = 0
		end
	end
end
```

## Client Flow

### Catalog Open

```text
Open Catalog
-> request server equipped snapshot
-> appliedItems = snapshot
-> previewItems = copy(appliedItems)
-> render viewport from previewItems
```

### Try On

```text
Click Try On
-> add item to previewItems
-> viewport rebuilds/applies preview
-> isDirty updates
-> no remote call
```

### Remove

```text
Click Remove
-> remove item from previewItems
-> viewport rebuilds/applies preview
-> isDirty updates
-> no remote call
```

### Apply

```text
Click Apply
-> client sends desired itemIds from previewItems
-> server validates/builds/applies final HumanoidDescription
-> server returns equippedItemIds
-> client sets appliedItems and previewItems from server response
```

## Viewport Behavior

Viewport remains client-only.

Rules:

- Source of truth is `previewItems`.
- Do not mutate live character in Try On.
- Do not fire remote in Try On/Remove.
- Rebuild or refresh viewport clone whenever `previewItems` changes.

Roblox caveat:

`Humanoid:ApplyDescription()` on a viewport clone can fail to visually remove some objects in certain cases. Prefer full viewport clone rebuild from the desired description when preview changes. Manual cleanup is acceptable as fallback, but source of truth must remain `previewItems`.

## Respawn Behavior

Server cache should persist applied outfit across respawn:

```text
CharacterAdded
-> wait Humanoid
-> if cached description exists:
   -> ApplyDescription(cached description)
-> else:
   -> parse current Roblox outfit as initial equipped state
```

Important:

- If player applied an empty desired state, cache should represent empty supported catalog fields.
- Do not accidentally fall back to original outfit after player intentionally removed supported items.

## Acceptance Criteria

- Player can apply catalog item and other players see it.
- Player can remove item that was applied through catalog.
- Player can remove supported item that was already worn when joining.
- Re-applying same desired state does not duplicate accessories.
- Respawn keeps the last server-applied desired state.
- Try On/Remove never mutates live character and never fires remote.
- Server validates all ids before applying.
- Server returns latest equipped snapshot after successful apply.

## Issues Impacted

- Issue 4.4 - Reset Preview:
  - Reset should restore `previewItems` to `appliedItems`, not necessarily empty.
- Issue 5.1 - Apply Button UI:
  - Apply active only when `previewItems` differs from server snapshot `appliedItems`.
- Issue 5.2 - Remote Contract:
  - Contract should be desired final state, not delta.
- Issue 5.3 - Server Validation:
  - Server validates every desired id and owns final state computation.
- Issue 5.4 - Server Appearance Apply:
  - Server clears supported fields then rebuilds final `HumanoidDescription`.
- Issue 9.2 - Character Preview Robustness:
  - Test join outfit, remove join outfit, respawn after empty desired state, and duplicate prevention.

## Implementation Order

1. Add server helpers for parsing and clearing supported `HumanoidDescription` fields.
2. Add server equipped state extraction from current description.
3. Update remote payload to `{ itemIds = { ... } }`.
4. Update server apply to rebuild final description from desired ids.
5. Return `equippedItemIds` on success.
6. Update `PreviewState` to support `appliedItems`, `previewItems`, `isDirty`, and server snapshot hydration.
7. Update UI buttons so `Remove` removes from preview state, including initially equipped items.
8. Update viewport refresh to rebuild from `previewItems`.
9. Test apply, remove, initial outfit remove, respawn, duplicate prevention.
