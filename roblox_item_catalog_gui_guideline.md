# Pedoman GUI Roblox — Item Catalog & Avatar Loader

Dokumen ini fokus **hanya pada struktur GUI/client UI** untuk membuat tampilan seperti referensi: panel katalog item di kiri dan preview avatar di kanan. Logic server, pembelian item, data catalog dari backend, validasi ownership, dan avatar loading runtime sengaja tidak dibahas.

Target stack:
- Roblox Studio + Rojo `rojo-rbx/rojo@7.7.0-rc.1`
- React-lua / React Luau untuk komponen UI
- TopbarPlus v3 untuk tombol topbar `Catalog`
- StyLua untuk formatting
- Struktur komponen modular, reusable, dan mudah di-skinning

---

## 1. Ringkasan Visual UI

UI terdiri dari dua area besar:

1. **Catalog Panel / Main Panel**
   - Panel putih besar di sisi kiri.
   - Berisi header tab, search bar, filter button, kategori, subkategori, dan grid item.
   - Look & feel: modern, clean, rounded, soft shadow, warna aksen ungu-magenta.

2. **Avatar Preview Area**
   - Area kanan berisi karakter aktif player di world Roblox asli.
   - Area ini bukan `ViewportFrame`; catalog panel harus transparan terhadap world kanan.
   - Preview item dilakukan client-side pada `Players.LocalPlayer.Character`.
   - Perubahan baru terlihat oleh player lain setelah user klik `Apply` dan server memvalidasi pilihan final.

3. **Topbar Entry**
   - UI catalog dibuka dan ditutup melalui tombol TopbarPlus bernama `Catalog`.
   - `ScreenGui` catalog default hidden agar progress UI bisa dicek langsung lewat tombol topbar.
   - Tombol topbar dibuat di client controller, bukan di komponen presentational catalog.

---

## 2. Design Tokens

Gunakan token supaya UI konsisten dan mudah diubah.

### 2.1 Warna

| Token | Hex | Penggunaan |
|---|---:|---|
| `Color.Background` | `#EEF2F7` | Background umum / fallback |
| `Color.Panel` | `#FFFFFF` | Main panel, card, input |
| `Color.PanelSoft` | `#FAFAFC` | Area input/card sangat soft |
| `Color.Border` | `#E6E8EF` | Border card, input, inactive tab |
| `Color.BorderStrong` | `#D8DCE6` | Border lebih jelas |
| `Color.TextPrimary` | `#1F2430` | Judul item, tab aktif/nonaktif utama |
| `Color.TextSecondary` | `#626A78` | Placeholder, label tambahan |
| `Color.TextMuted` | `#9AA1AD` | Placeholder lebih soft |
| `Color.Purple` | `#A744EA` | Aksen utama |
| `Color.Magenta` | `#F7199A` | Aksen gradient akhir |
| `Color.ActiveSoft` | `#F7EAFE` | Background chip aktif |
| `Color.IconDark` | `#4E5562` | Icon nonaktif |
| `Color.Success` | `#2DBE7F` | Optional state sukses |
| `Color.Danger` | `#EF4444` | Optional state error |

Gradient utama:
- Start: `#A744EA`
- End: `#F7199A`
- Digunakan pada active main tab, primary button, dan underline aktif.

Di Roblox:
```lua
local Theme = {
	Color = {
		Panel = Color3.fromRGB(255, 255, 255),
		Border = Color3.fromRGB(230, 232, 239),
		TextPrimary = Color3.fromRGB(31, 36, 48),
		TextSecondary = Color3.fromRGB(98, 106, 120),
		TextMuted = Color3.fromRGB(154, 161, 173),
		Purple = Color3.fromRGB(167, 68, 234),
		Magenta = Color3.fromRGB(247, 25, 154),
		ActiveSoft = Color3.fromRGB(247, 234, 254),
	}
}
```

### 2.2 Typography

