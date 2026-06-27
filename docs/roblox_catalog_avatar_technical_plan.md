# Dokumen Teknis Implementasi: Roblox Catalog Avatar Try-On

**Project:** `abayzv/roblox-catalog-avatar`  
**Commit acuan:** `0505d1b4ddcdb78a824174636af1978725836f6d`  
**Tanggal dokumen:** 25 Juni 2026  
**Target pembaca:** AI coding agent / developer Roblox Luau  
**Tujuan:** Membagi pekerjaan refactor catalog avatar menjadi beberapa phase kecil agar tidak dikerjakan sekaligus.

---

## 0. Ringkasan keputusan final

Fitur ini **bukan checkout** dan **bukan pembelian item**. Tujuan utama sekarang adalah membuat user bisa mencoba item catalog Roblox di dalam game dengan smooth.

Flow target:

```text
User buka category
-> tampilkan skeleton 30 slot
-> fetch 30 catalog metadata
-> warmup / resolve preview payload di background
-> card item baru muncul kalau preview payload sudah ready
-> user klik card
-> ViewportFrame preview langsung berubah tanpa fetch ulang
-> user klik Apply
-> server apply temporary outfit ke live character agar terlihat player lain
```

Prinsip utama:

```text
Visible card = preview ready.
Click card = no fetch, no parse, no delay.
Preview client = source of truth untuk UX.
Server = executor untuk live character.
Apply ke karakter asli = temporary in-game outfit, bukan purchase.
```

---

## 1. Scope dan non-scope

### In scope sekarang

- Catalog item loading per category/search dengan infinite scroll.
- Skeleton grid sebelum item siap.
- Background warmup untuk data preview.
- Preview payload resolver untuk asset, bundle, animation package, dan emote jika sudah masuk kategori.
- ViewportFrame clone karakter lokal.
- Click item ready langsung update preview.
- Apply temporary outfit ke karakter asli lewat server.
- Server-side minimal protection: rate limit, payload limit, shape check, cache/resolver, dan `AssetTypeVerification.Always`.
- Respawn reapply temporary outfit selama session.

### Explicitly out of scope sekarang

Jangan implement hal-hal ini dulu:

- Purchase / checkout.
- PromptPurchase.
- Owned check.
- Price validation.
- Creator/seller validation.
- Save outfit ke Roblox account.
- Persist outfit ke DataStore.
- Marketplace monetization / commission flow.

Catatan: field seperti harga, nama, thumbnail tetap boleh ditampilkan di UI, tetapi tidak boleh mempengaruhi flow `Apply` temporary outfit.

---

## 2. Kondisi project saat ini

Berdasarkan repo acuan, arah project sudah benar:

- UI catalog dibuat sebagai client React-lua app.
- Preview avatar direncanakan berjalan di `ViewportFrame` clone secara client-only.
- Player lain baru melihat perubahan setelah user klik `Apply`.
- Milestone lama sudah memisahkan `Try On` client-side dan `Apply` server-side.
- Implementation plan lama sudah memilih desired final state daripada delta, supaya lebih idempotent.

Namun beberapa bagian perlu direvisi:

1. Model lama `itemIds: { number }` kurang cukup untuk bundle dan animation package.
2. Current `PreviewState` masih berpusat ke `CatalogItem` dan `getDesiredAssetIds()`.
3. Current client punya `ensurePropertyName()` yang mengambil product info async setelah item sudah dipilih, ini bisa memunculkan delay/bug.
4. Server saat ini melakukan validasi asset id satu per satu saat apply. Ini aman, tapi perlu diubah menjadi resolver/cache agar tidak terasa berat.
5. Apply server saat ini memakai `ApplyDescription`; target baru pakai `ApplyDescriptionAsync(..., Enum.AssetTypeVerification.Always)`.

---

## 3. Target architecture

### 3.1 Client-side modules

Tambahkan / refactor module berikut:

