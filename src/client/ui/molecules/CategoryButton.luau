local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ButtonBase = require(script.Parent.Parent.atoms.ButtonBase)
local Icon = require(script.Parent.Parent.atoms.Icon)

export type CategoryButtonProps = {
	text: string,
	icon: string,
	active: boolean?,
	onActivated: (() -> ())?,
	layoutOrder: number?,
}

local function CategoryButton(props: CategoryButtonProps)
	return React.createElement(ButtonBase, {
		onActivated = props.onActivated,
		size = UDim2.new(0, 128, 0, 48),
		automaticSize = Enum.AutomaticSize.X,
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
			local iconColor = active and Theme.Color.Purple or Theme.Color.IconDark
			local strokeColor = active and Theme.Color.Purple or Theme.Color.Border

			return React.createElement(
				"Frame",
				{
					Size = UDim2.new(0, 128, 0, 48),
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
						Padding = UDim.new(0, Theme.Space.XS),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					SizeConstraint = React.createElement("UISizeConstraint", {
						MinSize = Vector2.new(128, 48),
					}),
					Icon = React.createElement(Icon, {
						image = props.icon,
						size = 20,
						color = iconColor,
						layoutOrder = 1,
					}),
					Text = React.createElement("TextLabel", {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Text = props.text,
						TextColor3 = textColor,
						Font = Theme.Font.Bold,
						TextSize = Theme.Text.BodyStrong,
						LayoutOrder = 2,
					}),
				})
			)
		end,
	})
end

return CategoryButton
