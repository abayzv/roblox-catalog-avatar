# Roblox Catalog V2 - Dokumen Utama

Dokumen ini adalah sumber utama untuk memahami proyek Roblox Catalog V2. Pakai ini sebagai rel pertama sebelum membaca dokumen phase lama atau membuka banyak file satu per satu.

## Ringkasan

Roblox Catalog V2 adalah sistem avatar catalog berbasis React-Lua untuk Roblox. Pemain bisa membuka UI catalog dari TopbarPlus, mencari item/avatar/template, mencoba perubahan appearance, melihat hasilnya di preview viewport, menyimpan template avatar, dan memuat template/avatar lain.

Fokus proyek saat ini:

- Catalog UI dengan kategori, subkategori, search, pagination, loading skeleton, dan item grid.
- Preview avatar di sisi kanan memakai `ViewportFrame`.
- State appearance berbasis `HumanoidDescription` snapshot.
- Try-on/remove/load template memakai optimistic update di client lalu disinkronkan ke server.
- Template avatar disimpan lewat DataStore dan bisa diload lagi memakai kode/template list.

## Status Saat Ini

Yang sudah ada:

- Struktur Rojo, Wally, Aftman, StyLua, script check/build.
- React-Lua app mount ke `PlayerGui` lewat `src/client/App.client.luau`.
- TopbarPlus button `Catalog` untuk show/hide UI dan background blur.
- Tab utama: `Item Catalog`, `My Avatar`, `Avatar Loader`.
- Catalog browsing memakai `AvatarEditorService:SearchCatalog`.
- Category/subcategory untuk body, clothing, accessory, animation, bundle.
- Grid item 5 kolom dengan pagination, cache search, loading state, dan payload warmup.
- Preview appearance memakai `ViewportFrame`, `WorldModel`, camera framing, idle animation, drag rotate.
- Try-on item, remove worn item, reset original avatar.
- Emote preview dengan resolver animation asset.
- Avatar Loader untuk list template, load template, load Roblox outfit, direct search by code/username.
- Save template dari avatar saat ini.
- Server appearance state per player, live revision, original snapshot, respawn reapply, dan morph detection.

Catatan penting: beberapa dokumen roadmap lama menyebut preview harus client-only sampai tombol Apply. Kode saat ini sudah bergerak ke model snapshot + optimistic update + server apply lewat `ApplyAvatarRemote`. Untuk perilaku aktual, ikuti README ini dan kode sekarang.

## Stack

- Roblox Luau
- Rojo project: `default.project.json`
- React-Lua dan ReactRoblox dari Wally
- TopbarPlus v3
- Aftman untuk toolchain
- StyLua untuk format/check

Command utama:

```powershell
aftman install
wally install
.\scripts\check.ps1
.\scripts\build.ps1
rojo serve default.project.json
```

## Arsitektur Singkat

```text
src/client
  App.client.luau              entry client, mount React, init TopbarPlus
  ui/                          design system + React components
  hooks/                       data hooks untuk catalog/appearance/worn items
  services/                    client service, cache, resolver, warmup queue
  controllers/                 topbar, preview, viewport animation
  logic/                       snapshot mutation dan preview state

src/server
  init.server.luau             init semua server service
  services/                    apply appearance, template, emote, Roblox outfit API

src/shared
  remotes/                     typed wrappers untuk RemoteFunction
  types/                       shared type modules
  avatar/                      serializer/extractor/config avatar
  config/                      catalog whitelist/config
```

Source of truth appearance saat runtime:

1. Server menyimpan `originalSnapshot`, `liveSnapshot`, dan `liveRevision` di `AvatarAppearanceService`.
2. Client mengambil snapshot via `AvatarAppearanceClient.fetchStateAsync`.
3. UI/preview membaca state lewat `useAppearanceState`.
4. Try-on/remove/load template membuat predicted snapshot di client.
5. Client mengirim snapshot ke server lewat `ApplyAvatarRemote`.
6. Server validate snapshot, apply ke humanoid, lalu mengembalikan snapshot dan revision terbaru.

## Fitur Dan File Index

