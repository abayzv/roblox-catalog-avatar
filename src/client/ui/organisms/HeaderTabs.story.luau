local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local HeaderTabs = require(script.Parent.HeaderTabs)

local function Story()
	local activeTab, setActiveTab = React.useState("Item Catalog")

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
			Tabs = React.createElement(HeaderTabs, {
				activeTab = activeTab,
				onTabSelected = setActiveTab,
			}),
		})
	)
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = Story,
}