Pakai font yang konsisten. Untuk Roblox, rekomendasi aman:
- Default: `Enum.Font.GothamSSm`
- SemiBold/Bold: `Enum.Font.GothamSSmBold`

Ukuran font disesuaikan dengan UI/UX umum Roblox desktop dan tetap nyaman di layar 13–15 inch.

| Token | TextSize | Weight | Penggunaan |
|---|---:|---|---|
| `Text.Caption` | `12` | Medium | Label kecil, metadata minor |
| `Text.Small` | `13` | Medium | Chip kecil, helper text |
| `Text.Body` | `14` | Medium | Label normal, placeholder |
| `Text.BodyStrong` | `15` | SemiBold | Nama sub kategori, label aktif |
| `Text.Button` | `15` | Bold | Text button `Try On` |
| `Text.CardTitle` | `16` | Bold | Nama item di card |
| `Text.Price` | `17` | Bold | Harga Robux |
| `Text.Tab` | `16` | Bold | Header tab dan kategori utama |
| `Text.ScreenTitle` | `18` | Bold | Optional title screen |

Batas penting:
- Jangan pakai text di bawah `12` untuk elemen interaktif.
- Button dan tab idealnya `15–16`.
- Judul item card idealnya `16`.
- Harga idealnya `17` supaya mudah discan.
- Minimum touch target: `44px` tinggi/lebar.

### 2.3 Radius

| Token | Radius | Penggunaan |
|---|---:|---|
| `Radius.XS` | `6` | Icon kecil, badge |
| `Radius.SM` | `8` | Button kecil |
| `Radius.MD` | `12` | Chip, category button |
| `Radius.LG` | `14` | Card item |
| `Radius.XL` | `16` | Search input, tab container |
| `Radius.Panel` | `18` | Main panel |

### 2.4 Spacing

Gunakan kelipatan 4/8.

| Token | Size | Penggunaan |
|---|---:|---|
| `Space.XXS` | `4` | Jarak icon-text kecil |
| `Space.XS` | `8` | Padding kecil |
| `Space.SM` | `12` | Gap antar komponen kecil |
| `Space.MD` | `16` | Gap standar |
| `Space.LG` | `20` | Padding panel/card |
| `Space.XL` | `24` | Padding utama panel |
| `Space.XXL` | `32` | Gap section besar |

### 2.5 Shadow / Elevation

Roblox tidak punya native shadow fleksibel seperti web. Pakai salah satu:
1. `ImageLabel` shadow 9-slice di belakang frame.
2. Border + background soft tanpa shadow berat.
3. Shadow tipis hanya pada panel dan card.

Rekomendasi:
- Main panel: shadow soft, opacity rendah.
- Card: shadow sangat ringan, jangan terlalu gelap.
- Button: tidak perlu shadow, cukup gradient.

---

## 3. Layout Berdasarkan Referensi

Ukuran gambar referensi: `1456 x 819`.

### 3.1 Root Layout

```txt
ScreenGui
└── AppRoot
    ├── CatalogPanel              // kiri
    └── WorldPreviewSpace         // kanan, world Roblox asli
```

Rekomendasi ukuran desktop:
- `CatalogPanel`
  - Width: sekitar `858px`
  - Height: `calc(100% - 8px)` atau sekitar `814px`
  - Position: kiri dengan margin `72px` dari kiri pada referensi
  - Corner radius: `18`
- `AvatarPreviewArea`
  - Mengisi sisa layar kanan
  - Berupa ruang world asli yang tidak ditutup UI
  - Tidak menggunakan `ViewportFrame`

Untuk responsive:
- Jika layar besar: panel fixed width `840–880px`.
- Jika layar medium: panel width `60–65%`.
- Jika mobile/layar kecil: panel boleh full-screen dan avatar preview disembunyikan/menjadi tab terpisah.

---

## 4. Hierarki Komponen Besar

