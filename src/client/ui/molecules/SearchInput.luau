local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local Icon = require(script.Parent.Parent.atoms.Icon)

export type SearchInputProps = {
	placeholder: string?,
	text: string?,
	onTextChanged: ((text: string) -> ())?,
	layoutOrder: number?,
}

local function SearchInput(props: SearchInputProps)
	local isFocused, setIsFocused = React.useState(false)

	local strokeColor = isFocused and Color3.fromRGB(206, 172, 240) or Theme.Color.Border

	return React.createElement(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Theme.Color.Panel,
			LayoutOrder = props.layoutOrder,
		},
		React.createElement(React.Fragment, nil, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.XL),
			}),
			UIStroke = React.createElement("UIStroke", {
				Color = isFocused and Theme.Color.Purple or Theme.Color.Border,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, Theme.Space.MD),
				PaddingRight = UDim.new(0, Theme.Space.MD),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Space.SM),
			}),
			SearchIcon = React.createElement(Icon, {
				image = Icons.Search or "rbxassetid://0",
				size = 24,
				color = Theme.Color.TextMuted,
				layoutOrder = 1,
			}),
			TextBox = React.createElement("TextBox", {
				Size = UDim2.new(1, -24 - Theme.Space.SM, 1, 0),
				BackgroundTransparency = 1,
				Text = props.text or "",
				PlaceholderText = props.placeholder or "Search items...",
				PlaceholderColor3 = Theme.Color.TextMuted,
				TextColor3 = Theme.Color.TextPrimary,
				Font = Theme.Font.Regular,
				TextSize = Theme.Text.BodyStrong,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ClearTextOnFocus = false,
				LayoutOrder = 2,
				[React.Change.Text] = function(rbx)
					if props.onTextChanged then
						props.onTextChanged(rbx.Text)
					end
				end,
				[React.Event.Focused] = function()
					setIsFocused(true)
				end,
				[React.Event.FocusLost] = function()
					setIsFocused(false)
				end,
			}),
		})
	)
end

return SearchInput
