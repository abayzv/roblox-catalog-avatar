local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local CatalogGrid = require(script.Parent.CatalogGrid)

local MOCK_ITEMS = {}
for i = 1, 12 do
	table.insert(MOCK_ITEMS, {
		id = tostring(i),
		name = "Awesome Roblox Item " .. i,
		price = math.random(50, 500),
		image = "rbxassetid://18517062196",
	})
end

local function Story()
	local isLoading, setIsLoading = React.useState(true)

	React.useEffect(function()
		-- Mock loading sequence
		local timer = task.delay(1.5, function()
			setIsLoading(false)
		end)
		return function()
			task.cancel(timer)
		end
	end, [])

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
			Grid = React.createElement(CatalogGrid, {
				items = MOCK_ITEMS,
				isLoading = isLoading,
				onTryOn = function(item)
					print("Try On clicked for", item.name)
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