```txt
CatalogScreen
├── CatalogPanel
│   ├── HeaderTabs
│   │   ├── HeaderTabButton: Item Catalog
│   │   │   ├── TabIcon
│   │   │   └── TabText
│   │   ├── HeaderTabButton: Avatar Loader
│   │   │   ├── TabIcon
│   │   │   └── TabText
│   │   └── ActiveUnderline
│   ├── SearchToolbar
│   │   ├── SearchInput
│   │   │   ├── SearchIcon
│   │   │   └── PlaceholderText / TextBox
│   │   └── FilterButton
│   │       └── FilterIcon
│   ├── MainCategoryTabs
│   │   ├── CategoryButton: Clothing
│   │   ├── CategoryButton: Accessories
│   │   ├── CategoryButton: Body
│   │   ├── CategoryButton: Faces
│   │   ├── CategoryButton: Animation
│   │   └── CategoryButton: Bundles
│   ├── SubCategoryChips
│   │   ├── SubCategoryChip: Jackets
│   │   ├── SubCategoryChip: Pants
│   │   ├── SubCategoryChip: Classic Shirts
│   │   ├── SubCategoryChip: Classic Pants
│   │   ├── SubCategoryChip: Shoes
│   │   └── SubCategoryChip: Hats
│   └── CatalogGrid
│       ├── ItemCard
│       │   ├── ItemImageContainer
│       │   │   └── ItemImage
│       │   ├── ItemName
│       │   ├── PriceRow
│       │   │   ├── RobuxIcon
│       │   │   └── PriceText
│       │   └── TryOnButton
│       │       └── ButtonText
│       └── ...
└── AvatarPreviewArea
    └── ActiveCharacterInWorld
```

---

## 5. Komponen Atom / Terkecil

### 5.1 `BaseFrame`

Wrapper frame standar untuk background, radius, stroke, padding.

Props:
```lua
export type BaseFrameProps = {
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	backgroundColor: Color3?,
	backgroundTransparency: number?,
	cornerRadius: number?,
	strokeColor: Color3?,
	strokeThickness: number?,
	padding: number?,
	layoutOrder: number?,
	children: any?,
}
```

Default:
- Background: `Theme.Color.Panel`
- Radius: `Theme.Radius.MD`
- Border: optional

Dipakai oleh:
- Panel
- Card
- Input
- Button container
- Chip

---

### 5.2 `Text`

Komponen text wrapper agar font dan warna konsisten.

Props:
```lua
export type TextProps = {
	text: string,
	textSize: number?,
	font: Enum.Font?,
	color: Color3?,
	textXAlignment: Enum.TextXAlignment?,
	textYAlignment: Enum.TextYAlignment?,
	textTruncate: Enum.TextTruncate?,
	size: UDim2?,
	automaticSize: Enum.AutomaticSize?,
	layoutOrder: number?,
}
```

Default:
- Font: `GothamSSm`
- TextColor: `TextPrimary`
- BackgroundTransparency: `1`
- TextWrapped: `false`
- TextTruncate: `AtEnd`

---

### 5.3 `Icon`

Komponen untuk render icon.

Props:
```lua
export type IconProps = {
	image: string,
	size: number?,
	color: Color3?,
	transparency: number?,
	layoutOrder: number?,
}
```

Default:
- Size: `20x20`
- Color: sesuai state parent
- BackgroundTransparency: `1`

Catatan:
- Icon di screenshot dipakai untuk shopping bag, avatar/person, search, sliders/filter, clothing, accessories, body, faces, animation, bundles, robux.
- Gunakan satu icon set yang konsisten.
- Jangan campur style icon filled dan outline terlalu banyak.

---

## 6. Komponen Button

### 6.1 `ButtonBase`

Komponen dasar semua button.

Props:
```lua
export type ButtonBaseProps = {
	text: string?,
	icon: string?,
	size: UDim2?,
	minHeight: number?,
	variant: "primary" | "secondary" | "ghost" | "chip" | "tab",
	selected: boolean?,
	disabled: boolean?,
	onActivated: (() -> ())?,
	layoutOrder: number?,
	children: any?,
}
```

State visual:
- `default`
- `hover`
- `pressed`
- `selected`
- `disabled`

