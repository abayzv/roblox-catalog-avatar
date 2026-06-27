# Roblox UI Layout Guide

Panduan ini adalah pola umum untuk membuat UI Roblox yang stabil di PC dan HP landscape. Tujuannya supaya saat bikin frame baru seperti catalog, inventory, shop, settings, avatar editor, admin panel, atau modal tool, layout tidak mudah rusak karena scale, scroll, stroke, viewport, atau input kamera.

Guide ini sengaja dibuat general. Contoh file catalog di project ini bisa dipakai sebagai referensi implementasi, tapi pattern-nya tidak khusus untuk catalog.

## Mental Model

Roblox UI punya dua ukuran yang perlu dipisahkan:

1. **Area size**: ruang nyata di layar, biasanya pakai scale.
2. **Content design size**: ukuran desain internal yang dipakai komponen, biasanya memakai offset lalu diskalakan dengan `UIScale`.

Rule utama:

- Layout besar pakai `Scale`.
- Detail komponen pakai ukuran desain yang konsisten.
- Jika desain perlu mengecil di HP, scale isi komponen, bukan mengubah struktur layout secara drastis.
- Kalau sebuah child sudah kena `UIScale`, semua perhitungan berbasis `AbsoluteSize` harus mempertimbangkan scale itu.

## Root Screen

Root screen selalu isi layar.

```lua
React.createElement("Frame", {
	Name = "ScreenRoot",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
}, children)
```

Untuk `ScreenGui`:

```lua
screenGui.IgnoreGuiInset = false
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
```

Catatan:

- `IgnoreGuiInset = false` adalah default aman untuk UI yang hidup bersama Roblox topbar.
- Gunakan `true` hanya kalau memang mau menggambar sampai area topbar/notch dan sudah handle padding sendiri.

## Split Area Layout

Untuk UI dengan panel kiri dan preview kanan, atau main panel dan side panel, bagi area dengan scale.

```lua
local LEFT_WIDTH_SCALE = 0.68
local RIGHT_WIDTH_SCALE = 1 - LEFT_WIDTH_SCALE
local SCREEN_PADDING_SCALE = 0.03
```

```lua
LeftArea = React.createElement("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.fromScale(LEFT_WIDTH_SCALE, 1),
})

RightArea = React.createElement("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(LEFT_WIDTH_SCALE, 0),
	Size = UDim2.fromScale(RIGHT_WIDTH_SCALE, 1),
})
```

Kasih padding ke setiap area, bukan ke root saja.

```lua
Padding = React.createElement("UIPadding", {
	PaddingTop = UDim.new(SCREEN_PADDING_SCALE, 0),
	PaddingBottom = UDim.new(SCREEN_PADDING_SCALE, 0),
	PaddingLeft = UDim.new(SCREEN_PADDING_SCALE, 0),
	PaddingRight = UDim.new(SCREEN_PADDING_SCALE, 0),
})
```

## Content Scaling

Gunakan content scale saat:

- UI terlihat bagus di desktop, tapi terlalu besar di HP.
- Elemen internal harus tetap proporsional.
- Jumlah kolom/grid harus terlihat mirip di PC dan HP, hanya ukurannya mengecil.

Tentukan design size komponen:

```lua
local DESIGN_SIZE = Vector2.new(858, 814)
local MIN_CONTENT_SCALE = 0.35
```

Hitung scale dari area aktual:

```lua
local function getContentScale(size: Vector2): number
	if size.X <= 0 or size.Y <= 0 then
		return 1
	end

	local fitScale = math.min(size.X / DESIGN_SIZE.X, size.Y / DESIGN_SIZE.Y)
	return math.clamp(fitScale, MIN_CONTENT_SCALE, 1)
end
```

Ukur bounds setelah padding:

```lua
Bounds = React.createElement("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	[React.Change.AbsoluteSize] = function(rbx)
		setBoundsSize(rbx.AbsoluteSize)
	end,
}, {
	Panel = React.createElement(Panel, {
		contentScale = contentScale,
	}),
})
```

Di dalam panel, scale isi panel:

```lua
local contentScale = props.contentScale or 1
local contentSizeScale = if contentScale > 0 then 1 / contentScale else 1

Content = React.createElement("Frame", {
	BackgroundTransparency = 1,
	ClipsDescendants = false,
	Size = UDim2.fromScale(contentSizeScale, contentSizeScale),
}, {
	UIScale = React.createElement("UIScale", {
		Scale = contentScale,
	}),

	-- Internal content here
})
```

Kenapa size content dibuat `1 / contentScale`:

- Tanpa ini, visual mengecil tapi layout internal tidak punya ruang logis yang benar.
- Dengan ini, panel tetap melebar sesuai area, sementara isi di dalamnya mengecil proporsional.

## Kapan Jangan Pakai Fixed Surface

Jangan memakai fixed surface sebagai panel utama:

```lua
Surface.Size = UDim2.fromOffset(858, 814)
Surface.UIScale.Scale = fitScale
```