```text
src/client/services/CatalogService.luau
src/client/services/PreviewPayloadResolver.luau
src/client/services/PreviewPayloadCache.luau
src/client/services/CatalogWarmupQueue.luau
src/client/services/ViewportDescriptionBuilder.luau
src/client/services/ViewportPreviewApplier.luau
src/client/controllers/AvatarPreviewController.luau
src/client/logic/PreviewState.luau
```

Tanggung jawab:

- `CatalogService`: fetch catalog metadata per category/search/cursor.
- `PreviewPayloadResolver`: mengubah catalog item mentah menjadi payload siap preview.
- `PreviewPayloadCache`: cache by `ItemKey`, misalnya `Asset:123` atau `Bundle:456`.
- `CatalogWarmupQueue`: concurrency-limited resolver queue.
- `PreviewState`: menyimpan draft outfit berbasis preview payload, bukan asset id angka saja.
- `ViewportDescriptionBuilder`: build `HumanoidDescription` dari draft preview.
- `ViewportPreviewApplier`: apply/rebuild viewport clone.
- `AvatarPreviewController`: action layer untuk UI.

### 3.2 Server-side modules

Tambahkan / refactor module berikut:

```text
src/server/services/AvatarApplyService.luau
src/server/services/ServerCatalogResolver.luau
src/server/services/ResolvedItemCache.luau
src/server/services/AvatarDescriptionBuilder.luau
src/server/services/ApplyRateLimiter.luau
```

Tanggung jawab:

- `AvatarApplyService`: remote entrypoint, get equipped, warmup server cache, apply live character.
- `ServerCatalogResolver`: resolve item key dari server-side, parse bundle/asset ke payload valid.
- `ResolvedItemCache`: TTL cache dan pending request dedupe.
- `AvatarDescriptionBuilder`: build final `HumanoidDescription` dari desired entries.
- `ApplyRateLimiter`: per-player cooldown apply/warmup.

---

## 4. Data contract target

### 4.1 ItemKey

Gunakan key yang membedakan asset dan bundle.

```lua
export type AvatarItemType = "Asset" | "Bundle"
export type ItemKey = string -- "Asset:123456" atau "Bundle:987654"

local function makeItemKey(itemType: AvatarItemType, id: number): string
    return `{itemType}:{id}`
end
```

Kenapa bukan angka saja?

- `Asset:123` dan `Bundle:123` bisa merujuk hal berbeda.
- Animation package biasanya berasal dari bundle, tapi hasil preview-nya berupa beberapa animation id.
- Bundle body bisa berisi beberapa item yang harus dipetakan ke beberapa property.

### 4.2 CatalogItem

```lua
export type CatalogItem = {
    key: ItemKey,
    id: number,
    itemType: AvatarItemType,

    name: string,
    price: number | string,
    image: string,

    assetTypeId: number?,
    assetTypeName: string?,
    category: string?,
    subcategory: string?,
}
```

### 4.3 PreviewPayload

Payload ini adalah hasil resolve yang sudah siap dipakai untuk preview.

```lua
export type PreviewPayload = {
    key: ItemKey,
    id: number,
    itemType: AvatarItemType,
    kind: string,

    propertyName: string?,
    assetIds: { number }?,
    animations: { [string]: number }?,
    bodyParts: { [string]: number }?,
    emoteAnimationId: number?,
}
```

Contoh accessory:

```lua
{
    key = "Asset:123456",
    id = 123456,
    itemType = "Asset",
    kind = "Accessory",
    propertyName = "JacketAccessory",
    assetIds = { 123456 },
}
```

Contoh animation bundle:

```lua
{
    key = "Bundle:987654",
    id = 987654,
    itemType = "Bundle",
    kind = "AnimationBundle",
    animations = {
        IdleAnimation = 111,
        WalkAnimation = 222,
        RunAnimation = 333,
        JumpAnimation = 444,
        FallAnimation = 555,
        ClimbAnimation = 666,
        SwimAnimation = 777,
    },
}
```