Sizing:
- Minimum height: `44`
- Button kecil/chip: `38–42`, tapi touch target tetap usahakan `44`
- Primary button card: `34–36` karena berada dalam card desktop, tapi untuk mobile naikkan ke `40–44`

---

### 6.2 `GradientButton`

Dipakai untuk tombol `Try On`.

Struktur:
```txt
GradientButton
├── UICorner
├── UIGradient
└── TextLabel
```

Style:
- Height: `34`
- Width: full card minus padding
- Radius: `8`
- Gradient: Purple → Magenta
- Text: `Try On`, size `15`, bold, putih
- Padding horizontal: `12`

Interaksi:
- Hover: brightness naik sedikit.
- Pressed: scale turun `0.98` atau transparency naik tipis.
- Disabled: pakai grey, tidak pakai gradient aktif.

---

### 6.3 `IconButton`

Dipakai untuk filter button di kanan search.

Style:
- Size: `52 x 52`
- Radius: `14`
- Background: white/pink soft
- Border: `#E9D7F5`
- Icon: purple/magenta, size `22`
- Minimum touch target sudah aman.

Struktur:
```txt
IconButton
└── Icon
```

---

### 6.4 `HeaderTabButton`

Dipakai pada `Item Catalog` dan `Avatar Loader`.

Style active:
- Size: sekitar `274 x 51`
- Radius: `12`
- Background: gradient Purple → Magenta
- Text: putih, `16`, bold
- Icon: putih, `22`
- Underline bawah: `3px`, gradient, terletak di bawah segmented tab

Style inactive:
- Background: white
- Border: `#E6E8EF`
- Text: `TextPrimary`, `16`, bold
- Icon: grey/dark
- No underline

Struktur:
```txt
HeaderTabButton
├── UIGradient?        // hanya active
├── UICorner
├── UIListLayout Horizontal
├── Icon
└── Text
```

---

### 6.5 `CategoryButton`

Dipakai kategori utama: Clothing, Accessories, Body, Faces, Animation, Bundles.

Style active:
- Height: `48`
- Width: content-based, minimal `128`
- Radius: `12`
- Background: putih / very soft active
- Border: purple
- Icon: purple
- Text: purple, `15`, bold

Style inactive:
- Height: `48`
- Border: `#E6E8EF`
- Icon: `IconDark`
- Text: `TextPrimary`, `15`, bold

Spacing:
- Gap antar category: `14–16`
- Padding horizontal: `18`

---

### 6.6 `SubCategoryChip`

Dipakai sub kategori: Jackets, Pants, Classic Shirts, Classic Pants, Shoes, Hats.

Style active:
- Height: `38`
- Radius: `12`
- Background: `ActiveSoft`
- Border: `#ECD7FA`
- Text: purple, `14`, bold

Style inactive:
- Height: `38`
- Background: putih
- Border: `#E6E8EF`
- Text: `TextPrimary`, `13–14`, semibold

Padding:
- Horizontal `18`
- Gap antar chip `12`

---

## 7. Search Toolbar

### 7.1 `SearchToolbar`

Layout:
```txt
SearchToolbar
├── SearchInput       // flex full
└── FilterButton      // fixed 52px
```

Sizing:
- Height: `52`
- Search input width: fill remaining
- Gap: `24–28` pada referensi terlihat cukup lega
- Margin top setelah header: `16`
- Margin bottom sebelum kategori: `18`

---

### 7.2 `SearchInput`

Struktur:
```txt
SearchInput
├── UICorner
├── UIStroke
├── UIPadding
├── SearchIcon
└── TextBox
```

Style:
- Height: `52`
- Radius: `14–16`
- Background: white
- Border: `#E6E8EF`
- Icon size: `24`
- Placeholder: `Search items...`
- Placeholder color: `TextMuted`
- TextSize: `15`
- Font: `GothamSSm`
- Padding left/right: `16`