Ini biasanya bikin UI kecil di tengah layar. Fixed surface boleh dipakai untuk preview/story, tapi bukan sebagai frame utama fullscreen yang harus melebar.

Gunakan:

- Area utama fill dengan `Size = UDim2.fromScale(1, 1)`.
- Isi di dalam area yang diberi `UIScale`.

## Panel Composition

Panel umum biasanya:

```text
Panel
├── UICorner
├── Content
│   ├── UIScale
│   ├── UIPadding
│   ├── UIListLayout
│   ├── Header
│   ├── Toolbar
│   ├── Tabs
│   └── Body
```

Panel root:

```lua
React.createElement("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Color.Panel,
	ClipsDescendants = true,
	BorderSizePixel = 0,
})
```

Gunakan outer stroke hanya kalau memang perlu. Untuk panel besar, sering kali radius + background sudah cukup.

## Fixed Height Rows

Jika panel memakai `UIListLayout`, tentukan tinggi setiap row secara eksplisit.

Contoh:

```lua
local HEADER_HEIGHT = 51
local SEARCH_HEIGHT = 60
local TAB_HEIGHT = 60
local CHIP_HEIGHT = 50

local BODY_OFFSET = HEADER_HEIGHT
	+ 16
	+ SEARCH_HEIGHT
	+ 18
	+ TAB_HEIGHT
	+ 16
	+ CHIP_HEIGHT
	+ 16
```

Body/grid:

```lua
Body = React.createElement("Frame", {
	Size = UDim2.new(1, 0, 1, -BODY_OFFSET),
	BackgroundTransparency = 1,
})
```

Saat row height berubah, offset wajib ikut berubah.

## Stroke Clipping

Stroke sering kepotong kalau parent row terlalu pas.

Rule praktis:

- Child height `52`, row parent minimal `60`.
- Child height `48`, row parent minimal `60`.
- Child height `38`, row parent minimal `50`.
- Row yang berisi stroke harus punya `UIPadding` minimal `4-6px`.
- Active/focus stroke boleh lebih tebal, tapi parent harus punya ruang.

Search toolbar:

```lua
React.createElement("Frame", {
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundTransparency = 1,
}, {
	Padding = React.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}),
})
```

Horizontal tab/chip scroller:

```lua
React.createElement("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundTransparency = 1,
	ScrollBarThickness = 0,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
}, {
	Padding = React.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	}),
})
```

Button stroke:

```lua
UIStroke = React.createElement("UIStroke", {
	Color = strokeColor,
	Thickness = if active then 2 else 1.5,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})
```

## Grid Layout

Grid yang berada di dalam scaled content harus tahu scale parent.

Props:

```lua
export type GridProps = {
	columns: number?,
	viewportScale: number?,
}
```

Ukur width logis:

```lua
local viewportScale = props.viewportScale or 1
local containerWidth, setContainerWidth = React.useState(DEFAULT_WIDTH)

[React.Change.AbsoluteSize] = function(rbx)
	local nextWidth = rbx.AbsoluteSize.X / viewportScale
	setContainerWidth(nextWidth)
end
```

Hitung cell:

```lua
local scrollBarThickness = 6
local sidePadding = 16
local usableWidth = math.max(containerWidth - scrollBarThickness - sidePadding, 1)

local targetCellWidth = math.max((usableWidth - (gapX * (columns - 1))) / columns, 1)
local scale = targetCellWidth / originalWidth
local targetCellHeight = math.floor(originalHeight * scale)
```

Card wrapper:

```lua
ItemWrapper = React.createElement("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
}, {
	ScalerContainer = React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(originalWidth, originalHeight),
	}, {
		UIScale = React.createElement("UIScale", {
			Scale = scale,
		}),
		Card = React.createElement(Card, props),
	}),
})
```

## Scroll Canvas

Kalau ada scaling, jangan hanya bergantung ke `UIGridLayout.AbsoluteContentSize`.

Tambahkan fallback berdasarkan jumlah item:

```lua
local itemCount = if props.isLoading
	then columns * 3
	elseif props.items
		then #props.items
		else 0

local rowCount = math.max(math.ceil(itemCount / columns), 1)
local estimatedContentHeight = gridPaddingTop
	+ (rowCount * targetCellHeight)
	+ (math.max(rowCount - 1, 0) * gapY)
	+ gridPaddingBottom
```

Canvas:

```lua
CanvasSize = contentSizeBinding:map(function(size)
	return UDim2.fromOffset(
		0,
		math.max(size.Y + gridPaddingTop + gridPaddingBottom, estimatedContentHeight)
	)
end)
```

Bottom padding sebaiknya cukup besar, misalnya `72-96`, supaya row terakhir tidak terasa mentok.

## Modal Blocker Opsional

Modal blocker bersifat opsional. Pakai hanya kalau UI memang harus menahan kamera atau input game di belakang, misalnya:

- catalog/shop fullscreen yang fokus ke UI
- avatar editor
- settings modal
- dialog konfirmasi
- tool panel yang tidak boleh membuat karakter/kamera ikut bergerak

Jangan pakai modal blocker untuk UI non-modal seperti:

