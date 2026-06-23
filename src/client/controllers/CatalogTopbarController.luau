local CatalogTopbarController = {}

export type CatalogTopbarController = {
	destroy: (self: CatalogTopbarController) -> (),
}

local function findTopbarIconModule(packages: Instance): ModuleScript
	local topbarPackage = packages:FindFirstChild("TopbarPlus")
	if topbarPackage and topbarPackage:IsA("ModuleScript") then
		return topbarPackage
	end

	local iconModule = packages:FindFirstChild("Icon")
	if iconModule and iconModule:IsA("ModuleScript") then
		return iconModule
	end

	error("TopbarPlus package was not found in ReplicatedStorage.Packages")
end

function CatalogTopbarController.new(
	packages: Instance,
	screenGui: ScreenGui
): CatalogTopbarController
	local Icon = require(findTopbarIconModule(packages))

	screenGui.Enabled = false

	local icon = Icon.new()
	icon:setLabel("Catalog")
	icon:setOrder(1)
	icon:autoDeselect(false)

	icon.selected:Connect(function()
		screenGui.Enabled = true
	end)

	icon.deselected:Connect(function()
		screenGui.Enabled = false
	end)

	return {
		destroy = function()
			screenGui.Enabled = false
			icon:destroy()
		end,
	}
end

return CatalogTopbarController