UX:
- Saat focus: border berubah ke purple soft.
- Saat ada query: tampilkan optional clear button di kanan.
- Jangan ubah tinggi input ketika focus.

---

## 8. Catalog Grid

### 8.1 `CatalogGrid`

Layout:
- 3 kolom pada desktop.
- Gap horizontal: `16–18`
- Gap vertical: `14–16`
- Card size referensi: sekitar `248 x 252`
- Pakai `UIGridLayout`

Rekomendasi:
```lua
CellSize = UDim2.fromOffset(248, 252)
CellPadding = UDim2.fromOffset(18, 14)
FillDirectionMaxCells = 3
SortOrder = Enum.SortOrder.LayoutOrder
```

Responsive:
- Width panel >= 820: 3 kolom
- Width panel 580–819: 2 kolom
- Width panel < 580: 1 kolom

---

### 8.2 `ItemCard`

Struktur:
```txt
ItemCard
├── CardBackground
│   ├── UICorner
│   ├── UIStroke
│   ├── UIPadding
│   ├── ItemImageContainer
│   │   └── ItemImage
│   ├── ItemName
│   ├── PriceRow
│   │   ├── RobuxIcon
│   │   └── PriceText
│   └── TryOnButton
```

Style:
- Width: `248`
- Height: `252`
- Radius: `14`
- Background: white
- Border: `#E6E8EF`
- Padding: `12`
- Optional shadow very soft

Important:
- Image area harus konsisten agar grid rapi.
- Nama item max 1 line, truncate di akhir.
- Harga selalu berada sebelum button.
- Button selalu align di bawah supaya card konsisten.

---

### 8.3 `ItemImageContainer`

Style:
- Height: `130–136`
- Width: full
- Background: transparent / very soft
- Image fit: contain
- Tidak perlu border.
- Padding dalam: `4–8`

Image:
- `ScaleType = Enum.ScaleType.Fit`
- BackgroundTransparency `1`
- Anchor center

---

### 8.4 `ItemName`

Style:
- TextSize: `16`
- Font: `GothamSSmBold`
- Color: `TextPrimary`
- Height: `22`
- TextXAlignment: left
- Truncate: `AtEnd`

Contoh:
- Black Puffer Jacket
- Pastel Purple Hoodie
- Denim Jacket – Light Wash

---

### 8.5 `PriceRow`

Struktur:
```txt
PriceRow
├── RobuxIcon
└── PriceText
```

Style:
- Height: `24`
- Gap icon-text: `6`
- Robux icon: `20 x 20`
- Price text: `17`, bold
- Color: `TextPrimary`

---

## 9. Active Character Preview Area

Preview avatar memakai karakter aktif player di world, bukan `ViewportFrame`.

### 9.1 `AvatarPreviewArea`

Struktur:
```txt
AvatarPreviewArea
└── ActiveCharacterInWorld
```

Style:
- Fill sisa layar kanan.
- Background transparent agar world Roblox asli terlihat.
- Character center kanan.
- Tidak menutupi CatalogPanel.

Catatan:
- Jangan taruh logic `HumanoidDescription`, insert asset, purchase, atau server call di komponen visual ini.
- Jangan membuat `ViewportFrame` untuk avatar preview.
- `Try On` nantinya hanya mengubah karakter lokal di client.
- `Apply` adalah aksi pertama yang boleh mengirim pilihan final ke server.
- Komponen ini cukup menerima prop:
```lua
export type AvatarPreviewProps = {
	visible: boolean?,
	children: any?,
}
```

### 9.2 TopbarPlus Catalog Button

Catalog UI harus memiliki entry point dari TopbarPlus.

Struktur client:
```txt
App.client.luau
├── mount React ScreenGui
└── CatalogTopbarController
    └── TopbarPlus Icon: Catalog
```

Behavior:
- `ScreenGui.Enabled = false` saat startup.
- Klik `Catalog` di topbar memilih icon dan menampilkan catalog UI.
- Klik lagi deselect icon dan menyembunyikan catalog UI.
- Controller topbar hanya mengatur visibility shell.
- State catalog, filter, preview, dan apply tetap berada di module masing-masing.

