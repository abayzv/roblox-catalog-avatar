local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)
local CatalogConfig = require(ReplicatedStorage.Shared.config.CatalogConfig)

local AvatarApplyService = {}

function AvatarApplyService.init()
	ApplyAvatarRemote.OnServerInvoke = function(player: Player, assetIds: any)
		-- Validate payload type
		if type(assetIds) ~= "table" then
			warn(`[AvatarApplyService] Invalid payload from {player.Name}`)
			return { success = false, message = "Format payload tidak valid." }
		end

		-- Ensure all elements are numbers and deduplicate
		local validatedAssetIds = {}
		local seen = {}
		for _, id in ipairs(assetIds) do
			local numId = tonumber(id)
			if type(numId) == "number" and not seen[numId] then
				seen[numId] = true
				table.insert(validatedAssetIds, numId)
			end
		end
		
		if #validatedAssetIds > 20 then
			return { success = false, message = "Terlalu banyak item yang dipilih sekaligus." }
		end

		-- Validation Pipeline
		for _, assetId in ipairs(validatedAssetIds) do
			local success, productInfo = pcall(function()
				return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
			end)
			
			if not success or not productInfo then
				warn(`[AvatarApplyService] Failed to fetch info for AssetId: {assetId}`)
				return { success = false, message = `Gagal memuat data untuk item dengan ID: {assetId}.` }
			end
			
			local assetTypeId = productInfo.AssetTypeId
			if not CatalogConfig.AllowedAssetTypes[assetTypeId] then
				warn(`[AvatarApplyService] Player {player.Name} tried to equip unsupported AssetTypeId: {assetTypeId} (Asset: {assetId})`)
				return { success = false, message = `Item "${productInfo.Name}" bukan merupakan aksesoris yang didukung.` }
			end
			
			if CatalogConfig.RequireOwnership then
				local ownsAsset = false
				local successOwn, _ = pcall(function()
					ownsAsset = MarketplaceService:PlayerOwnsAsset(player, assetId)
				end)
				if not successOwn or not ownsAsset then
					return { success = false, message = `Anda belum memiliki item "${productInfo.Name}".` }
				end
			end
		end

		print(`[AvatarApplyService] Validasi berhasil untuk {player.Name}. Item valid:`, validatedAssetIds)
		
		-- TODO: Construct ApplyDescription payload
		-- TODO: Use HumanoidDescription:SetAccessories() and Humanoid:ApplyDescription()
		
		return { success = true, message = "Aksesoris berhasil divalidasi!" }
	end
end

return AvatarApplyService
