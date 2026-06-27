local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local IconButton = require(script.Parent.Parent.atoms.IconButton)
local SearchInput = require(script.Parent.SearchInput)

export type SearchToolbarProps = {
	searchText: string?,
	onSearchInputChanged: ((text: string) -> ())?,
	onSearchSubmitted: ((text: string) -> ())?,
	layoutOrder: number?,
}

local function SearchToolbar(props: SearchToolbarProps)
	return React.createElement(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			LayoutOrder = props.layoutOrder,
		},
		React.createElement(React.Fragment, nil, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 24),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
			SearchContainer = React.createElement(
				"Frame",
				{
					Size = UDim2.new(1, -52 - 24, 1, 0),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				},
				React.createElement(React.Fragment, nil, {
					Input = React.createElement(SearchInput, {
						text = props.searchText,
						onTextChanged = props.onSearchInputChanged,
						onSubmit = props.onSearchSubmitted,
					}),
				})
			),
			SearchBtn = React.createElement(IconButton, {
				icon = Icons.Search or "rbxassetid://0",
				onActivated = function()
					if props.onSearchSubmitted and props.searchText then
						props.onSearchSubmitted(props.searchText)
					end
				end,
				layoutOrder = 2,
			}),
		})
	)
end

return SearchToolbar