---

## 10. Struktur Folder Rojo

Rekomendasi struktur project fokus UI:

```txt
project/
├── default.project.json
├── stylua.toml
├── src/
│   ├── client/
│   │   ├── App.client.luau
│   │   └── ui/
│   │       ├── App.luau
│   │       ├── theme/
│   │       │   ├── Theme.luau
│   │       │   └── Icons.luau
│   │       ├── atoms/
│   │       │   ├── BaseFrame.luau
│   │       │   ├── Text.luau
│   │       │   ├── Icon.luau
│   │       │   ├── ButtonBase.luau
│   │       │   ├── GradientButton.luau
│   │       │   ├── IconButton.luau
│   │       │   └── Spacer.luau
│   │       ├── molecules/
│   │       │   ├── HeaderTabButton.luau
│   │       │   ├── CategoryButton.luau
│   │       │   ├── SubCategoryChip.luau
│   │       │   ├── SearchInput.luau
│   │       │   ├── SearchToolbar.luau
│   │       │   ├── PriceRow.luau
│   │       │   └── ItemCard.luau
│   │       ├── organisms/
│   │       │   ├── HeaderTabs.luau
│   │       │   ├── MainCategoryTabs.luau
│   │       │   ├── SubCategoryChips.luau
│   │       │   ├── CatalogGrid.luau
│   │       │   ├── CatalogPanel.luau
│   │       │   └── AvatarPreviewArea.luau
│   │       └── screens/
│   │           └── CatalogScreen.luau
│   └── shared/
│       └── types/
│           └── CatalogTypes.luau
└── Packages/
    └── ...
```

Catatan:
- `atoms`: komponen paling kecil dan reusable.
- `molecules`: gabungan beberapa atoms.
- `organisms`: section besar.
- `screens`: komposisi final screen.

---

## 11. Contoh `default.project.json`

```json
{
  "name": "ItemCatalogGui",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Packages": {
        "$path": "Packages"
      },
      "Shared": {
        "$path": "src/shared"
      }
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "Client": {
          "$path": "src/client"
        }
      }
    }
  }
}
```

---

## 12. Contoh `stylua.toml`

```toml
column_width = 100
line_endings = "Unix"
indent_type = "Tabs"
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
collapse_simple_statement = "Never"
```

Guideline formatting:
- Satu komponen per file.
- Nama file PascalCase untuk komponen: `ItemCard.luau`.
- Props type di atas function.
- Return JSX-style React element / `React.createElement` dibuat rapi.
- Hindari inline angka magic terlalu banyak; ambil dari `Theme`.

---

## 13. Data Props UI Saja

Contoh type data item untuk UI mock/client:

```lua
export type CatalogItem = {
	id: string,
	name: string,
	price: number,
	image: string,
	category: string,
	subcategory: string,
}
```

Untuk UI-only, data bisa hardcoded/mock dulu:

```lua
local MOCK_ITEMS = {
	{
		id = "black-puffer-jacket",
		name = "Black Puffer Jacket",
		price = 75,
		image = "rbxassetid://0",
		category = "Clothing",
		subcategory = "Jackets",
	},
}
```

Jangan masukkan:
- Purchase logic
- MarketplaceService call
- RemoteEvent
- Server validation
- HumanoidDescription loader
- Asset insertion logic

---

## 14. State UI yang Dibutuhkan

State visual minimal:
```lua
type CatalogUiState = {
	activeHeaderTab: "ItemCatalog" | "AvatarLoader",
	activeCategory: string,
	activeSubcategory: string,
	searchQuery: string,
	hoveredItemId: string?,
	selectedItemId: string?,
}
```

State ini cukup untuk visual:
- Tab aktif
- Kategori aktif
- Search text
- Hover/pressed visual
- Selected item optional

Jangan campur dengan:
- Inventory ownership
- Payment state server
- Avatar asset apply state
- Backend loading

---

