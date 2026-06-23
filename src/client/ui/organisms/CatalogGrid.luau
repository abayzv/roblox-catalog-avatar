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
	onTryOn: ((item: CatalogItem) -> ())?,
	layoutOrder: number?,
}

local function CatalogGrid(props: CatalogGridProps)
	local contentSizeBinding, updateContentSize = React.useBinding(Vector2.new(0, 0))

	local children = {}
	local isEmpty = props.items and #props.items == 0 and not props.isLoading

	if not isEmpty then
		children.Layout = React.createElement("UIGridLayout", {
			CellSize = UDim2.fromOffset(248, 252),
			CellPadding = UDim2.fromOffset(18, 14),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = 3,
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
			for i = 1, 9 do
				children["Skeleton_" .. i] = React.createElement(ItemCardSkeleton, {
					layoutOrder = i,
				})
			end
		elseif props.items then
			for i, item in ipairs(props.items) do
				children["Item_" .. item.id] = React.createElement(ItemCard, {
					name = item.name,
					price = item.price,
					image = item.image,
					layoutOrder = i,
					onTryOn = if props.onTryOn
						then function()
							props.onTryOn(item)
						end
						else nil,
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
	}, children)
end

return CatalogGrid
