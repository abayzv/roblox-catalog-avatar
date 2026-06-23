local CatalogTopbarController = {}
local Lighting = game:GetService("Lighting")

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

local function getCatalogBlur(): BlurEffect
	local blur = Lighting:FindFirstChild("CatalogBackgroundBlur")
	if blur and blur:IsA("BlurEffect") then
		return blur
	end

	blur = Instance.new("BlurEffect")
	blur.Name = "CatalogBackgroundBlur"
	blur.Enabled = false
	blur.Size = 18
	blur.Parent = Lighting

	return blur
end

function CatalogTopbarController.new(
	packages: Instance,
	screenGui: ScreenGui
): CatalogTopbarController
	local Icon = require(findTopbarIconModule(packages))
	local blur = getCatalogBlur()

	screenGui.Enabled = false
	blur.Enabled = false

	local icon = Icon.new()
	icon:setLabel("Catalog")
	icon:setOrder(1)
	icon:autoDeselect(false)

	icon.selected:Connect(function()
		screenGui.Enabled = true
		blur.Enabled = true
	end)

	icon.deselected:Connect(function()
		screenGui.Enabled = false
		blur.Enabled = false
	end)

	return {
		destroy = function()
			screenGui.Enabled = false
			blur.Enabled = false
			icon:destroy()
		end,
	}
end

return CatalogTopbarController
