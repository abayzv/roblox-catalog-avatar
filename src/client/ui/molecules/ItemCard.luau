local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local GradientButton = require(script.Parent.Parent.atoms.GradientButton)
local PriceRow = require(script.Parent.PriceRow)

export type ItemCardProps = {
	name: string,
	price: number | string,
	image: string,
	onTryOn: (() -> ())?,
	layoutOrder: number?,
}

local function ItemCard(props: ItemCardProps)
	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromOffset(248, 252), -- Exactly matches guideline
			BackgroundColor3 = Theme.Color.Panel,
			LayoutOrder = props.layoutOrder,
		},
		React.createElement(React.Fragment, nil, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.LG),
			}),
			UIStroke = React.createElement("UIStroke", {
				Color = Theme.Color.Border,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),

			-- 1. Image Area
			ImageContainer = React.createElement(
				"Frame",
				{
					Size = UDim2.new(1, 0, 0, 124),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				},
				React.createElement(React.Fragment, nil, {
					UIPadding = React.createElement("UIPadding", {
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					}),
					ItemImage = React.createElement("ImageLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = props.image,
						ScaleType = Enum.ScaleType.Fit,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
					}),
				})
			),

			-- 2. Item Name
			ItemName = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Text = props.name,
				TextColor3 = Theme.Color.TextPrimary,
				Font = Theme.Font.Bold,
				TextSize = Theme.Text.CardTitle,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 2,
			}),

			-- 3. Price
			Price = React.createElement(PriceRow, {
				price = props.price,
				layoutOrder = 3,
			}),

			-- 4. Try On Button
			TryOnButton = React.createElement(GradientButton, {
				text = "Try On",
				onActivated = props.onTryOn,
				layoutOrder = 4,
			}),
		})
	)
end

return ItemCard
