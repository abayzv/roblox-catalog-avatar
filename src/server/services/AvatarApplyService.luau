local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)
local CatalogConfig = require(ReplicatedStorage.Shared.config.CatalogConfig)

local AvatarApplyService = {}

-- Cache to store the applied descriptions for when players respawn
local appliedDescriptions = {}

local function joinUniqueCsv(existingCsv: string, newId: number): string
	local ids = string.split(existingCsv, ",")
	local newIdStr = tostring(newId)
	
	for _, id in ipairs(ids) do
		if id == newIdStr then
			return existingCsv -- Already has it, skip duplicate
		end
	end
	
	if existingCsv == "" or existingCsv == "0" then
		return newIdStr
	else
		return existingCsv .. "," .. newIdStr
	end
end

function AvatarApplyService.init()
	-- Handle respawns
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid
			if humanoid then
				local cachedDescription = appliedDescriptions[player.UserId]
				if cachedDescription then
					-- Add a small delay to ensure character is fully built by Roblox before overriding
					task.delay(0.5, function()
						if character.Parent then
							humanoid:ApplyDescription(cachedDescription)
						end
					end)
				end
			end
		end)
	end)
	
	-- Handle apply requests
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
		
		local character = player.Character
		if not character then
			return { success = false, message = "Karakter tidak ditemukan. Tunggu hingga respawn." }
		end
		
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
		if not humanoid then
			return { success = false, message = "Humanoid tidak ditemukan." }
		end
		
		local description = humanoid:GetAppliedDescription()
		if not description then
			-- Fallback to creating a new one from current user id
			description = Players:GetHumanoidDescriptionFromUserId(player.UserId)
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
			local propertyName = CatalogConfig.AssetTypeToProperty[assetTypeId]
			
			if not propertyName then
				warn(`[AvatarApplyService] Player {player.Name} tried to equip unsupported AssetTypeId: {assetTypeId} (Asset: {assetId})`)
				return { success = false, message = `Item "{productInfo.Name}" bukan merupakan aksesoris yang didukung.` }
			end
			
			if CatalogConfig.RequireOwnership then
				local ownsAsset = false
				local successOwn, _ = pcall(function()
					ownsAsset = MarketplaceService:PlayerOwnsAsset(player, assetId)
				end)
				if not successOwn or not ownsAsset then
					return { success = false, message = `Anda belum memiliki item "{productInfo.Name}".` }
				end
			end
			
			-- Apply to HumanoidDescription based on property type
			local currentVal = description[propertyName]
			if type(currentVal) == "string" then
				-- It's an accessory (CSV string)
				description[propertyName] = joinUniqueCsv(currentVal, assetId)
			elseif type(currentVal) == "number" then
				-- It's clothing (ID)
				description[propertyName] = assetId
			end
		end

		-- Apply the updated description to the live character
		local applySuccess, applyError = pcall(function()
			humanoid:ApplyDescription(description)
		end)
		
		if not applySuccess then
			warn(`[AvatarApplyService] Failed to apply description for {player.Name}: {applyError}`)
			return { success = false, message = "Gagal menerapkan item ke karakter." }
		end
		
		-- Cache the description so it persists upon respawn
		appliedDescriptions[player.UserId] = description
		
		print(`[AvatarApplyService] Sukses menerapkan item untuk {player.Name}.`)
		return { success = true, message = "Aksesoris berhasil dipakai!" }
	end
end

return AvatarApplyService
