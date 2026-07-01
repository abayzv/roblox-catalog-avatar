local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ButtonBase = require(script.Parent.Parent.atoms.ButtonBase)
local Icon = require(script.Parent.Parent.atoms.Icon)

export type HeaderTabButtonProps = {
	text: string,
	icon: string,
	active: boolean?,
	onActivated: (() -> ())?,
	layoutOrder: number?,
}

local function HeaderTabButton(props: HeaderTabButtonProps)
	return React.createElement(ButtonBase, {
		onActivated = props.onActivated,
		size = UDim2.fromOffset(274, 51),
		layoutOrder = props.layoutOrder,
		render = function(isHovered, isPressed)
			local active = props.active
			local scale = isPressed and 0.98 or 1

			local bgColor = active and Theme.Color.PanelRaised or Theme.Color.Panel
			local textColor = active and Color3.new(1, 1, 1) or Theme.Color.TextPrimary
			local iconColor = active and Color3.new(1, 1, 1) or Theme.Color.IconDark

			local overlayTransparency = 1
			local overlayColor = Theme.Color.OverlayLight

			if isPressed then
				overlayTransparency = 0.85
				overlayColor = Theme.Color.OverlayDark
			elseif isHovered then
				overlayTransparency = active and 0.9 or 0.95
				overlayColor = Theme.Color.OverlayLight
			end

			return React.createElement(
				"Frame",
				{
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = bgColor,
					BackgroundTransparency = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
				},
				React.createElement(React.Fragment, nil, {
					UIScale = React.createElement("UIScale", {
						Scale = scale,
					}),
					UICorner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, Theme.Radius.MD),
					}),
					UIStroke = not active and React.createElement("UIStroke", {
						Color = Theme.Color.Border,
						Thickness = 1,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}) or nil,
					UIGradient = active and React.createElement("UIGradient", {
						Color = Theme.Gradient.Primary,
					}) or nil,
					Overlay = React.createElement(
						"Frame",
						{
							Size = UDim2.fromScale(1, 1),
							BackgroundColor3 = overlayColor,
							BackgroundTransparency = overlayTransparency,
							ZIndex = 2,
						},
						React.createElement(React.Fragment, nil, {
							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(0, Theme.Radius.MD),
							}),
						})
					),
					Content = React.createElement(
						"Frame",
						{
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							ZIndex = 3,
						},
						React.createElement(React.Fragment, nil, {
							Layout = React.createElement("UIListLayout", {
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, Theme.Space.SM),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							Icon = React.createElement(Icon, {
								image = props.icon,
								size = 22,
								color = iconColor,
								layoutOrder = 1,
							}),
							Text = React.createElement("TextLabel", {
								AutomaticSize = Enum.AutomaticSize.XY,
								BackgroundTransparency = 1,
								Text = props.text,
								TextColor3 = textColor,
								Font = Theme.Font.Bold,
								TextSize = Theme.Text.Tab,
								LayoutOrder = 2,
							}),
						})
					),
				})
			)
		end,
	})
end

return HeaderTabButton
