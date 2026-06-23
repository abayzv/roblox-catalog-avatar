local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local CatalogPanel = require(script.Parent.Parent.organisms.CatalogPanel)

local function CatalogScreen()
	return React.createElement("Frame", {
		Name = "CatalogScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		CatalogPanel = React.createElement(CatalogPanel),
	})
end

return CatalogScreen