### 4.4 DesiredOutfitEntry untuk server apply

Client tidak mengirim final `HumanoidDescription`. Client hanya mengirim niat final user.

```lua
export type DesiredOutfitEntry = {
    key: ItemKey,
    itemType: AvatarItemType,
    id: number,
}
```

---

## 5. Remote contract target

Untuk fase awal, boleh pertahankan satu `RemoteFunction` existing dengan field `action` supaya diff kecil. Setelah stabil, boleh dipisah menjadi beberapa remote.

### 5.1 GetEquipped

Request:

```lua
{
    action = "GetEquipped"
}
```

Response:

```lua
{
    success = true,
    equippedEntries = { DesiredOutfitEntry },
    originalEntries = { DesiredOutfitEntry },
}
```

### 5.2 WarmupItems

Request:

```lua
{
    action = "WarmupItems",
    items = {
        { key = "Asset:123", itemType = "Asset", id = 123 },
        { key = "Bundle:456", itemType = "Bundle", id = 456 },
    },
}
```

Response:

```lua
{
    success = true,
    warmed = { "Asset:123", "Bundle:456" },
    failed = { "Asset:999" },
}
```

Catatan:

- Warmup server adalah optimization, bukan dependency wajib.
- Jika server cache miss saat Apply, server tetap boleh resolve sekali.
- Warmup request harus diberi rate limit dan batch limit.

### 5.3 Apply

Request:

```lua
{
    action = "Apply",
    items = {
        { key = "Asset:123", itemType = "Asset", id = 123 },
        { key = "Bundle:456", itemType = "Bundle", id = 456 },
    },
}
```

Response sukses:

```lua
{
    success = true,
    message = "Outfit berhasil diterapkan.",
    equippedEntries = { DesiredOutfitEntry },
}
```

Response gagal:

```lua
{
    success = false,
    message = "Terlalu banyak item yang dipilih sekaligus."
}
```

---

## 6. Phase-by-phase implementation plan

Instruksi untuk AI agent:

```text
Kerjakan hanya satu phase per run.
Jangan lanjut ke phase berikutnya sebelum user/developer bilang lanjut.
Setelah selesai satu phase, laporkan:
1. file yang dibuat/diubah,
2. ringkasan perubahan,
3. acceptance criteria yang sudah dites,
4. risiko atau TODO phase berikutnya.
Jangan implement purchase/checkout/ownership check di phase mana pun kecuali ada instruksi baru.
```

### Phase 0 - Repo audit dan safety baseline

**Goal:** pahami struktur repo dan pastikan tidak merusak flow yang sudah ada.

Files yang dibaca:

```text
README.md
implementation_plan.md
roblox_item_catalog_milestones.md
src/client/logic/PreviewState.luau
src/client/controllers/AvatarPreviewController.luau
src/server/services/AvatarApplyService.luau
src/shared/config/CatalogConfig.luau
src/shared/types/CatalogTypes.luau
src/shared/remotes/ApplyAvatarRemote.luau
```

Task:

- Catat flow existing.
- Catat API public yang sudah dipakai UI.
- Jangan ubah behavior dulu kecuali ada error kecil yang menghalangi build.
- Jalankan command check/build yang tersedia di repo.

Acceptance criteria:

- Agent punya daftar file penting dan dependency antar module.
- Project masih build/check tanpa error baru.
- Tidak ada perubahan arsitektur besar di phase ini.

Stop condition:

- Stop setelah audit dan laporan. Jangan lanjut implement phase 1.

---

### Phase 1 - Shared type contract dan key system

**Goal:** menyiapkan model data baru tanpa mengubah UI besar.

Files target:

```text
src/shared/types/CatalogTypes.luau
src/shared/types/PreviewTypes.luau       -- baru jika belum ada
src/shared/types/AvatarApplyTypes.luau   -- baru jika perlu
src/shared/config/CatalogConfig.luau
```

