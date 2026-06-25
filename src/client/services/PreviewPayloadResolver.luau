local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
local PreviewTypes = require(ReplicatedStorage.Shared.types.PreviewTypes)
local CatalogConfig = require(ReplicatedStorage.Shared.config.CatalogConfig)
local AvatarEditorService = game:GetService("AvatarEditorService")

local PreviewPayloadResolver = {}

local AssetTypeStringToValue = {}
for _, enumItem in ipairs(Enum.AvatarAssetType:GetEnumItems()) do
	AssetTypeStringToValue[enumItem.Name] = enumItem.Value
end

function PreviewPayloadResolver.resolveBatch(items: { CatalogTypes.CatalogItem }): { [string]: PreviewTypes.PreviewPayload }
	local payloads = {}
	if #items == 0 then
		return payloads
	end

	local assetIds = {}
	local bundleIds = {}
	
	for _, item in ipairs(items) do
		local id = tonumber(item.assetId or item.id)
		if id then
			if item.itemType == "Bundle" then
				table.insert(bundleIds, id)
			else
				table.insert(assetIds, id)
			end
		end
	end

	local details = {}
	
	if #assetIds > 0 then
		local success, result = pcall(function()
			return AvatarEditorService:GetBatchItemDetails(assetIds, Enum.AvatarItemType.Asset)
		end)
		if success and type(result) == "table" then
			for _, detail in ipairs(result) do
				table.insert(details, detail)
			end
		end
	end
	
	if #bundleIds > 0 then
		local success, result = pcall(function()
			return AvatarEditorService:GetBatchItemDetails(bundleIds, Enum.AvatarItemType.Bundle)
		end)
		if success and type(result) == "table" then
			for _, detail in ipairs(result) do
				table.insert(details, detail)
			end
		end
	end

	if #details == 0 then
		for _, item in ipairs(items) do
			payloads[item.key] = {
				key = item.key,
				id = tonumber(item.assetId or item.id) or 0,
				itemType = item.itemType,
				kind = "Failed",
			}
		end
		return payloads
	end

	local detailsMap = {}
	for _, detail in ipairs(details) do
		local typeStr = if tostring(detail.ItemType) == "Bundle" or detail.ItemType == Enum.AvatarItemType.Bundle then "Bundle" else "Asset"
		detailsMap[`{typeStr}:{detail.Id}`] = detail
	end

	for _, item in ipairs(items) do
		local id = tonumber(item.assetId or item.id) or 0
		local mapKey = `{item.itemType}:{id}`
		local detail = detailsMap[mapKey]

		if not detail then
			payloads[item.key] = {
				key = item.key,
				id = id,
				itemType = item.itemType,
				kind = "Failed",
			}
			continue
		end

		if item.itemType == "Asset" then
			local propertyName = nil
			if detail.AssetType then
				local val = AssetTypeStringToValue[detail.AssetType]
				if val then
					propertyName = CatalogConfig.AssetTypeToProperty[val]
				end
			end
			
			if propertyName == "EmoteAnimation" then
				payloads[item.key] = {
					key = item.key,
					id = id,
					itemType = "Asset",
					kind = "Emote",
					emoteAnimationId = id,
				}
			else
				payloads[item.key] = {
					key = item.key,
					id = id,
					itemType = "Asset",
					kind = "Asset",
					propertyName = propertyName,
					assetIds = { id },
				}
			end
		elseif item.itemType == "Bundle" then
			local bodyParts = {}
			local animations = {}
			local assetIds = {}
			
			if detail.BundledItems then
				for _, bundled in ipairs(detail.BundledItems) do
					if bundled.Type == "Asset" and bundled.AssetType then
						local val = AssetTypeStringToValue[bundled.AssetType]
						if val then
							local prop = CatalogConfig.AssetTypeToProperty[val]
							if prop then
								if string.match(prop, "Animation$") then
									animations[prop] = bundled.Id
								elseif prop == "Head" or prop == "Face" or prop == "Torso" or prop == "LeftArm" or prop == "RightArm" or prop == "LeftLeg" or prop == "RightLeg" then
									bodyParts[prop] = bundled.Id
								else
									table.insert(assetIds, bundled.Id)
								end
							end
						end
					end
				end
			end
			
			local kind = "Bundle"
			if next(bodyParts) then
				kind = "BodyBundle"
			elseif next(animations) then
				kind = "AnimationBundle"
			end
			
			payloads[item.key] = {
				key = item.key,
				id = id,
				itemType = "Bundle",
				kind = kind,
				bodyParts = if next(bodyParts) then bodyParts else nil,
				animations = if next(animations) then animations else nil,
				assetIds = if #assetIds > 0 then assetIds else nil,
			}
		end
	end

	return payloads
end

return PreviewPayloadResolver