- HUD
- health bar
- quest tracker
- minimap
- notification toast
- small floating widget
- overlay yang tetap membiarkan player bergerak/kamera bergerak

Jika UI perlu modal behavior, gunakan invisible `TextButton`:

```lua
InputBlocker = React.createElement("TextButton", {
	AutoButtonColor = false,
	Active = true,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Modal = true,
	Selectable = false,
	Size = UDim2.fromScale(1, 1),
	Text = "",
	ZIndex = 1,
})
```

UI utama harus di atas blocker:

```lua
MainArea = React.createElement("Frame", {
	ZIndex = 10,
})
```

Catatan:

- `Modal` hanya ada di button-like GuiObject, bukan `Frame`.
- Jika ada `ViewportFrame`, kasih ZIndex eksplisit lebih tinggi.
- Jika UI bukan modal, jangan tambahkan blocker ini.

## ViewportFrame Preview

Struktur umum:

```text
PreviewPanel
└── Stage
    └── ViewportFrame
        ├── Camera
        └── WorldModel
            └── PreviewModel
```

ZIndex:

```lua
PreviewPanel.ZIndex = 10
Stage.ZIndex = 11
ViewportFrame.ZIndex = 12
```

Tips:

- `ViewportFrame.CurrentCamera` wajib di-set.
- Model harus parent ke `WorldModel`.
- Jangan anchor semua part kalau model perlu animasi.
- Jika clone player, tunggu `Humanoid` dan `HumanoidRootPart`.
- Set camera dari `Model:GetBoundingBox()` agar full-body/fit object.

Camera fit pattern:

```lua
local boundingCFrame, boundingSize = model:GetBoundingBox()
local center = boundingCFrame.Position
local height = math.max(boundingSize.Y, 5)
local width = math.max(boundingSize.X, boundingSize.Z, 3)
local distance = math.max(height * 2.65, width * 3.1, 13)
local target = center + Vector3.new(0, height * 0.04, 0)
local cameraPosition = target + Vector3.new(0, height * 0.04, distance)

camera.CFrame = CFrame.new(cameraPosition, target)
```

## ZIndex Rules

Gunakan layer sederhana:

- `1`: modal blocker/background blocker
- `10`: main panel area
- `11`: inner surface/stage
- `12`: viewport/content interactive surface
- `20+`: dropdown, popover, tooltip

Jangan mencampur ZIndex acak antar komponen. Kalau ada modal blocker, semua UI utama harus jelas di atasnya.

## Responsive QA Checklist

Cek sebelum dianggap selesai:

- PC: panel melebar sesuai area, bukan fixed kecil.
- HP landscape: layout tetap sama secara struktur, hanya mengecil proporsional.
- Tidak ada text/button yang overlap.
- Stroke active/focus tidak kepotong.
- Card paling kiri dan kanan tidak kepotong.
- Scroll bisa mencapai row terakhir.
- Jika ada preview, preview tetap visible di HP.
- Jika modal, kamera/game input belakang tidak ikut bergerak.
- Jika ada `ViewportFrame`, model muncul dan ter-frame penuh.

## Common Mistakes

### Fixed Surface Jadi Panel Utama

Akibat:

- UI kecil di tengah.
- Tidak melebar ke samping.
- Gap antar area jadi aneh.

Solusi:

- Area utama tetap scale/full.
- Content internal saja yang memakai `UIScale`.

### Double-Scale Grid

Akibat:

- Card jadi terlalu kecil.
- Grid kacau.

Solusi:

- Bagi `AbsoluteSize.X` dengan `viewportScale`.

### Stroke Tanpa Buffer

Akibat:

- Stroke search/category/chip/card kepotong.

Solusi:

- Parent row lebih tinggi dari child.
- Tambahkan padding `4-6px`.

### CanvasSize Kurang Panjang

Akibat:

- Scroll mentok bawah tapi item terakhir masih kepotong.

Solusi:

- Hitung estimated content height dari row count.
- Tambahkan bottom padding cukup besar.

### Modal Blocker Dipakai Saat Tidak Perlu

Akibat:

- Kamera/player input terasa terkunci padahal UI cuma overlay biasa.
- UX terasa berat untuk HUD atau floating widget.

Solusi:

- Pakai modal blocker hanya untuk modal/fullscreen interaction.
- Jangan pakai blocker untuk HUD/non-modal overlay.

### Modal Blocker Menutup Viewport

Akibat:

- Viewport terlihat blank atau tidak menerima input.

Solusi:

- Beri ZIndex eksplisit pada main area dan viewport.

## Referensi Implementasi Project Ini

- `src/client/ui/screens/CatalogScreen.luau`
- `src/client/ui/organisms/CatalogPanel.luau`
- `src/client/ui/organisms/CatalogGrid.luau`
- `src/client/ui/organisms/AvatarPreviewViewport.luau`
- `src/client/ui/molecules/SearchToolbar.luau`
- `src/client/ui/organisms/MainCategoryTabs.luau`
- `src/client/ui/organisms/SubCategoryChips.luau`