| Fitur | File utama |
| --- | --- |
| App bootstrap | `src/client/App.client.luau`, `src/client/ui/App.luau` |
| Topbar toggle | `src/client/controllers/CatalogTopbarController.luau` |
| Layout layar utama | `src/client/ui/screens/CatalogScreen.luau` |
| Theme/icon | `src/client/ui/theme/Theme.luau`, `src/client/ui/theme/Icons.luau` |
| Header tab | `src/client/ui/organisms/HeaderTabs.luau`, `src/client/ui/molecules/HeaderTabButton.luau` |
| Search toolbar | `src/client/ui/molecules/SearchToolbar.luau`, `src/client/ui/molecules/SearchInput.luau` |
| Category/chip | `src/client/ui/organisms/MainCategoryTabs.luau`, `src/client/ui/organisms/SubCategoryChips.luau` |
| Catalog panel | `src/client/ui/organisms/CatalogPanel.luau`, `src/client/hooks/useCatalogItems.luau` |
| Catalog data | `src/client/services/CatalogService.luau`, `src/shared/types/CatalogTypes.luau` |
| Item grid/card | `src/client/ui/organisms/CatalogGrid.luau`, `src/client/ui/molecules/ItemCard.luau` |
| Preview viewport | `src/client/ui/organisms/AvatarPreviewViewport.luau` |
| Try-on/remove logic | `src/client/controllers/AvatarPreviewController.luau`, `src/client/logic/AvatarDescriptionDraft.luau` |
| Preview payload | `src/client/services/PreviewPayloadResolver.luau`, `src/client/services/PreviewPayloadCache.luau` |
| Appearance client state | `src/client/services/AvatarAppearanceClient.luau`, `src/client/hooks/useAppearanceState.luau` |
| Server apply state | `src/server/services/AvatarAppearanceService.luau`, `src/server/services/AvatarApplyService.luau` |
| My Avatar tab | `src/client/ui/organisms/MyAvatarPanel.luau`, `src/client/hooks/useWornItems.luau` |
| Worn item extraction | `src/shared/avatar/WornItemExtractor.luau`, `src/client/services/WornItemDetailsService.luau` |
| Avatar Loader tab | `src/client/ui/organisms/AvatarLoaderPanel.luau` |
| Template system | `src/server/services/AvatarTemplateService.luau`, `src/client/services/AvatarTemplateCache.luau` |
| Template thumbnail | `src/client/services/TemplateThumbnailGenerator.luau` |
| Roblox outfit/user load | `src/server/services/RobloxOutfitConverter.luau`, `src/server/services/RobloxAvatarApiClient.luau` |
| Emote resolving | `src/server/services/ResolveEmotesService.luau`, `src/client/services/EmoteAnimationResolver.luau` |
| HumanoidDescription snapshot | `src/shared/avatar/HumanoidDescriptionSerializer.luau` |
| Remote wrappers | `src/shared/remotes/*.luau`, `default.project.json` |

## UI Guideline

Gunakan style yang sudah ada, bukan bikin bahasa visual baru.

- Layout utama split: catalog kiri `0.68`, preview kanan `0.32`.
- Root `ScreenGui`: `IgnoreGuiInset = false`, `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`.
- Panel memakai `Theme.Color.Panel`, radius `Theme.Radius.Panel`, padding `Theme.Space.XL`.
- Detail visual harus ambil dari `Theme.luau` dan `Icons.luau`.
- Content panel diskalakan dengan `UIScale`; jangan membuat fixed-size surface sebagai panel utama fullscreen.
- Row dengan stroke/focus perlu tinggi dan padding cukup supaya stroke tidak kepotong.
- Grid saat ini memakai 5 kolom dengan ukuran cell dihitung dari lebar container dan `viewportScale`.
- Preview avatar harus berada di `ViewportFrame` berisi `Camera` + `WorldModel`.
- Jangan campur logic Marketplace/server apply langsung ke component UI presentational.

Panduan layout lengkap ada di `docs/roblox_ui_layout_guide.md`.

## Pedoman Untuk AI Agent

- Mulai dari dokumen ini sebelum membaca phase plan lain.
- Kalau perlu mengubah UI, cek `Theme.luau`, component atom/molecule yang sudah ada, lalu ikuti pola panel/grid yang ada.
- Kalau perlu mengubah appearance flow, mulai dari `AvatarAppearanceClient`, `AvatarPreviewController`, `AvatarDescriptionDraft`, dan `AvatarAppearanceService`.
- Kalau perlu menambah kategori/asset type, cek `CatalogService.applyFilters`, `CatalogConfig.AssetTypeToProperty`, dan extractor terkait.
- Kalau perlu remote baru, tambahkan wrapper di `src/shared/remotes`, mapping di `default.project.json`, lalu init handler di service server.
- Jangan menganggap dokumen phase lama selalu lebih benar dari kode saat ini. Phase docs adalah sejarah/roadmap; README ini adalah pegangan utama.
- Hindari menyentuh file besar UI tanpa memahami props dan scaling, karena layout Roblox UI mudah rusak di viewport kecil.

## Dokumen Pendukung

- `docs/roblox_ui_layout_guide.md` - pedoman layout Roblox UI.
- `docs/roblox_item_catalog_milestones.md` - milestone awal dan roadmap historis.
- `docs/roblox_catalog_avatar_technical_plan.md` - rencana teknis avatar/catalog.
- `docs/phase_*_plan.md` - catatan implementasi per fase.
- `implementation_plan.md` - rencana lama desired outfit state, masih berguna untuk konteks keputusan apply flow.

## Batasan/Known Notes

- Ownership item belum dipaksa secara default; `CatalogConfig.RequireOwnership = false`.
- Template thumbnail masih punya placeholder/generator client-side.
- Beberapa ikon di `Icons.luau` masih bertanda TODO untuk asset final.
- Search/catalog bergantung pada service Roblox dan bisa throttle; ada fallback/caching ringan di client.
- Beberapa server flow memakai DataStore/HTTP, jadi perlu diuji di environment Studio yang mengizinkan API terkait.
