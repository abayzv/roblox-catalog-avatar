local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ItemCard = require(script.Parent.Parent.molecules.ItemCard)
local ItemCardSkeleton = require(script.Parent.Parent.molecules.ItemCardSkeleton)

export type CatalogItem = {
	id: string,
	name: string,
	price: number,
	image: string,
}

export type CatalogGridProps = {
	items: { CatalogItem }?,
	isLoading: boolean?,
	columns: number?,
	onTryOn: ((item: CatalogItem) -> ())?,
	layoutOrder: number?,
}

local function CatalogGrid(props: CatalogGridProps)
	local contentSizeBinding, updateContentSize = React.useBinding(Vector2.new(0, 0))
	local containerWidth, setContainerWidth = React.useState(804) -- default desktop assumption

	local children = {}
	local isEmpty = props.items and #props.items == 0 and not props.isLoading

	local columns = props.columns or 3
	local usableWidth = containerWidth - 6 -- subtract ScrollBarThickness
	local gapX = 18
	local originalWidth = 248
	local originalHeight = 252

	local targetCellWidth = (usableWidth - (gapX * (columns - 1))) / columns
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
			if rbx.AbsoluteSize.X > 0 and math.abs(rbx.AbsoluteSize.X - containerWidth) > 1 then
				setContainerWidth(rbx.AbsoluteSize.X)
			end
		end,
	}, children)
end

return CatalogGrid
