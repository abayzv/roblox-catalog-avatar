local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local CatalogPanel = require(script.Parent.Parent.organisms.CatalogPanel)
local AvatarPreviewViewport = require(script.Parent.Parent.organisms.AvatarPreviewViewport)

local CATALOG_WIDTH_SCALE = 0.68
local PREVIEW_WIDTH_SCALE = 1 - CATALOG_WIDTH_SCALE
local SCREEN_PADDING_SCALE = 0.03
local CATALOG_DESIGN_SIZE = Vector2.new(858, 814)
local MIN_CATALOG_SCALE = 0.35

local function getCatalogContentScale(size: Vector2): number
	if size.X <= 0 or size.Y <= 0 then
		return 1
	end

	local fitScale = math.min(size.X / CATALOG_DESIGN_SIZE.X, size.Y / CATALOG_DESIGN_SIZE.Y)
	return math.clamp(fitScale, MIN_CATALOG_SCALE, 1)
end

local function CatalogScreen()
	local catalogBoundsSize, setCatalogBoundsSize = React.useState(Vector2.new(0, 0))
	local catalogContentScale = getCatalogContentScale(catalogBoundsSize)

	return React.createElement("Frame", {
		Name = "CatalogScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
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
		}),

		CatalogArea = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(CATALOG_WIDTH_SCALE, 1),
			ClipsDescendants = false,
			ZIndex = 10,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(SCREEN_PADDING_SCALE, 0),
				PaddingBottom = UDim.new(SCREEN_PADDING_SCALE, 0),
				PaddingLeft = UDim.new(SCREEN_PADDING_SCALE, 0),
				PaddingRight = UDim.new(SCREEN_PADDING_SCALE, 0),
			}),

			CatalogBounds = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				[React.Change.AbsoluteSize] = function(rbx)
					local nextSize = rbx.AbsoluteSize
					if nextSize.X ~= catalogBoundsSize.X or nextSize.Y ~= catalogBoundsSize.Y then
						setCatalogBoundsSize(nextSize)
					end
				end,
			}, {
				CatalogPanel = React.createElement(CatalogPanel, {
					contentScale = catalogContentScale,
				}),
			}),
		}),

		ActiveCharacterPreviewSpace = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(CATALOG_WIDTH_SCALE, 0),
			Size = UDim2.fromScale(PREVIEW_WIDTH_SCALE, 1),
			ZIndex = 10,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(SCREEN_PADDING_SCALE, 0),
				PaddingBottom = UDim.new(SCREEN_PADDING_SCALE, 0),
				PaddingLeft = UDim.new(SCREEN_PADDING_SCALE, 0),
				PaddingRight = UDim.new(SCREEN_PADDING_SCALE, 0),
			}),

			Preview = React.createElement(AvatarPreviewViewport),
		}),
	})
end

return CatalogScreen
