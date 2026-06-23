local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local MainCategoryTabs = require(script.Parent.MainCategoryTabs)

local function Story()
	local activeCategory, setActiveCategory = React.useState("Clothing")

	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		},
		React.createElement(React.Fragment, nil, {
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 40),
				PaddingLeft = UDim.new(0, 40),
				PaddingRight = UDim.new(0, 40),
				PaddingBottom = UDim.new(0, 40),
			}),
			Tabs = React.createElement(MainCategoryTabs, {
				activeCategory = activeCategory,
				onCategorySelected = setActiveCategory,
			}),
		})
	)
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = Story,
}
