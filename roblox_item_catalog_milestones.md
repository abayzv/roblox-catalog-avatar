# Milestone Roblox Item Catalog System

Dokumen ini membagi pekerjaan menjadi milestone dan issue kecil agar bisa dikerjakan bertahap. Prioritas utama adalah UI first: bentuk catalog panel, item grid, tab, search, filter, dan visual state harus jadi dulu sebelum logic katalog, avatar preview, purchase, atau server apply.

Referensi UI utama:
- `roblox_item_catalog_gui_guideline.md`
- Screenshot referensi catalog panel kiri + karakter aktif di kanan

## Prinsip Arsitektur

1. UI catalog dibuat dulu dengan mock data.
2. Preview avatar menggunakan karakter aktif player di world, bukan `ViewportFrame`.
3. Tombol `Try On` hanya melakukan preview client-side pada karakter lokal.
4. Item hasil preview tidak terlihat oleh player lain.
5. Tombol `Apply` baru mengirim pilihan final ke server.
6. Server hanya menerima pilihan final, melakukan validasi, lalu menerapkan appearance agar terlihat oleh player lain.
7. Komponen UI tidak boleh berisi logic Marketplace, purchase, server validation, atau insert asset langsung.
8. Catalog UI dibuka dan ditutup lewat tombol TopbarPlus bernama `Catalog`.

## Milestone 0 - Project Foundation

Tujuan: menyiapkan struktur proyek agar UI bisa dibangun modular dengan React-lua/Rojo.

### Issue 0.1 - Setup Rojo Project Structure

Scope:
- Tambahkan `default.project.json`.
- Buat struktur folder `src/client`, `src/shared`, dan folder UI.
- Pastikan `StarterPlayerScripts` memuat entry client.

Acceptance criteria:
- Project bisa dibuka/sync lewat Rojo.
- `src/client/App.client.luau` dapat berjalan tanpa error.
- Struktur folder siap untuk komponen UI.

### Issue 0.2 - Setup Tooling

Scope:
- Tambahkan konfigurasi StyLua.
- Tambahkan command format/check sederhana jika dibutuhkan.
- Dokumentasikan cara run project lokal.

Acceptance criteria:
- Format command berjalan.
- Struktur file konsisten.
- README atau catatan setup tersedia.

### Issue 0.3 - Install UI Dependencies

Scope:
- Tambahkan dependency React-lua/ReactRoblox sesuai stack yang dipakai.
- Tambahkan dependency TopbarPlus v3.
- Mount root React dari client script.

Acceptance criteria:
- React root berhasil mount ke `PlayerGui`.
- Tombol TopbarPlus `Catalog` muncul di topbar.
- Klik tombol `Catalog` membuka/menutup `ScreenGui` catalog.
- Unmount aman saat script reload.
- Tidak ada UI catalog dulu, cukup empty root/smoke test.

### Issue 0.4 - Topbar Catalog Toggle Shell

Scope:
- Buat `CatalogTopbarController`.
- Default `ScreenGui.Enabled = false`.
- TopbarPlus icon label: `Catalog`.
- Toggle icon selected/deselected untuk show/hide UI.

Acceptance criteria:
- Catalog UI bisa dicek langsung di Studio melalui topbar.
- Controller tidak berisi logic item catalog, preview, purchase, atau server apply.
- Destroy/unmount membersihkan icon TopbarPlus dan ScreenGui.

## Milestone 1 - UI Design System

Tujuan: membangun fondasi visual sebelum membuat layar catalog.

### Issue 1.1 - Theme Tokens

Scope:
- Buat `Theme.luau`.
- Isi token color, font, text size, radius, spacing, dan gradient.

Acceptance criteria:
- Semua token utama dari guideline tersedia.
- Komponen UI tidak perlu hardcode warna utama.
- Token bisa dipakai lintas atom/molecule.

### Issue 1.2 - Icon Registry

