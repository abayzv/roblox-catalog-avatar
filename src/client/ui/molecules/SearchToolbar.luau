local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local IconButton = require(script.Parent.Parent.atoms.IconButton)
local SearchInput = require(script.Parent.SearchInput)

export type SearchToolbarProps = {
	searchText: string?,
	onSearchTextChanged: ((text: string) -> ())?,
	onFilterActivated: (() -> ())?,
	layoutOrder: number?,
}

local function SearchToolbar(props: SearchToolbarProps)
	return React.createElement(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 52),
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
						onTextChanged = props.onSearchTextChanged,
					}),
				})
			),
			FilterBtn = React.createElement(IconButton, {
				icon = Icons.Filter or "rbxassetid://0",
				onActivated = props.onFilterActivated,
				layoutOrder = 2,
			}),
		})
	)
end

return SearchToolbar