## 15. Ukuran Komponen Detail

### 15.1 Main Panel

| Properti | Nilai |
|---|---:|
| Width desktop | `858–860` |
| Height desktop | `814` atau `100% - 8` |
| Padding | `24` kiri-kanan |
| Radius | `18` |
| Background | White |
| Border | `#E8EAF0`, thickness `1` |

### 15.2 Header Tabs

| Properti | Nilai |
|---|---:|
| Container height | `64` termasuk underline |
| Button height | `51–52` |
| Button width | `274–276` |
| Gap | `0–2` jika segmented, atau `8–12` jika dipisah |
| TextSize | `16` |
| Icon | `22` |
| Underline height | `3` |

### 15.3 Search Toolbar

| Properti | Nilai |
|---|---:|
| Height | `52` |
| Search radius | `15` |
| Filter size | `52 x 52` |
| Gap search-filter | `24` |
| TextSize | `15` |
| Icon search | `24` |
| Icon filter | `22` |

### 15.4 Main Category

| Properti | Nilai |
|---|---:|
| Height | `48` |
| Radius | `12` |
| Padding X | `18` |
| Gap | `14` |
| TextSize | `15` |
| Icon | `20–22` |

### 15.5 Subcategory Chip

| Properti | Nilai |
|---|---:|
| Height | `38` |
| Radius | `12` |
| Padding X | `18` |
| Gap | `12` |
| TextSize | `13–14` |

### 15.6 Item Card

| Properti | Nilai |
|---|---:|
| Width | `248` |
| Height | `252` |
| Padding | `12` |
| Radius | `14` |
| Image area height | `132` |
| Item name TextSize | `16` |
| Price TextSize | `17` |
| Button height | `34–36` |
| Button TextSize | `15` |

---

## 16. Responsive Rules

### Desktop / PC

- Panel kiri fixed `840–880px`.
- Grid 3 kolom.
- Avatar preview kanan selalu visible.
- Font pakai token normal.

### Tablet / Medium

- Panel width `65–72%`.
- Grid 2 kolom jika panel terlalu sempit.
- Header tabs tetap horizontal.
- Category bisa horizontal scrolling.

### Mobile / Small

- Panel full screen.
- Avatar preview disembunyikan atau pindah ke tab `Avatar Loader`.
- Grid 1 kolom atau 2 kolom compact.
- Button height minimum `44`.
- Search filter button tetap `48–52`.

---

## 17. Perilaku Visual Interaktif

### Hover

Untuk PC:
- Button hover: background sedikit lebih terang.
- Card hover: border purple soft dan naikkan shadow tipis.
- Item image tidak perlu zoom berlebihan; cukup 1–2% scale jika mau.

### Pressed

- Button pressed: scale `0.98`.
- Transparency naik `0.05`.
- Jangan ubah layout size permanen agar tidak bikin grid loncat.

### Selected

- Category selected: purple border, icon/text purple.
- Chip selected: purple soft background.
- Header tab selected: gradient background + underline.

### Disabled

- Opacity `0.45`.
- Text grey.
- Tidak menerima click.

---

## 18. Komposisi React-lua

Contoh pola komponen:

```lua
local React = require(path.to.React)
local Theme = require(script.Parent.Parent.theme.Theme)

export type GradientButtonProps = {
	text: string,
	onActivated: (() -> ())?,
	layoutOrder: number?,
	disabled: boolean?,
}

local function GradientButton(props: GradientButtonProps)
	return React.createElement("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = props.layoutOrder,
		AutoButtonColor = false,
		Text = props.text,
		TextSize = Theme.Text.Button,
		Font = Theme.Font.Bold,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundColor3 = Theme.Color.Purple,
		[React.Event.Activated] = if props.disabled then nil else props.onActivated,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, Theme.Radius.SM),
		}),
		Gradient = React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.Color.Purple),
				ColorSequenceKeypoint.new(1, Theme.Color.Magenta),
			}),
		}),
	})
end

return GradientButton
```

