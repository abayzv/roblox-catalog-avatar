local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local CatalogPanel = require(script.Parent.CatalogPanel)

local function Story()
	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(238, 242, 247), -- Theme.Color.Background
		BackgroundTransparency = 0,
	}, React.createElement(CatalogPanel))
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = Story,
}