Task:

- Tambahkan `AvatarItemType = "Asset" | "Bundle"`.
- Tambahkan `ItemKey` convention: `Asset:{id}` dan `Bundle:{id}`.
- Tambahkan helper `makeItemKey`, `parseItemKey`, `isValidItemKey`.
- Update `CatalogItem` agar punya `key`, `id`, `itemType`, metadata display.
- Tambahkan `PreviewPayload` type.
- Tambahkan `DesiredOutfitEntry` type untuk remote apply.
- Pastikan type lama tetap kompatibel sementara jika UI masih pakai `assetId`.

Acceptance criteria:

- Type baru bisa di-require dari client dan server.
- `makeItemKey("Asset", 123)` menghasilkan `Asset:123`.
- `parseItemKey("Bundle:456")` menghasilkan `{ itemType = "Bundle", id = 456 }`.
- Existing code belum wajib diubah total di phase ini.

Stop condition:

- Stop setelah shared contract siap dan build/check lolos.

---

### Phase 2 - Client ready-first catalog loading

**Goal:** card hanya muncul kalau preview payload sudah ready.

Files target:

```text
src/client/services/CatalogService.luau
src/client/services/PreviewPayloadResolver.luau
src/client/services/PreviewPayloadCache.luau
src/client/services/CatalogWarmupQueue.luau
src/client/hooks/useCatalogItems.luau atau hook existing
src/client/ui/... catalog grid/card components
```

Task:

- Buat `CatalogService` untuk fetch 30 item per category/search/cursor.
- Buat `PreviewPayloadCache` by `ItemKey`.
- Buat `PreviewPayloadResolver.resolve(item): PreviewPayload?`.
- Buat `CatalogWarmupQueue` dengan concurrency 4-6 item.
- Saat category dibuka:
  - render skeleton 30 slot,
  - fetch catalog metadata,
  - warmup item secara background,
  - reveal item saat payload ready,
  - failed/timeout item jangan tampil normal.
- Tambahkan request token per category/search agar hasil lama tidak masuk ke UI baru.
- Untuk infinite scroll, fetch next page saat user mencapai 60-70% scroll.

Pseudo flow:

```text
LoadCategory(category)
-> requestId += 1
-> ShowSkeleton(30)
-> items = CatalogService.fetchPage(category, cursor)
-> queue.warmup(items, requestId)
-> onPayloadReady(item, payload): if requestId still active, reveal card
```

Acceptance criteria:

- User melihat skeleton dulu.
- Item muncul bertahap setelah payload ready.
- Klik card yang terlihat tidak memicu resolver/fetch lagi.
- Pindah category saat warmup belum selesai tidak membuat item category lama nyasar.
- Failed item tidak stuck sebagai skeleton selamanya; ada timeout/hide.

Stop condition:

- Stop setelah ready-first rendering bekerja minimal untuk asset biasa.
- Bundle/animation boleh masih basic/fallback jika belum selesai, tetapi struktur resolver harus siap.

---

### Phase 3 - Preview payload resolver untuk asset, bundle, animation, emote

**Goal:** semua tipe item yang ditampilkan sudah punya payload siap preview sebelum card muncul.

Files target:

```text
src/client/services/PreviewPayloadResolver.luau
src/client/services/PreviewPayloadCache.luau
src/shared/config/CatalogConfig.luau
```

Task:

- Asset wearable biasa:
  - map `AssetTypeId` ke `HumanoidDescription` property via `CatalogConfig.AssetTypeToProperty`.
- Layered clothing/accessory:
  - pastikan property seperti `JacketAccessory`, `SweaterAccessory`, `PantsAccessory`, dll didukung jika masuk scope.
- Bundle:
  - parse bundled items.
  - buat payload sesuai isi bundle.
