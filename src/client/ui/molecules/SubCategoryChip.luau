local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ButtonBase = require(script.Parent.Parent.atoms.ButtonBase)

export type SubCategoryChipProps = {
	text: string,
	active: boolean?,
	onActivated: (() -> ())?,
	layoutOrder: number?,
}

local function SubCategoryChip(props: SubCategoryChipProps)
	return React.createElement(ButtonBase, {
		onActivated = props.onActivated,
		automaticSize = Enum.AutomaticSize.X,
		size = UDim2.new(0, 0, 0, 38),
		layoutOrder = props.layoutOrder,
		render = function(isHovered, isPressed)
			local active = props.active
			local scale = isPressed and 0.98 or 1

			local bgColor = Theme.Color.Panel
			if active then
				bgColor = Theme.Color.ActiveSoft
			elseif isHovered then
				bgColor = Theme.Color.PanelSoft
			end

			local textColor = active and Theme.Color.Purple or Theme.Color.TextPrimary
			local strokeColor = active and Color3.fromRGB(236, 215, 250) or Theme.Color.Border

			return React.createElement(
				"Frame",
				{
					Size = UDim2.new(0, 0, 0, 38),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = bgColor,
				},
				React.createElement(React.Fragment, nil, {
					UIScale = React.createElement("UIScale", {
						Scale = scale,
					}),
					UICorner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, Theme.Radius.MD),
					}),
					UIStroke = React.createElement("UIStroke", {
						Color = strokeColor,
						Thickness = 1,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					UIPadding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 18),
						PaddingRight = UDim.new(0, 18),
					}),
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Text = React.createElement("TextLabel", {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Text = props.text,
						TextColor3 = textColor,
						Font = Theme.Font.Bold,
						TextSize = Theme.Text.Body,
					}),
				})
			)
		end,
	})
end

return SubCategoryChip
