local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)

local AvatarApplyService = {}

function AvatarApplyService.init()
	ApplyAvatarRemote.OnServerEvent:Connect(function(player: Player, assetIds: any)
		-- Validate payload
		if type(assetIds) ~= "table" then
			warn(`[AvatarApplyService] Invalid payload from {player.Name}`)
			return
		end

		-- Ensure all elements are numbers to prevent exploit string injections
		local validatedAssetIds = {}
		for _, id in ipairs(assetIds) do
			if type(id) == "number" then
				table.insert(validatedAssetIds, id)
			elseif type(id) == "string" and tonumber(id) then
				table.insert(validatedAssetIds, tonumber(id))
			end
		end

		print(`[AvatarApplyService] Received apply request from {player.Name} with assets:`, validatedAssetIds)
		
		-- TODO: Validate item IDs and ownership via MarketplaceService/Catalog API
		-- TODO: Fetch AccessoryType and construct ApplyDescription payload
		-- TODO: Use HumanoidDescription:SetAccessories() and Humanoid:ApplyDescription()
	end)
end

return AvatarApplyService