- Animation package:
  - map bundled animation asset ke properties: `IdleAnimation`, `WalkAnimation`, `RunAnimation`, `JumpAnimation`, `FallAnimation`, `ClimbAnimation`, `SwimAnimation`.
- Emote:
  - payload boleh berupa `emoteAnimationId`, tidak harus langsung masuk outfit draft permanen.
- Tambahkan batch detail lookup jika memungkinkan, bukan satu request per item.
- Gunakan cache dan pending promise dedupe agar item sama tidak diresolve berkali-kali.

Acceptance criteria:

- Asset biasa resolve ke property benar.
- Animation package resolve menjadi beberapa property animation, bukan satu asset id mentah.
- Bundle yang tidak bisa dipreview ditandai failed dan tidak muncul sebagai card normal.
- Resolver tidak melakukan request ulang untuk item yang sudah cached.

Stop condition:

- Stop setelah resolver client stabil dan item visible selalu punya payload.

---

### Phase 4 - PreviewState refactor berbasis payload

**Goal:** preview state tidak lagi berbasis asset id angka saja.

Files target:

```text
src/client/logic/PreviewState.luau
src/client/controllers/AvatarPreviewController.luau
src/client/hooks/usePreviewState.luau
```

Task:

- Ganti/add state:

```lua
previewPayloads: { [ItemKey]: PreviewPayload }
appliedEntries: { [ItemKey]: DesiredOutfitEntry }
originalEntries: { [ItemKey]: DesiredOutfitEntry }
```

- Tambah API:

```lua
PreviewState.hydrateAppliedEntries(entries)
PreviewState.hydrateOriginalEntries(entries)
PreviewState.addPreviewPayload(payload)
PreviewState.removePreviewPayload(key)
PreviewState.hasPreviewPayload(key)
PreviewState.getDesiredEntries()
PreviewState.resetPreviewToApplied()
PreviewState.isDirty()
```

- Pertahankan compat method lama sementara jika UI belum semua diganti.
- `AvatarPreviewController.ToggleItemPreview(item)` diganti/ditambah menjadi `TogglePayloadPreview(payload)`.
- Jangan ada `MarketplaceService:GetProductInfo` di `PreviewState`. Resolver harus di luar state.

Acceptance criteria:

- PreviewState tidak melakukan network/Marketplace call.
- Klik item ready menambahkan payload ke preview state.
- `getDesiredEntries()` mengembalikan `Asset` dan `Bundle` entry yang benar.
- Reset preview kembali ke applied snapshot, bukan selalu empty.
- `isDirty` benar saat add/remove/reset.

Stop condition:

- Stop setelah state baru stabil dan UI masih bisa toggle preview.

---

### Phase 5 - Viewport preview stabilization

**Goal:** preview di ViewportFrame tidak ngebug walau user klik cepat.

Files target:

```text
src/client/services/ViewportDescriptionBuilder.luau
src/client/services/ViewportPreviewApplier.luau
src/client/controllers/AvatarPreviewController.luau
src/client/ui/... AvatarPreviewViewport component
```

Task:

- Buat builder yang menerima `PreviewPayload` draft dan menghasilkan `HumanoidDescription` target.
- Source of truth tetap `PreviewState`, bukan instance accessory di viewport.
- Untuk setiap preview update:
  - clone base/current description,
  - clear supported fields yang dikelola catalog,
  - apply payload draft ke description,
  - apply ke viewport clone.
- Tambahkan request token / revision:

```lua
local revision = 0
function ApplyPreviewFromState()
    revision += 1
    local currentRevision = revision
    local description = ViewportDescriptionBuilder.build(PreviewState.getPreviewPayloads())
    if currentRevision ~= revision then return end
    ViewportPreviewApplier.apply(description)
end
```

- Jika `ApplyDescriptionAsync` ke clone tidak menghapus item dengan benar, rebuild clone dari base description.
- Strip `Script` dan `LocalScript` dari clone viewport.
- Anchor/position clone agar tidak terkena physics.

