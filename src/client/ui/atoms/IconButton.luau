local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ButtonBase = require(script.Parent.ButtonBase)
local Icon = require(script.Parent.Icon)

export type IconButtonProps = {
	icon: string,
	onActivated: (() -> ())?,
	disabled: boolean?,
	layoutOrder: number?,
}

local function IconButton(props: IconButtonProps)
	return React.createElement(ButtonBase, {
		disabled = props.disabled,
		onActivated = props.onActivated,
		size = UDim2.fromOffset(52, 52),
		layoutOrder = props.layoutOrder,
		render = function(isHovered, isPressed)
			local scale = isPressed and 0.96 or 1
			local bgColor = Theme.Color.Panel
			if isHovered then
				bgColor = Theme.Color.ActiveSoft
			end
			if props.disabled then
				bgColor = Theme.Color.Border
			end

			return React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = bgColor,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}, {
				UIScale = React.createElement("UIScale", {
					Scale = scale,
				}),
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, Theme.Radius.LG),
				}),
				UIStroke = React.createElement("UIStroke", {
					Color = Color3.fromRGB(233, 215, 245),
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Icon = React.createElement(Icon, {
					image = props.icon,
					size = 22,
					color = Theme.Color.Purple,
					layoutOrder = 1,
				}),
				Layout = React.createElement("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
			})
		end,
	})
end

return IconButton