Catatan:
- Ini contoh UI-only.
- Event `onActivated` boleh diteruskan ke parent, tapi jangan taruh logic server di button.
- Button visual bisa dikembangkan dengan hover/pressed hook.

---

## 19. Contoh Theme Module

```lua
local Theme = {}

Theme.Color = {
	Panel = Color3.fromRGB(255, 255, 255),
	PanelSoft = Color3.fromRGB(250, 250, 252),
	Border = Color3.fromRGB(230, 232, 239),
	TextPrimary = Color3.fromRGB(31, 36, 48),
	TextSecondary = Color3.fromRGB(98, 106, 120),
	TextMuted = Color3.fromRGB(154, 161, 173),
	Purple = Color3.fromRGB(167, 68, 234),
	Magenta = Color3.fromRGB(247, 25, 154),
	ActiveSoft = Color3.fromRGB(247, 234, 254),
	IconDark = Color3.fromRGB(78, 85, 98),
}

Theme.Font = {
	Regular = Enum.Font.GothamSSm,
	Medium = Enum.Font.GothamSSmMedium,
	Bold = Enum.Font.GothamSSmBold,
}

Theme.Text = {
	Caption = 12,
	Small = 13,
	Body = 14,
	BodyStrong = 15,
	Button = 15,
	CardTitle = 16,
	Price = 17,
	Tab = 16,
	ScreenTitle = 18,
}

Theme.Radius = {
	XS = 6,
	SM = 8,
	MD = 12,
	LG = 14,
	XL = 16,
	Panel = 18,
}

Theme.Space = {
	XXS = 4,
	XS = 8,
	SM = 12,
	MD = 16,
	LG = 20,
	XL = 24,
	XXL = 32,
}

return Theme
```

---

## 20. Checklist Implementasi

Urutan yang disarankan:

1. Buat `Theme.luau`.
2. Buat atom:
   - `BaseFrame`
   - `Text`
   - `Icon`
   - `ButtonBase`
   - `GradientButton`
   - `IconButton`
3. Buat molecule:
   - `HeaderTabButton`
   - `CategoryButton`
   - `SubCategoryChip`
   - `SearchInput`
   - `SearchToolbar`
   - `PriceRow`
   - `ItemCard`
4. Buat organism:
   - `HeaderTabs`
   - `MainCategoryTabs`
   - `SubCategoryChips`
   - `CatalogGrid`
   - `CatalogPanel`
   - `AvatarPreviewArea`
5. Buat screen:
   - `CatalogScreen`
6. Masukkan mock data item.
7. Pastikan grid dan ukuran card sudah sama.
8. Tambahkan responsive rule.
9. Baru tambahkan integrasi logic server di tahap berikutnya, di luar komponen presentational.

---

## 21. Acceptance Criteria UI

UI dianggap sesuai referensi jika:

- Panel kiri terlihat clean, putih, rounded, dan proporsional.
- Header tab active memakai gradient ungu-magenta.
- Search bar tinggi dan padding-nya nyaman.
- Kategori utama dan subkategori punya selected state jelas.
- Grid item 3 kolom pada desktop.
- Card punya ukuran konsisten, image center, nama item, harga, dan tombol `Try On`.
- Text tidak terlalu kecil; semua button readable.
- Minimum touch target mayoritas elemen interaktif minimal `44px`.
- Tidak ada logic server/purchase/avatar loading di komponen GUI.
- Semua ukuran, warna, dan font diambil dari `Theme`, bukan magic number tersebar.

---

## 22. Catatan Akhir

Kunci UI ini adalah konsistensi:
- Satu gradient utama.
- Satu sistem spacing.
- Satu sistem font.
- Semua button punya state yang sama.
- Komponen kecil reusable, bukan copy-paste per section.

Untuk fase awal, prioritaskan pixel-feel:
1. Panel dan grid harus presisi.
2. Card harus rapi.
3. Button dan tab harus terasa modern.
4. Baru setelah itu tambahkan animasi hover/pressed.
