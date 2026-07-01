local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ItemCard = require(script.Parent.Parent.molecules.ItemCard)
local ItemCardSkeleton = require(script.Parent.Parent.molecules.ItemCardSkeleton)
local usePreviewState = require(script.Parent.Parent.Parent.hooks.usePreviewState)
local PreviewState = require(script.Parent.Parent.Parent.logic.PreviewState)
local PreviewPayloadCache = require(script.Parent.Parent.Parent.services.PreviewPayloadCache)

local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
export type CatalogItem = CatalogTypes.CatalogItem

export type CatalogGridProps = {
	items: { CatalogItem }?,
	readyKeys: { [string]: boolean }?,
	ownedKeys: { [string]: boolean }?,
	isLoading: boolean?,
	isFetchingNextPage: boolean?,
	hasNextPage: boolean?,
	isLimitReached: boolean?,
	onLoadNextPage: (() -> ())?,
	columns: number?,
	onTryOn: ((item: CatalogItem) -> ())?,
	layoutOrder: number?,
	viewportScale: number?,
	emptyText: string?,
}

local function CatalogGrid(props: CatalogGridProps)
	local contentSizeBinding, updateContentSize = React.useBinding(Vector2.new(0, 0))
	local containerWidth, setContainerWidth = React.useState(804)
	local equippedKeys, activeEmote = usePreviewState()
	local isHydrated = true
	local lastScrollTime = React.useRef(0)

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
	local originalHeight = 208

	local targetCellWidth = math.max((usableWidth - (gapX * (columns - 1))) / columns, 1)
	local scale = targetCellWidth / originalWidth
	local targetCellHeight = math.floor(originalHeight * scale)
	local itemCount = if props.isLoading then columns * 3 elseif props.items then #props.items else 0
	if props.isFetchingNextPage then
		itemCount += columns
	end
	local rowCount = math.max(math.ceil(itemCount / columns), 1)
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
				local isReady = props.readyKeys and item.key and props.readyKeys[item.key]

				if isReady then
					local payload = PreviewPayloadCache.get(item.key)
					local isEmote = payload and payload.kind == "Emote"
					local isPreviewing = false
					if not isEmote then
						isPreviewing = (equippedKeys[item.key] == true)
					end

					local actionText = nil
					if isEmote then
						if activeEmote and activeEmote.key == item.key then
							actionText = "Stop"
						else
							actionText = "Play"
						end
					end

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
								isFree = item.isFree,
								isOffSale = item.isOffSale,
								isOwned = item.isOwned
									or (props.ownedKeys and props.ownedKeys[item.key]),
								image = item.image,
								isPreviewing = isPreviewing,
								actionText = actionText,
								onActivated = if props.onTryOn
									then function()
										props.onTryOn(item)
									end
									else nil,
							}),
						}),
					})
				else
					children["SkeletonWrapper_" .. item.id] = React.createElement("Frame", {
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
			end

			if props.isFetchingNextPage then
				local offset = #props.items
				for i = 1, columns do
					children["NextPageSkeletonWrapper_" .. i] = React.createElement("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						LayoutOrder = offset + i,
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
			end
		end
	else
		children.EmptyState = React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = props.emptyText or "No items match your criteria.",
			TextColor3 = Theme.Color.TextMuted,
			Font = Theme.Font.Regular,
			TextSize = Theme.Text.Body,
			TextWrapped = true,
		})
	end

	local gridFrame = React.createElement("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(154, 161, 173),
		CanvasSize = contentSizeBinding:map(function(size)
			return UDim2.fromOffset(
				0,
				math.max(size.Y + gridPaddingTop + gridPaddingBottom, estimatedContentHeight)
			)
		end),
		LayoutOrder = props.layoutOrder,
		[React.Change.AbsoluteSize] = function(rbx)
			local nextWidth = rbx.AbsoluteSize.X / viewportScale
			if nextWidth ~= containerWidth then
				setContainerWidth(nextWidth)
			end
		end,
		[React.Change.CanvasPosition] = function(rbx)
			local maxY = rbx.CanvasSize.Y.Offset - rbx.AbsoluteWindowSize.Y
			if maxY > 0 and rbx.CanvasPosition.Y >= maxY * 0.7 then
				local currentTime = os.clock()
				if currentTime - lastScrollTime.current > 0.5 then
					lastScrollTime.current = currentTime
					if
						props.hasNextPage
						and not props.isFetchingNextPage
						and props.onLoadNextPage
					then
						props.onLoadNextPage()
					end
				end
			end
		end,
	}, children)

	return gridFrame
end

return CatalogGrid