Scope:
- Buat `Icons.luau`.
- Daftarkan icon untuk catalog, avatar, search, filter, clothing, accessories, body, faces, animation, bundles, dan robux.

Acceptance criteria:
- Semua icon dipanggil dari registry.
- Style icon konsisten.
- Tidak ada asset id tersebar acak di komponen.

### Issue 1.3 - Base UI Atoms

Scope:
- Buat atom:
  - `BaseFrame`
  - `Text`
  - `Icon`
  - `Spacer`

Acceptance criteria:
- Atom menerima props dasar.
- Font, color, radius, dan padding menggunakan `Theme`.
- Atom bisa dipakai untuk membangun button/card.

### Issue 1.4 - Button Atoms

Scope:
- Buat:
  - `ButtonBase`
  - `GradientButton`
  - `IconButton`

Acceptance criteria:
- Button punya state default, hover, pressed, selected, disabled.
- `GradientButton` cocok untuk tombol `Try On`.
- `IconButton` cocok untuk tombol filter.

## Milestone 2 - Static Catalog UI

Tujuan: membuat tampilan catalog sesuai screenshot dengan mock data, tanpa logic avatar.

### Issue 2.1 - Header Tabs

Scope:
- Buat `HeaderTabButton`.
- Buat `HeaderTabs`.
- Tab awal: `Item Catalog` aktif, `Avatar Loader` inactive.

Acceptance criteria:
- Tab aktif memakai gradient purple-magenta.
- Tab inactive memakai border putih/abu.
- Underline aktif muncul seperti referensi.

### Issue 2.2 - Search Toolbar

Scope:
- Buat `SearchInput`.
- Buat `SearchToolbar`.
- Tambahkan filter button di kanan.

Acceptance criteria:
- Search bar tinggi, padding, placeholder, dan border sesuai guideline.
- Filter button fixed size.
- Focus state tidak mengubah layout.

### Issue 2.3 - Category Tabs

Scope:
- Buat `CategoryButton`.
- Buat `MainCategoryTabs`.
- Kategori awal: Clothing, Accessories, Body, Faces, Animation, Bundles.

Acceptance criteria:
- Category selected state jelas.
- Icon dan label sejajar.
- Layout horizontal rapi di desktop.

### Issue 2.4 - Subcategory Chips

Scope:
- Buat `SubCategoryChip`.
- Buat `SubCategoryChips`.
- Subcategory awal untuk Clothing: Jackets, Pants, Classic Shirts, Classic Pants, Shoes, Hats.

Acceptance criteria:
- Chip aktif memakai background soft purple.
- Chip inactive tetap readable.
- Chip tidak mengubah tinggi layout ketika aktif.

### Issue 2.5 - Item Card

Scope:
- Buat:
  - `PriceRow`
  - `ItemCard`
- Gunakan mock item dari guideline.

Acceptance criteria:
- Card punya image area, item name, price row, dan `Try On` button.
- Nama item truncate satu baris.
- Harga selalu di atas button.
- Button align bawah agar semua card konsisten.

### Issue 2.6 - Catalog Grid

Scope:
- Buat `CatalogGrid`.
- Render mock data ke 3 kolom desktop.

Acceptance criteria:
- Grid 3 kolom di desktop.
- Gap horizontal dan vertical sesuai guideline.
- Card size konsisten.
- Scroll area siap jika item banyak.

### Issue 2.7 - Catalog Panel Composition

Scope:
- Buat `CatalogPanel`.
- Susun header tabs, search toolbar, category tabs, chips, dan grid.

Acceptance criteria:
- Panel kiri terlihat seperti screenshot.
- Padding panel konsisten.
- Corner radius dan border sesuai guideline.
- Tidak ada logic server/avatar di panel.

### Issue 2.8 - Catalog Screen Layout

Scope:
- Buat `CatalogScreen`.
- Tempatkan `CatalogPanel` di kiri.
- Area kanan dibiarkan transparan agar karakter aktif di world tetap terlihat.