Acceptance criteria:

- Spam klik 10 item cepat tidak membuat preview kembali ke item lama.
- Remove item benar-benar hilang dari viewport.
- Reset preview stabil.
- Preview tidak mutate live character.
- Preview tidak fire remote.

Stop condition:

- Stop setelah viewport preview smooth untuk asset biasa + minimal animation/bundle yang sudah resolve.

---

### Phase 6 - Server resolver/cache dan minimal validation

**Goal:** server tetap aman dan cepat tanpa validasi checkout yang tidak perlu.

Files target:

```text
src/server/services/ServerCatalogResolver.luau
src/server/services/ResolvedItemCache.luau
src/server/services/ApplyRateLimiter.luau
src/server/services/AvatarDescriptionBuilder.luau
src/server/services/AvatarApplyService.luau
```

Task:

- Tambahkan `ResolvedItemCache`:
  - key: `ItemKey`,
  - value: server-side resolved payload,
  - TTL: 10-30 menit,
  - pending request dedupe.
- Tambahkan `ServerCatalogResolver.resolve(entry)`:
  - cek cache,
  - resolve asset/bundle jika miss,
  - validate item type supported,
  - return resolved payload.
- Tambahkan `ApplyRateLimiter`:
  - Apply cooldown misalnya 1.0-1.5 detik/player,
  - Warmup cooldown/batch throttle,
  - max items per apply tetap sekitar 20.
- Validasi server cukup:
  - payload harus table,
  - item count <= max,
  - key format valid,
  - itemType hanya `Asset` atau `Bundle`,
  - id number positif,
  - server build description sendiri.

Tidak perlu validasi ini:

```text
Owned check
Purchase check
Price validation
IsPurchasable check
Seller/creator validation
```

Acceptance criteria:

- Payload besar ditolak cepat.
- Spam apply kena cooldown.
- Cache hit tidak resolve ulang.
- Cache miss resolve sekali dan cache.
- Server tidak percaya final HumanoidDescription dari client.

Stop condition:

- Stop setelah resolver/cache server siap dan testable, walau belum disambung penuh ke Apply.

---

### Phase 7 - Apply temporary outfit ke live character

**Goal:** outfit dari preview bisa dipakai di karakter asli dan terlihat semua player.

Files target:

```text
src/server/services/AvatarApplyService.luau
src/server/services/AvatarDescriptionBuilder.luau
src/shared/remotes/ApplyAvatarRemote.luau
src/client/logic/PreviewState.luau
src/client/controllers/... apply button handler
```

Task:

- Update `ApplyAvatarRemote.OnServerInvoke` untuk handle:
  - `GetEquipped`,
  - `WarmupItems`,
  - `Apply`.
- `Apply` flow:

```text
Receive desired entries
-> rate limit
-> validate shape
-> normalize + dedupe by key
-> resolve each entry using ServerCatalogResolver
-> build final HumanoidDescription
-> humanoid:ApplyDescriptionAsync(finalDescription, Enum.AssetTypeVerification.Always)
-> cache temporary outfit state
-> return equippedEntries snapshot
```

- Gunakan `ApplyDescriptionResetAsync(..., Always)` sebagai fallback jika ada kasus viewport/live character tidak match karena external mutation.
- Cache player temporary outfit per session.
- Saat `CharacterAdded`, reapply cached temporary description.

Acceptance criteria:

- Klik Apply mengubah karakter asli player.
- Player lain melihat perubahan.
- Apply same state tidak duplicate.
- Remove item dari preview lalu Apply membuat item hilang di live character.
- Respawn menjaga temporary outfit terakhir.
- Empty supported outfit bisa diterapkan tanpa fallback ke outfit awal.

Stop condition:

- Stop setelah server apply temporary outfit stabil.

---

### Phase 8 - QA, performance, dan cleanup

**Goal:** memastikan flow siap dipakai sebelum lanjut checkout/purchase future phase.

