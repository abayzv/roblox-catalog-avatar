local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

export type TextProps = {
	text: string,
	textSize: number?,
	font: Enum.Font?,
	color: Color3?,
	textXAlignment: Enum.TextXAlignment?,
	textYAlignment: Enum.TextYAlignment?,
	textTruncate: Enum.TextTruncate?,
	size: UDim2?,
	automaticSize: Enum.AutomaticSize?,
	layoutOrder: number?,
}

local function Text(props: TextProps)
	return React.createElement("TextLabel", {
		Text = props.text,
		TextSize = props.textSize or Theme.Text.Body,
		Font = props.font or Theme.Font.Regular,
		TextColor3 = props.color or Theme.Color.TextPrimary,
		TextXAlignment = props.textXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.textYAlignment or Enum.TextYAlignment.Center,
		TextTruncate = props.textTruncate or Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		BackgroundTransparency = 1,
		Size = props.size or UDim2.fromScale(1, 1),
		AutomaticSize = props.automaticSize or Enum.AutomaticSize.None,
		LayoutOrder = props.layoutOrder,
	})
end

return Text
