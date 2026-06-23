local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local CatalogPanel = require(script.Parent.Parent.organisms.CatalogPanel)

local function CatalogScreen()
	local isMobile, setIsMobile = React.useState(false)

	return React.createElement("Frame", {
		Name = "CatalogScreen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		[React.Change.AbsoluteSize] = function(rbx)
			if rbx.AbsoluteSize.X <= 640 then
				if not isMobile then
					setIsMobile(true)
				end
			else
				if isMobile then
					setIsMobile(false)
				end
			end
		end,
	}, {
		CatalogPanel = React.createElement(CatalogPanel, {
			isMobile = isMobile,
		}),
	})
end

return CatalogScreen
