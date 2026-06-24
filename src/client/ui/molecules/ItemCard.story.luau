local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local ItemCard = require(script.Parent.ItemCard)

local MOCK_ITEMS = {
	{
		name = "Black Puffer Jacket",
		price = 150,
		image = "rbxassetid://18517062196", -- Mock image
		category = "Clothing",
		subcategory = "Jackets",
		tags = { "mock", "test" },
		availability = "InStock",
	},
	{
		name = "Pastel Purple Hoodie With Very Long Name That Will Truncate",
		price = 200,
		image = "rbxassetid://18517062196", -- Mock image
		category = "Clothing",
		subcategory = "Sweaters",
		tags = { "mock", "test" },
		availability = "InStock",
	},
	{
		name = "Denim Jacket - Light Wash",
		price = 80,
		image = "rbxassetid://18517062196", -- Mock image
		category = "Clothing",
		subcategory = "Jackets",
		tags = { "mock", "test" },
		availability = "InStock",
	},
}

local function Story()
	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		},
		React.createElement(React.Fragment, nil, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 20),
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 20),
				PaddingLeft = UDim.new(0, 20),
				PaddingRight = UDim.new(0, 20),
				PaddingBottom = UDim.new(0, 20),
			}),

			Item1 = React.createElement(ItemCard, {
				name = MOCK_ITEMS[1].name,
				price = MOCK_ITEMS[1].price,
				image = MOCK_ITEMS[1].image,
				layoutOrder = 1,
				onTryOn = function()
					print("Try On clicked for", MOCK_ITEMS[1].name)
				end,
			}),

			Item2 = React.createElement(ItemCard, {
				name = MOCK_ITEMS[2].name,
				price = MOCK_ITEMS[2].price,
				image = MOCK_ITEMS[2].image,
				layoutOrder = 2,
				onTryOn = function()
					print("Try On clicked for", MOCK_ITEMS[2].name)
				end,
			}),

			Item3 = React.createElement(ItemCard, {
				name = MOCK_ITEMS[3].name,
				price = MOCK_ITEMS[3].price,
				image = MOCK_ITEMS[3].image,
				layoutOrder = 3,
				onTryOn = function()
					print("Try On clicked for", MOCK_ITEMS[3].name)
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
