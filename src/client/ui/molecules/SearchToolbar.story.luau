local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local SearchToolbar = require(script.Parent.SearchToolbar)

local function Story()
	local searchText, setSearchText = React.useState("")

	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		},
		React.createElement(React.Fragment, nil, {
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 20),
				PaddingLeft = UDim.new(0, 20),
				PaddingRight = UDim.new(0, 20),
				PaddingBottom = UDim.new(0, 20),
			}),
			Toolbar = React.createElement(SearchToolbar, {
				searchText = searchText,
				onSearchTextChanged = setSearchText,
				onFilterActivated = function()
					print("Filter clicked")
				end,
			}),
		})
	)
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = Story,
}
