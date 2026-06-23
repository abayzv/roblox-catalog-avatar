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

	local children = {
		Layout = React.createElement("UIGridLayout", {
			CellSize = UDim2.fromOffset(248, 252),
			CellPadding = UDim2.fromOffset(18, 14),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = 3,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			[React.Change.AbsoluteContentSize] = function(rbx)
				updateContentSize(rbx.AbsoluteContentSize)
			end,
		}),
	}

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

	return React.createElement("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(154, 161, 173), -- TextMuted equivalent
		CanvasSize = contentSizeBinding:map(function(size)
			return UDim2.fromOffset(0, size.Y + 20) -- extra bottom padding
		end),
		LayoutOrder = props.layoutOrder,
	}, children)
end

return CatalogGrid
