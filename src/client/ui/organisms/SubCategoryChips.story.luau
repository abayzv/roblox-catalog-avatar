local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local SubCategoryChips = require(script.Parent.SubCategoryChips)

local function Story()
	local activeSubCategory, setActiveSubCategory = React.useState("Jackets")

	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(245, 245, 245), -- Soft background
		},
		React.createElement(React.Fragment, nil, {
			Layout = React.createElement("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Container = React.createElement(
				"Frame",
				{
					Size = UDim2.new(0, 700, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.new(1, 1, 1),
				},
				React.createElement(React.Fragment, nil, {
					UICorner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, 16),
					}),
					Padding = React.createElement("UIPadding", {
						PaddingTop = UDim.new(0, 40),
						PaddingLeft = UDim.new(0, 40),
						PaddingRight = UDim.new(0, 40),
						PaddingBottom = UDim.new(0, 40),
					}),
					Chips = React.createElement(SubCategoryChips, {
						activeSubCategory = activeSubCategory,
						onSubCategorySelected = setActiveSubCategory,
					}),
				})
			),
		})
	)
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = Story,
}
