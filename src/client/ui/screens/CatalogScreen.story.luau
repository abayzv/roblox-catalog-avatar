local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local CatalogScreen = require(script.Parent.CatalogScreen)

local function Story()
	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		-- Provide a mock world background in the story to verify transparency
		BackgroundColor3 = Color3.fromRGB(150, 180, 200),
	}, React.createElement(CatalogScreen))
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = Story,
}
