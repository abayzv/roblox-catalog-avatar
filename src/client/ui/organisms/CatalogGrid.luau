local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ItemCard = require(script.Parent.Parent.molecules.ItemCard)
local ItemCardSkeleton = require(script.Parent.Parent.molecules.ItemCardSkeleton)
local usePreviewState = require(script.Parent.Parent.Parent.hooks.usePreviewState)

export type CatalogItem = {
	id: string,
	name: string,
	price: number,
	image: string,
	assetId: number?,
}

export type CatalogGridProps = {
	items: { CatalogItem }?,
	isLoading: boolean?,
	columns: number?,
	onTryOn: ((item: CatalogItem) -> ())?,
	layoutOrder: number?,
	viewportScale: number?,
}

local function CatalogGrid(props: CatalogGridProps)
	local contentSizeBinding, updateContentSize = React.useBinding(Vector2.new(0, 0))
	local containerWidth, setContainerWidth = React.useState(804)
	local previewItems = usePreviewState()

	local children = {}
	local isEmpty = props.items and #props.items == 0 and not props.isLoading

	local columns = props.columns or 3
	local viewportScale = props.viewportScale or 1
	local scrollBarThickness = 6
	local sidePadding = 4
	local usableWidth = math.max(containerWidth - scrollBarThickness - sidePadding, 1)
	local gapX = 18
	local originalWidth = 248
	local originalHeight = 252

	local targetCellWidth = math.max((usableWidth - (gapX * (columns - 1))) / columns, 1)
	local scale = targetCellWidth / originalWidth

	if not isEmpty then
		children.Layout = React.createElement("UIGridLayout", {
			CellSize = UDim2.fromOffset(
				math.floor(targetCellWidth),
				math.floor(originalHeight * scale)
			),
			CellPadding = UDim2.fromOffset(gapX, 14),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = columns,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			[React.Change.AbsoluteContentSize] = function(rbx)
				updateContentSize(rbx.AbsoluteContentSize)
			end,
		})
		children.Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
		})

		if props.isLoading then
			local skeletonCount = columns * 3
			for i = 1, skeletonCount do
				children["SkeletonWrapper_" .. i] = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					LayoutOrder = i,
				}, {
					ScalerContainer = React.createElement("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(originalWidth, originalHeight),
					}, {
						UIScale = React.createElement("UIScale", { Scale = scale }),
						Card = React.createElement(ItemCardSkeleton, {}),
					}),
				})
			end
		elseif props.items then
			for i, item in ipairs(props.items) do
				children["ItemWrapper_" .. item.id] = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					LayoutOrder = i,
				}, {
					ScalerContainer = React.createElement("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(originalWidth, originalHeight),
					}, {
						UIScale = React.createElement("UIScale", { Scale = scale }),
						Card = React.createElement(ItemCard, {
							name = item.name,
							price = item.price,
							image = item.image,
							isPreviewing = previewItems[item.id] ~= nil,
							onTryOn = if props.onTryOn
								then function()
									props.onTryOn(item)
								end
								else nil,
						}),
					}),
				})
			end
		end
	else
		children.EmptyState = React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "No items match your criteria.",
			TextColor3 = Theme.Color.TextMuted,
			Font = Theme.Font.Regular,
			TextSize = Theme.Text.Body,
			TextWrapped = true,
		})
	end

	return React.createElement("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(154, 161, 173), -- TextMuted equivalent
		CanvasSize = contentSizeBinding:map(function(size)
			return UDim2.fromOffset(0, size.Y + 36) -- extra bottom padding + top padding
		end),
		LayoutOrder = props.layoutOrder,
		[React.Change.AbsoluteSize] = function(rbx)
			local nextWidth = rbx.AbsoluteSize.X / viewportScale
			if nextWidth ~= containerWidth then
				setContainerWidth(nextWidth)
			end
		end,
	}, children)
end

return CatalogGrid