Task QA manual:

- Buka category, skeleton muncul.
- Item card hanya muncul saat preview-ready.
- Klik item visible, preview langsung berubah.
- Search lalu cepat pindah category; item lama tidak nyasar.
- Infinite scroll tidak freeze.
- Klik banyak item cepat; preview tetap state terbaru.
- Apply spam cepat; server cooldown bekerja.
- Apply > max items; server reject cepat.
- Respawn setelah apply; outfit temporary tetap.
- Bundle/animation package tidak delay saat klik.

Task performance:

- Log count resolver request client.
- Log count server cache hit/miss.
- Pastikan tidak resolve item yang sama berkali-kali.
- Pastikan warmup queue concurrency tidak terlalu tinggi.
- Pastikan `ApplyDescriptionAsync` tidak dipanggil bertumpuk.

Cleanup:

- Remove compat method lama jika semua UI sudah pakai contract baru.
- Hapus `ensurePropertyName()` dari `PreviewState`.
- Rapikan warning/error message.
- Dokumentasikan remote contract final di repo.

Acceptance criteria:

- No visible preview delay untuk item ready.
- No major viewport desync.
- No server spike saat scroll/apply normal.
- `scripts/check.ps1` dan build project lolos.

Stop condition:

- Stop setelah laporan QA dan daftar bug sisa.

---

## 7. Agent implementation prompts per phase

AI agent bisa diberi prompt terpisah seperti ini.

### Prompt Phase 1

```text
Kerjakan Phase 1 saja dari dokumen teknis. Tambahkan shared type contract untuk ItemKey, CatalogItem, PreviewPayload, dan DesiredOutfitEntry. Jangan ubah flow UI/server apply dulu. Setelah selesai, laporkan file yang diubah dan acceptance criteria.
```

### Prompt Phase 2

```text
Kerjakan Phase 2 saja. Implement ready-first catalog loading: skeleton dulu, fetch metadata, warmup preview payload, reveal card hanya kalau payload ready. Jangan ubah server apply. Setelah selesai, stop dan laporkan hasil.
```

### Prompt Phase 3

```text
Kerjakan Phase 3 saja. Lengkapi PreviewPayloadResolver agar asset, bundle, animation package, dan emote menghasilkan PreviewPayload yang siap dipakai. Jangan refactor PreviewState besar-besaran kecuali diperlukan minimal. Setelah selesai, stop.
```

### Prompt Phase 4

```text
Kerjakan Phase 4 saja. Refactor PreviewState agar berbasis PreviewPayload dan DesiredOutfitEntry, bukan asset id angka saja. Pastikan tidak ada MarketplaceService call di PreviewState. Setelah selesai, stop.
```

### Prompt Phase 5

```text
Kerjakan Phase 5 saja. Stabilkan ViewportFrame preview dengan builder/applier, request revision token, dan rebuild clone fallback. Try On tetap client-only dan tidak fire remote. Setelah selesai, stop.
```

### Prompt Phase 6

```text
Kerjakan Phase 6 saja. Tambahkan server resolver/cache, minimal validation, dan rate limiter. Jangan implement checkout, purchase, ownership check, atau price validation. Setelah selesai, stop.
```

### Prompt Phase 7

```text
Kerjakan Phase 7 saja. Sambungkan Apply remote agar desired entries dari preview diterapkan sebagai temporary outfit ke live character menggunakan ApplyDescriptionAsync dengan AssetTypeVerification.Always. Tambahkan respawn reapply. Setelah selesai, stop.
```

### Prompt Phase 8

```text
Kerjakan Phase 8 saja. Lakukan QA/performance cleanup, hapus compat lama yang aman dihapus, dan dokumentasikan hasil final. Jangan tambah fitur purchase. Setelah selesai, laporkan test matrix.
```

---

## 8. Design notes penting

### 8.1 Kenapa visible card harus preview-ready?

