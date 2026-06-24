local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local ButtonBase = require(script.Parent.ButtonBase)

export type GlassButtonProps = {
	text: string?,
	icon: string?,
	layoutOrder: number?,
	onActivated: () -> (),
	disabled: boolean?,
	color: Color3?,
	size: UDim2?,
}

local function GlassButton(props: GlassButtonProps)
	local textColor = props.color or Theme.Color.TextPrimary

	return React.createElement(ButtonBase, {
		disabled = props.disabled,
		layoutOrder = props.layoutOrder,
		onActivated = props.onActivated,
		size = props.size or UDim2.new(0, 0, 0, 48),
		automaticSize = if props.size then nil else Enum.AutomaticSize.X,
		render = function(isHovered, isPressed)
			local bgTransparency = 0.5
			if isPressed then
				bgTransparency = 0.3
			elseif isHovered then
				bgTransparency = 0.4
			end

			return React.createElement("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = bgTransparency,
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = if props.size then nil else Enum.AutomaticSize.X,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, Theme.Radius.MD),
				}),

				Stroke = React.createElement("UIStroke", {
					Color = Color3.new(1, 1, 1),
					Transparency = 0,
					Thickness = 1.5,
				}),

				Padding = React.createElement("UIPadding", {
					PaddingTop = UDim.new(0, Theme.Space.SM),
					PaddingBottom = UDim.new(0, Theme.Space.SM),
					PaddingLeft = UDim.new(
						0,
						if props.text then Theme.Space.MD else Theme.Space.SM
					),
					PaddingRight = UDim.new(
						0,
						if props.text then Theme.Space.MD else Theme.Space.SM
					),
				}),

				Content = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
				}, {
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, Theme.Space.SM),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					Icon = props.icon and React.createElement("ImageLabel", {
						BackgroundTransparency = 1,
						Image = props.icon,
						ImageColor3 = textColor,
						Size = UDim2.fromOffset(20, 20),
						LayoutOrder = 1,
					}),

					Text = props.text and React.createElement("TextLabel", {
						BackgroundTransparency = 1,
						Font = Theme.Font.Medium,
						Text = props.text,
						TextColor3 = textColor,
						TextSize = Theme.Text.Button,
						Size = UDim2.fromOffset(0, 20),
						AutomaticSize = Enum.AutomaticSize.X,
						LayoutOrder = 2,
					}),
				}),
			})
		end,
	})
end

return GlassButton
