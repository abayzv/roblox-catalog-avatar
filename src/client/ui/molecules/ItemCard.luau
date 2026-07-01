local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local PriceRow = require(script.Parent.PriceRow)

export type ItemCardProps = {
	name: string,
	price: number | string | nil,
	isFree: boolean?,
	isOffSale: boolean?,
	isOwned: boolean?,
	image: string,
	creatorName: string?,
	creatorHasVerifiedBadge: boolean?,
	isPreviewing: boolean?,
	onActivated: (() -> ())?,
	layoutOrder: number?,
	actionText: string?,
}

local function ItemCard(props: ItemCardProps)
	local isHovered, setIsHovered = React.useState(false)

	local isActive = props.isPreviewing or props.actionText == "Stop"

	return React.createElement(
		"TextButton",
		{
			Size = UDim2.fromOffset(248, 228), -- Added room for creator row
			BackgroundTransparency = 1,
			LayoutOrder = props.layoutOrder,
			AutoButtonColor = false,
			Text = "",
			Active = true,
			[React.Event.Activated] = props.onActivated,
			[React.Event.MouseEnter] = function()
				setIsHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setIsHovered(false)
			end,
		},
		React.createElement("Frame", {
			Size = UDim2.new(1, -4, 1, -4),
			Position = UDim2.fromOffset(2, 2),
			BackgroundColor3 = Theme.Color.Panel,
			BorderSizePixel = 0,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.LG),
			}),
			UIStroke = React.createElement("UIStroke", {
				Color = (isHovered or isActive) and Theme.Color.Purple or Theme.Color.Border,
				Thickness = (isHovered or isActive) and 2 or 1,
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
				Padding = UDim.new(0, 6),
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
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = props.name,
				TextColor3 = Theme.Color.TextPrimary,
				Font = Theme.Font.Bold,
				TextSize = Theme.Text.CardTitle,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 2,
			}),

			-- 3. Creator Row
			CreatorRow = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 3),
				}),
				CreatorName = React.createElement("TextLabel", {
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Text = props.creatorName or "",
					TextColor3 = Theme.Color.TextSecondary,
					Font = Theme.Font.Regular,
					TextSize = Theme.Text.Caption,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 1,
				}),
				VerifiedBadge = if props.creatorHasVerifiedBadge
					then React.createElement("ImageLabel", {
						Size = UDim2.fromOffset(12, 12),
						BackgroundTransparency = 1,
						Image = Icons.Verified,
						LayoutOrder = 2,
					})
					else nil,
			}),

			-- 4. Price
			Price = React.createElement(PriceRow, {
				price = props.price,
				isFree = props.isFree,
				isOffSale = props.isOffSale,
				isOwned = props.isOwned,
				layoutOrder = 4,
			}),
		})
	)
end

return ItemCard
