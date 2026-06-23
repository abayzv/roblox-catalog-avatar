local React = require(game:GetService("ReplicatedStorage").Packages.React)

local CatalogScreen = require(script.Parent.screens.CatalogScreen)

local function App()
	return React.createElement(CatalogScreen)
end

return App
