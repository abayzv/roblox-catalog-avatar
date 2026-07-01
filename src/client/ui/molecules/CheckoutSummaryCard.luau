local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local GradientButton = require(script.Parent.Parent.atoms.GradientButton)

export type CheckoutSummaryCardProps = {
	totalPrice: number,
	onBuy: () -> (),
	layoutOrder: number?,
}

local function CheckoutSummaryCard(props: CheckoutSummaryCardProps)
	local cashbackAmount = math.floor(props.totalPrice * 0.2)

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 160),
		BackgroundColor3 = Theme.Color.Panel,
		LayoutOrder = props.layoutOrder,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, Theme.Radius.MD),
		}),
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, Theme.Space.LG),
			PaddingBottom = UDim.new(0, Theme.Space.LG),
			PaddingLeft = UDim.new(0, Theme.Space.LG),
			PaddingRight = UDim.new(0, Theme.Space.LG),
		}),
		UIStroke = React.createElement("UIStroke", {
			Color = Theme.Color.Border,
			Thickness = 1,
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
		
		-- Price Row
		PriceRow = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, {
			Label = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "Total Price",
				TextColor3 = Theme.Color.TextPrimary,
				Font = Theme.Font.Bold,
				TextSize = Theme.Text.BodyStrong,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			PriceContainer = React.createElement("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundTransparency = 1,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Icon = React.createElement("ImageLabel", {
					Size = UDim2.fromOffset(20, 20),
					BackgroundTransparency = 1,
					Image = Icons.Robux,
					ImageColor3 = Theme.Color.TextPrimary,
					LayoutOrder = 1,
				}),
				Amount = React.createElement("TextLabel", {
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Text = tostring(props.totalPrice),
					TextColor3 = Theme.Color.TextPrimary,
					Font = Theme.Font.Bold,
					TextSize = Theme.Text.ScreenTitle,
					LayoutOrder = 2,
				}),
			}),
		}),
		
		-- Cashback Row
		CashbackRow = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, {
			Label = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "Cashback 20%",
				TextColor3 = Theme.Color.Purple,
				Font = Theme.Font.Bold,
				TextSize = Theme.Text.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			CashbackContainer = React.createElement("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundTransparency = 1,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Icon = React.createElement("ImageLabel", {
					Size = UDim2.fromOffset(18, 18),
					BackgroundTransparency = 1,
					Image = Icons.Robux,
					ImageColor3 = Theme.Color.Purple,
					LayoutOrder = 1,
				}),
				Amount = React.createElement("TextLabel", {
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Text = tostring(cashbackAmount),
					TextColor3 = Theme.Color.Purple,
					Font = Theme.Font.Bold,
					TextSize = Theme.Text.ScreenTitle,
					LayoutOrder = 2,
				}),
			}),
		}),
		
		-- Separator
		Separator = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Color.Border,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}),
		
		-- Buy Button
		BuyButton = React.createElement(GradientButton, {
			text = "Buy",
			size = UDim2.new(1, 0, 0, 44),
			layoutOrder = 4,
			onActivated = props.onBuy,
		}),
	})
end

return CheckoutSummaryCard