Acceptance criteria:
- Panel tidak menutup karakter kanan.
- Background kanan tidak memakai `ViewportFrame`.
- Layout desktop match screenshot secara visual.

## Milestone 3 - UI Interaction And Responsive Polish

Tujuan: membuat UI terasa hidup dan nyaman dipakai sebelum masuk logic avatar.

### Issue 3.1 - UI State Controller

Scope:
- Tambahkan state:
  - active header tab
  - active category
  - active subcategory
  - search query
  - selected item id

Acceptance criteria:
- Klik category mengubah selected visual.
- Klik chip mengubah selected visual.
- Search query tersimpan di state.
- UI tetap pakai mock data.

### Issue 3.2 - Search Filtering Client Mock

Scope:
- Filter mock item berdasarkan search query, category, dan subcategory.

Acceptance criteria:
- Item grid berubah berdasarkan search.
- Empty state tersedia.
- Filtering tidak memanggil server.

### Issue 3.3 - Hover And Pressed Feedback

Scope:
- Tambahkan hover/pressed untuk button dan card.

Acceptance criteria:
- Button terasa responsif.
- Card hover punya border/shadow soft.
- Layout tidak loncat saat hover/pressed.

### Issue 3.4 - Responsive Layout

Scope:
- Tambahkan responsive rule:
  - desktop 3 kolom
  - medium 2 kolom
  - small 1 kolom atau compact
- Category/chip bisa horizontal scroll jika sempit.

Acceptance criteria:
- Text tidak overlap.
- Button tetap readable.
- Panel bisa dipakai di beberapa ukuran layar.

### Issue 3.5 - Visual QA Pass

Scope:
- Bandingkan dengan screenshot referensi.
- Rapikan ukuran, gap, radius, dan typography.

Acceptance criteria:
- Catalog panel sudah layak dianggap UI MVP.
- Semua text readable.
- Tidak ada clipping/overlap besar.
- Semua komponen mengambil style dari `Theme`.

## Milestone 4 - Client-Side Try On Preview

Tujuan: tombol `Try On` melakukan preview di karakter aktif player secara lokal, belum terlihat oleh orang lain.

### Issue 4.1 - Avatar Preview Architecture

Scope:
- Buat dokumen teknis singkat untuk preview aktif character.
- Tentukan module client:
  - `AvatarPreviewController`
  - `PreviewState`
  - `PreviewItemApplier`

Acceptance criteria:
- Preview tidak memakai `ViewportFrame`.
- Preview target adalah `Players.LocalPlayer.Character`.
- Batas client-only dan server apply jelas.

### Issue 4.2 - Local Preview State

Scope:
- Simpan daftar item yang sedang dicoba.
- Bedakan item original, preview item, dan applied item.

Acceptance criteria:
- Klik `Try On` memilih item untuk preview.
- State preview bisa di-clear.
- UI bisa menampilkan selected/previewed item.

### Issue 4.3 - Client-Only Visual Apply

Scope:
- Terapkan item visual ke karakter lokal di client.
- Jangan kirim remote event saat `Try On`.

Acceptance criteria:
- Player lokal melihat item preview di karakter aktif.
- Player lain belum melihat perubahan.
- Preview bisa diganti tanpa menumpuk duplicate item.

### Issue 4.4 - Reset Preview

Scope:
- Tambahkan tombol/aksi reset preview.
- Kembalikan karakter lokal ke appearance sebelum preview.

Acceptance criteria:
- Semua item preview terhapus.
- Original appearance lokal kembali.
- Tidak ada instance preview tertinggal.

## Milestone 5 - Apply Flow And Server Validation

Tujuan: pilihan final bisa diterapkan ke server saat player klik `Apply`.

### Issue 5.1 - Apply Button UI

Scope:
- Tambahkan area action untuk `Apply` dan `Reset` bila ada preview aktif.
- Tentukan posisi tanpa merusak layout screenshot.

