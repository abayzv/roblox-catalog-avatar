local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ButtonBase = require(script.Parent.ButtonBase)

export type GradientButtonProps = {
	text: string,
	size: UDim2?,
	onActivated: (() -> ())?,
	disabled: boolean?,
	layoutOrder: number?,
}

local function GradientButton(props: GradientButtonProps)
	return React.createElement(ButtonBase, {
		disabled = props.disabled,
		onActivated = props.onActivated,
		size = props.size or UDim2.new(1, 0, 0, 34),
		layoutOrder = props.layoutOrder,
		render = function(isHovered, isPressed)
			local scale = isPressed and 0.98 or 1

			local overlayTransparency = 1
			local overlayColor = Color3.new(1, 1, 1)

			if props.disabled then
				overlayTransparency = 0.5
				overlayColor = Color3.new(0.5, 0.5, 0.5)
			elseif isPressed then
				overlayTransparency = 0.8
				overlayColor = Color3.new(0, 0, 0)
			elseif isHovered then
				overlayTransparency = 0.85
				overlayColor = Color3.new(1, 1, 1)
			end

			return React.createElement(
				"Frame",
				{
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
				},
				React.createElement(React.Fragment, nil, {
					UIScale = React.createElement("UIScale", {
						Scale = scale,
					}),
					UICorner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, Theme.Radius.SM),
					}),
					UIGradient = React.createElement("UIGradient", {
						Color = Theme.Gradient.Primary,
					}),
					Overlay = React.createElement("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = overlayColor,
						BackgroundTransparency = overlayTransparency,
						ZIndex = 2,
					}, {
						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, Theme.Radius.SM),
						}),
					}),
					TextLabel = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = props.text,
						TextColor3 = Color3.new(1, 1, 1),
						Font = Theme.Font.Bold,
						TextSize = Theme.Text.Button,
						ZIndex = 3,
					}),
				})
			)
		end,
	})
end

return GradientButton
