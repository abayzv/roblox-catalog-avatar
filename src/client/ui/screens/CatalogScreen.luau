local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local CatalogPanel = require(script.Parent.Parent.organisms.CatalogPanel)

local CATALOG_WIDTH_SCALE = 0.68
local PREVIEW_WIDTH_SCALE = 1 - CATALOG_WIDTH_SCALE
local DESIGN_SIZE = Vector2.new(858, 814)

local function CatalogScreen()
	local catalogAreaSize, setCatalogAreaSize = React.useState(DESIGN_SIZE)
	local catalogScale = catalogAreaSize.Y / DESIGN_SIZE.Y

	return React.createElement("Frame", {
		Name = "CatalogScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		CatalogArea = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(CATALOG_WIDTH_SCALE, 1),
			ClipsDescendants = false,
			[React.Change.AbsoluteSize] = function(rbx)
				local size = rbx.AbsoluteSize
				if size.X ~= catalogAreaSize.X or size.Y ~= catalogAreaSize.Y then
					setCatalogAreaSize(size)
				end
			end,
		}, {
			CatalogSurface = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(DESIGN_SIZE.X, DESIGN_SIZE.Y),
			}, {
				UIScale = React.createElement("UIScale", {
					Scale = catalogScale,
				}),

				CatalogPanel = React.createElement(CatalogPanel),
			}),
		}),

		ActiveCharacterPreviewSpace = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(CATALOG_WIDTH_SCALE, 0),
			Size = UDim2.fromScale(PREVIEW_WIDTH_SCALE, 1),
		}),
	})
end

return CatalogScreen