Acceptance criteria:
- `Apply` hanya muncul/aktif saat ada perubahan preview.
- `Reset` jelas dan tidak dominan.
- UI tetap clean.

### Issue 5.2 - Remote Contract

Scope:
- Buat remote event/function untuk apply.
- Definisikan payload item ids yang dipilih.

Acceptance criteria:
- Contract terdokumentasi.
- Client hanya mengirim id item final.
- Server tidak menerima asset mentah tanpa validasi.

### Issue 5.3 - Server Validation

Scope:
- Validasi item id dari catalog whitelist.
- Validasi category/subcategory yang didukung.
- Validasi ownership/purchase jika fitur sudah ada.

Acceptance criteria:
- Payload invalid ditolak.
- Server tidak percaya data client.
- Error bisa dikirim balik ke UI.

### Issue 5.4 - Server Appearance Apply

Scope:
- Terapkan item final ke karakter player di server.
- Pastikan perubahan terlihat ke player lain.

Acceptance criteria:
- Setelah `Apply`, item terlihat oleh semua player.
- Respawn behavior didefinisikan.
- Tidak ada duplicate accessory/clothing.

## Milestone 6 - Catalog Data Integration

Tujuan: mengganti mock data dengan data catalog asli.

### Issue 6.1 - Catalog Data Schema

Scope:
- Definisikan schema item:
  - id
  - name
  - price
  - image
  - asset id
  - category
  - subcategory
  - tags
  - availability

Acceptance criteria:
- Schema dipakai client dan server.
- UI masih bisa render dari schema yang sama.
- Mock data bisa diganti tanpa ubah komponen visual.

### Issue 6.2 - Catalog Provider Client

Scope:
- Buat provider/hook untuk memberi data ke UI.
- Awalnya bisa dari local module, nanti dari server/backend.

Acceptance criteria:
- UI tidak tahu sumber data.
- Loading, empty, dan error state tersedia.
- Search/filter tetap jalan.

### Issue 6.3 - Item Images

Scope:
- Hubungkan image asset katalog.
- Tambahkan fallback image.

Acceptance criteria:
- Semua card punya image.
- Image fit tanpa stretch.
- Missing image tidak merusak card.

## Milestone 7 - Avatar Loader Tab

Tujuan: tab `Avatar Loader` dibuat setelah catalog UI dan try-on MVP stabil.

### Issue 7.1 - Avatar Loader UI Shell

Scope:
- Buat screen/tab Avatar Loader.
- Gunakan style yang sama dengan catalog.

Acceptance criteria:
- Klik tab berpindah UI.
- Tab tetap satu sistem design.
- Belum perlu logic loader penuh.

### Issue 7.2 - Avatar Input Form

Scope:
- Tambahkan input username/user id.
- Tambahkan action button load.

Acceptance criteria:
- Form readable dan responsive.
- Error/empty state tersedia.
- Belum ada logic server berat di UI component.

### Issue 7.3 - Avatar Loader Logic

Scope:
- Ambil avatar target sesuai aturan Roblox/API yang dipakai.
- Terapkan ke preview client atau flow yang disepakati.

Acceptance criteria:
- Loader tidak merusak active character preview flow.
- Ada clear/reset.
- Error handled dengan baik.

## Milestone 8 - Purchase And Ownership

Tujuan: menambahkan flow pembelian/ownership setelah UI dan apply flow aman.

### Issue 8.1 - Ownership State

Scope:
- Tambahkan state owned/not owned.
- Bedakan tombol `Try On`, `Buy`, dan `Apply`.

Acceptance criteria:
- Owned item bisa di-apply.
- Not owned item bisa dicoba sesuai aturan.
- UI jelas tanpa terlalu ramai.

### Issue 8.2 - Purchase Prompt Flow

Scope:
- Integrasi MarketplaceService di layer service, bukan di komponen card.