User lebih sabar melihat skeleton daripada klik item lalu menunggu preview. Dengan rule ini, delay pindah ke fase loading yang natural, bukan setelah user sudah punya niat klik.

### 8.2 Kenapa server tetap perlu cek minimal?

Bukan untuk mencegah beli gratis, karena belum ada purchase. Cek minimal hanya untuk mencegah:

- Remote spam.
- Payload besar.
- Cache miss brutal.
- ApplyDescription bertumpuk.
- Item key invalid yang membebani resolver.

### 8.3 Kenapa client preload bukan source of truth server?

Client boleh jadi source of truth untuk UX preview, tapi live character terlihat player lain sehingga server harus tetap executor. Server tidak perlu validasi checkout, tapi tetap harus build `HumanoidDescription` sendiri.

### 8.4 Kenapa `itemIds: number[]` diganti `entries`?

Karena item bisa berupa Asset atau Bundle. Animation package dan body bundle tidak cukup direpresentasikan dengan satu angka yang langsung masuk property accessory.

---

## 9. Suggested acceptance test matrix

| Area | Test | Expected |
| --- | --- | --- |
| Catalog | buka category | skeleton muncul dulu |
| Catalog | item ready | card muncul clickable |
| Catalog | item failed resolve | card tidak tampil normal / hidden |
| Preview | klik ready asset | viewport berubah instant |
| Preview | spam klik | state terakhir menang |
| Preview | remove item | item hilang dari viewport |
| Preview | reset | balik ke applied snapshot |
| Category | pindah category saat loading | item lama tidak masuk UI baru |
| Server | apply valid | live character berubah |
| Server | apply spam | cooldown reject/ignore |
| Server | payload besar | reject cepat |
| Server | cache hit | tidak resolve ulang |
| Server | respawn | temporary outfit reapplied |
| Scope | checkout | tidak ada perubahan/prompt purchase |

---

## 10. Referensi teknis

- Repo acuan: https://github.com/abayzv/roblox-catalog-avatar/tree/0505d1b4ddcdb78a824174636af1978725836f6d
- README project: https://github.com/abayzv/roblox-catalog-avatar/tree/0505d1b4ddcdb78a824174636af1978725836f6d#readme
- Implementation plan lama: https://raw.githubusercontent.com/abayzv/roblox-catalog-avatar/0505d1b4ddcdb78a824174636af1978725836f6d/implementation_plan.md
- Milestone lama: https://raw.githubusercontent.com/abayzv/roblox-catalog-avatar/0505d1b4ddcdb78a824174636af1978725836f6d/roblox_item_catalog_milestones.md
- Roblox security tactics: https://create.roblox.com/docs/scripting/security/security-tactics
- Roblox remote events/callbacks: https://create.roblox.com/docs/scripting/events/remote
- Roblox AvatarEditorService item details/throttling: https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService/GetBatchItemDetails
- Roblox Humanoid ApplyDescriptionAsync: https://create.roblox.com/docs/reference/engine/classes/Humanoid/ApplyDescriptionResetAsync
- Roblox AssetTypeVerification: https://create.roblox.com/docs/reference/engine/enums/AssetTypeVerification

---

## 11. Final guardrails untuk agent

```text
Do:
- Keep Try On fully client-only.
- Keep card hidden/skeleton until preview payload is ready.
- Use item entries/key instead of raw number[] for new flow.
- Use server cache/resolver for Apply.
- Keep validation minimal and tied to runtime safety.
- Use ApplyDescriptionAsync with AssetTypeVerification.Always for live character.
- Stop after each phase.

Do not:
- Implement purchase/checkout now.
- Add ownership validation now.
- Let PreviewState call MarketplaceService.
- Fetch/parse item again when a visible card is clicked.
- Trust client-sent HumanoidDescription.
- Let stale async request mutate current category/preview.
- Continue to next phase without explicit instruction.
```
