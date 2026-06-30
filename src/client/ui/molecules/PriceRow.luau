local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local Icon = require(script.Parent.Parent.atoms.Icon)

export type PriceRowProps = {
	price: number | string | nil,
	isFree: boolean?,
	isOffSale: boolean?,
	isOwned: boolean?,
	layoutOrder: number?,
}

local function PriceRow(props: PriceRowProps)
	local displayText = ""
	local showIcon = false

	if props.isOwned then
		displayText = "Owned"
	elseif props.isOffSale then
		displayText = "Off-Sale"
	elseif props.isFree then
		displayText = "Free"
	else
		displayText = tostring(props.price or 0)
		showIcon = true
	end

	return React.createElement(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			LayoutOrder = props.layoutOrder,
		},
		React.createElement(React.Fragment, nil, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			RobuxIcon = showIcon and React.createElement(Icon, {
				image = Icons.Robux,
				size = 20,
				layoutOrder = 1,
				color = Theme.Color.TextPrimary,
			}),
			PriceText = React.createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = displayText,
				TextColor3 = Theme.Color.TextPrimary,
				Font = Theme.Font.Bold,
				TextSize = Theme.Text.Price,
				LayoutOrder = 2,
			}),
		})
	)
end

return PriceRow