Acceptance criteria:
- Prompt hanya muncul dari action yang valid.
- Error/cancel handled.
- UI update setelah purchase success.

### Issue 8.3 - Apply Requires Ownership

Scope:
- Server memastikan item yang di-apply memang owned/allowed.

Acceptance criteria:
- Client tidak bisa bypass ownership.
- Apply invalid ditolak.
- Feedback error tampil di UI.

## Milestone 9 - QA, Performance, And Release

Tujuan: merapikan sistem untuk siap dipakai.

### Issue 9.1 - UI Performance

Scope:
- Optimasi render grid.
- Pastikan list item banyak tidak lag parah.

Acceptance criteria:
- Scroll tetap smooth.
- Re-render tidak berlebihan.
- Komponen besar dipisah dengan rapi.

### Issue 9.2 - Character Preview Robustness

Scope:
- Test respawn.
- Test character belum load.
- Test reset dan apply berkali-kali.

Acceptance criteria:
- Tidak crash saat respawn.
- Preview bisa restore setelah character reload jika dibutuhkan.
- Tidak ada duplicate item.

### Issue 9.3 - End-To-End QA

Scope:
- Test flow:
  - open catalog
  - search/filter
  - try on client-only
  - reset
  - apply server-visible
  - respawn

Acceptance criteria:
- Semua flow utama lolos.
- Error state jelas.
- Tidak ada warning/error besar di output.

## Urutan Issue Yang Disarankan

1. Issue 0.1 - Setup Rojo Project Structure
2. Issue 0.2 - Setup Tooling
3. Issue 0.3 - Install UI Dependencies
4. Issue 0.4 - Topbar Catalog Toggle Shell
5. Issue 1.1 - Theme Tokens
6. Issue 1.2 - Icon Registry
7. Issue 1.3 - Base UI Atoms
8. Issue 1.4 - Button Atoms
9. Issue 2.1 - Header Tabs
10. Issue 2.2 - Search Toolbar
11. Issue 2.3 - Category Tabs
12. Issue 2.4 - Subcategory Chips
13. Issue 2.5 - Item Card
14. Issue 2.6 - Catalog Grid
15. Issue 2.7 - Catalog Panel Composition
16. Issue 2.8 - Catalog Screen Layout
17. Issue 3.1 - UI State Controller
18. Issue 3.2 - Search Filtering Client Mock
19. Issue 3.3 - Hover And Pressed Feedback
20. Issue 3.4 - Responsive Layout
21. Issue 3.5 - Visual QA Pass
22. Issue 4.1 - Avatar Preview Architecture
23. Issue 4.2 - Local Preview State
24. Issue 4.3 - Client-Only Visual Apply
25. Issue 4.4 - Reset Preview
26. Issue 5.1 - Apply Button UI
27. Issue 5.2 - Remote Contract
28. Issue 5.3 - Server Validation
29. Issue 5.4 - Server Appearance Apply

## MVP Definition

MVP awal dianggap selesai jika:

- Catalog panel sudah mirip screenshot.
- Tombol TopbarPlus `Catalog` bisa membuka/menutup UI.
- UI memakai mock data.
- Search/category/chip/filter visual sudah ada.
- Item card dan grid rapi.
- Karakter aktif di kanan tetap terlihat di world.
- Klik `Try On` bisa preview client-side di karakter lokal.
- Klik `Apply` bisa membuat pilihan final terlihat oleh player lain.

## Catatan Untuk Pembuatan GitHub Issues

Label yang disarankan:
- `type: ui`
- `type: client`
- `type: server`
- `type: data`
- `priority: p0`
- `priority: p1`
- `milestone: foundation`
- `milestone: ui`
- `milestone: preview`
- `milestone: apply`

Prioritas awal:
- P0: Milestone 0 sampai Milestone 3.
- P1: Milestone 4 dan Milestone 5.
- P2: Milestone 6 sampai Milestone 9.
