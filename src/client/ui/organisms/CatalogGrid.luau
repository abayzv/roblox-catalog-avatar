local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ItemCard = require(script.Parent.Parent.molecules.ItemCard)
local ItemCardSkeleton = require(script.Parent.Parent.molecules.ItemCardSkeleton)
local usePreviewState = require(script.Parent.Parent.Parent.hooks.usePreviewState)
local PreviewState = require(script.Parent.Parent.Parent.logic.PreviewState)

local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
export type CatalogItem = CatalogTypes.CatalogItem

export type CatalogGridProps = {
	items: { CatalogItem }?,
	isLoading: boolean?,
	isFetchingMore: boolean?,
	fetchNextPage: (() -> ())?,
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
	local sidePadding = 16
	local usableWidth = math.max(containerWidth - scrollBarThickness - sidePadding, 1)
	local gapX = 18
	local gapY = 14
	local originalWidth = 248
	local originalHeight = 252

	local targetCellWidth = math.max((usableWidth - (gapX * (columns - 1))) / columns, 1)
	local scale = targetCellWidth / originalWidth
	local targetCellHeight = math.floor(originalHeight * scale)
	
	local totalItemsToRender = if props.items then #props.items else 0
	if props.isLoading then
		totalItemsToRender = columns * 3
	elseif props.isFetchingMore then
		totalItemsToRender += columns
	end
	
	local rowCount = math.max(math.ceil(totalItemsToRender / columns), 1)
	local gridPaddingTop = 12
	local gridPaddingBottom = 96
	local estimatedContentHeight = gridPaddingTop
		+ (rowCount * targetCellHeight)
		+ (math.max(rowCount - 1, 0) * gapY)
		+ gridPaddingBottom

	if not isEmpty then
		children.Layout = React.createElement("UIGridLayout", {
			CellSize = UDim2.fromOffset(math.floor(targetCellWidth), targetCellHeight),
			CellPadding = UDim2.fromOffset(gapX, gapY),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = columns,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			[React.Change.AbsoluteContentSize] = function(rbx)
				updateContentSize(rbx.AbsoluteContentSize)
			end,
		})
		children.Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, gridPaddingTop),
			PaddingBottom = UDim.new(0, gridPaddingBottom),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		})

		if props.isLoading then
			for i = 1, columns * 3 do
				children["Skeleton_" .. i] = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(math.floor(targetCellWidth), targetCellHeight),
					LayoutOrder = i,
				}, {
					ScalerContainer = React.createElement("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(originalWidth, originalHeight),
					}, {
						UIScale = React.createElement("UIScale", { Scale = scale }),
						Card = React.createElement(ItemCardSkeleton),
					}),
				})
			end
		elseif props.items and #props.items > 0 then
			for i, item in ipairs(props.items) do
				local previewKey = tostring(item.assetId or item.id)
				local isPreviewing = previewItems[previewKey] ~= nil
					or PreviewState.hasPreviewItem(item)

				children["Item_" .. item.id] = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(math.floor(targetCellWidth), targetCellHeight),
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
							isPreviewing = isPreviewing,
							onTryOn = if props.onTryOn
								then function()
									props.onTryOn(item)
								end
								else nil,
						}),
					}),
				})
			end
			
			if props.isFetchingMore then
				for i = 1, columns do
					children["Skeleton_More_" .. i] = React.createElement("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(math.floor(targetCellWidth), targetCellHeight),
						LayoutOrder = #props.items + i,
					}, {
						ScalerContainer = React.createElement("Frame", {
							BackgroundTransparency = 1,
							Size = UDim2.fromOffset(originalWidth, originalHeight),
						}, {
							UIScale = React.createElement("UIScale", { Scale = scale }),
							Card = React.createElement(ItemCardSkeleton),
						}),
					})
				end
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
			return UDim2.fromOffset(
				0,
				math.max(size.Y + gridPaddingTop + gridPaddingBottom, estimatedContentHeight)
			)
		end),
		LayoutOrder = props.layoutOrder,
		[React.Change.CanvasPosition] = function(rbx)
			if props.fetchNextPage and not props.isLoading and not props.isFetchingMore then
				local canvasY = rbx.CanvasPosition.Y
				local windowY = rbx.AbsoluteWindowSize.Y
				local contentY = rbx.AbsoluteCanvasSize.Y
				if contentY - (canvasY + windowY) < 200 then
					props.fetchNextPage()
				end
			end
		end,
		[React.Change.AbsoluteSize] = function(rbx)
			local nextWidth = rbx.AbsoluteSize.X / viewportScale
			if nextWidth ~= containerWidth then
				setContainerWidth(nextWidth)
			end
		end,
	}, children)
end

return CatalogGrid
