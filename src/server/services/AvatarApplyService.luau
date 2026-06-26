local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)
local CatalogConfig = require(ReplicatedStorage.Shared.config.CatalogConfig)
local HumanoidDescriptionSerializer = require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)

local AvatarApplyService = {}

type ProductInfo = {
	AssetTypeId: number,
	Name: string,
}

type EquippedItem = {
	assetId: number,
	propertyName: string,
}

type EquippedState = {
	description: HumanoidDescription,
	items: { EquippedItem },
	itemIds: { number },
}

local MAX_APPLY_ITEMS = 20
local applyingByUserId = {}
local PlayerAppliedDescriptions = {}
local ACCESSORY_TYPE_TO_PROPERTY = {
	[Enum.AccessoryType.Back] = "BackAccessory",
	[Enum.AccessoryType.Face] = "FaceAccessory",
	[Enum.AccessoryType.Front] = "FrontAccessory",
	[Enum.AccessoryType.Hair] = "HairAccessory",
	[Enum.AccessoryType.Hat] = "HatAccessory",
	[Enum.AccessoryType.Neck] = "NeckAccessory",
	[Enum.AccessoryType.Shoulder] = "ShouldersAccessory",
	[Enum.AccessoryType.Waist] = "WaistAccessory",
}

local function describeItems(items: { EquippedItem }): string
	local values = {}
	for _, item in ipairs(items) do
		table.insert(values, `{item.assetId}:{item.propertyName}`)
	end

	return table.concat(values, ",")
end

local function splitCsv(value: string?): { string }
	local values = {}
	if not value or value == "" or value == "0" then
		return values
	end

	for token in string.gmatch(value, "[^,]+") do
		local trimmed = string.gsub(token, "^%s*(.-)%s*$", "%1")
		if trimmed ~= "" and trimmed ~= "0" then
			table.insert(values, trimmed)
		end
	end

	return values
end

local function joinCsv(assetIds: { number }): string
	local seen = {}
	local values = {}

	for _, assetId in ipairs(assetIds) do
		if assetId > 0 and not seen[assetId] then
			seen[assetId] = true
			table.insert(values, tostring(assetId))
		end
	end

	return table.concat(values, ",")
end

local function getSupportedProperties(): { string }
	local seen = {}
	local properties = {}

	for _, propertyName in pairs(CatalogConfig.AssetTypeToProperty) do
		if not seen[propertyName] then
			seen[propertyName] = true
			table.insert(properties, propertyName)
		end
	end

	return properties
end

local SUPPORTED_PROPERTIES = getSupportedProperties()

local function normalizeAssetIds(assetIds: any): { number }?
	if type(assetIds) ~= "table" then
		return nil
	end

	local normalized = {}
	local seen = {}

	for _, id in ipairs(assetIds) do
		local assetId = tonumber(id)
		if assetId and assetId > 0 and not seen[assetId] then
			seen[assetId] = true
			table.insert(normalized, assetId)
		end
	end

	return normalized
end

local function getDesiredIdsFromPayload(payload: any): { number }?
	if type(payload) ~= "table" then
		return nil
	end

	if payload.itemIds ~= nil then
		return normalizeAssetIds(payload.itemIds)
	end

	return normalizeAssetIds(payload)
end

local function addSupportedItem(
	items: { EquippedItem },
	seen: { [number]: boolean },
	assetId: number?,
	propertyName: string?
)
	if not assetId or assetId <= 0 or not propertyName or seen[assetId] then
		return
	end

	seen[assetId] = true
	table.insert(items, {
		assetId = assetId,
		propertyName = propertyName,
	})
end

local function getAccessoryAssetId(accessory: Accessory): number?
	local success, sourceAssetId = pcall(function()
		return accessory.SourceAssetId
	end)
	if success and type(sourceAssetId) == "number" and sourceAssetId > 0 then
		return sourceAssetId
	end

	local attributeAssetId = accessory:GetAttribute("AssetId")
		or accessory:GetAttribute("SourceAssetId")
	return tonumber(attributeAssetId)
end

local function appendCharacterAccessoryItems(
	items: { EquippedItem },
	seen: { [number]: boolean },
	character: Model?
)
	if not character then
		return
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			local propertyName = ACCESSORY_TYPE_TO_PROPERTY[child.AccessoryType]
			local assetId = getAccessoryAssetId(child)

			if propertyName and assetId then
				addSupportedItem(items, seen, assetId, propertyName)
			end
		end
	end
end

local function extractSupportedItems(
	description: HumanoidDescription,
	character: Model?
): { EquippedItem }
	local items = {}
	local seen = {}

	for _, propertyName in ipairs(SUPPORTED_PROPERTIES) do
		local success, currentValue = pcall(function()
			return description[propertyName]
		end)
		if success then
			if type(currentValue) == "string" then
				for _, value in ipairs(splitCsv(currentValue)) do
					local assetId = tonumber(value)
					addSupportedItem(items, seen, assetId, propertyName)
				end
			elseif
				type(currentValue) == "number"
				and currentValue > 0
				and not seen[currentValue]
			then
				addSupportedItem(items, seen, currentValue, propertyName)
			end
		end
	end

	appendCharacterAccessoryItems(items, seen, character)

	table.sort(items, function(left, right)
		return left.assetId < right.assetId
	end)
	return items
end

local function getItemIds(items: { EquippedItem }): { number }
	local itemIds = {}
	for _, item in ipairs(items) do
		table.insert(itemIds, item.assetId)
	end

	return itemIds
end

local function getCurrentDescription(player: Player, humanoid: Humanoid?): HumanoidDescription
	local description = nil
	if humanoid then
		description = humanoid:GetAppliedDescription()
	end

	if description then
		return description
	end

	local state = appliedStates[player.UserId]
	if state then
		return state.description
	end

	if not description then
		local success, webDescription = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if success and webDescription then
			description = webDescription
		else
			description = Instance.new("HumanoidDescription")
		end
	end

	return description
end

local function cacheState(
	player: Player,
	description: HumanoidDescription,
	character: Model?
): EquippedState
	local items = extractSupportedItems(description, character)
	local state = {
		description = description,
		items = items,
		itemIds = getItemIds(items),
	}

	appliedStates[player.UserId] = state
	if not originalStates[player.UserId] then
		originalStates[player.UserId] = state
	end
	return state
end

local function getCharacterHumanoid(player: Player): (Model?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character, humanoid
end

local function getOrCreateState(player: Player): EquippedState?
	local state = appliedStates[player.UserId]
	if state then
		return state
	end

	local character, humanoid = getCharacterHumanoid(player)

	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
		character, humanoid = getCharacterHumanoid(player)
	end

	if humanoid then
		return cacheState(player, humanoid:GetAppliedDescription(), character)
	end

	if player.UserId > 0 then
		local success, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)

		if success and description then
			return cacheState(player, description, nil)
		end
	end

	return nil
end

local function validateProduct(player: Player, assetId: number): (boolean, ProductInfo?, string?)
	local success, productInfo = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
	end)

	if not success or not productInfo then
		warn(`[AvatarApplyService] Failed to fetch info for AssetId: {assetId}`)
		return false, nil, `Gagal memuat data untuk item dengan ID: {assetId}.`
	end

	local assetTypeId = productInfo.AssetTypeId
	local propertyName = CatalogConfig.AssetTypeToProperty[assetTypeId]

	if not propertyName then
		warn(
			`[AvatarApplyService] Player {player.Name} tried to equip unsupported AssetTypeId: {assetTypeId} (Asset: {assetId})`
		)
		return false, nil, `Item "{productInfo.Name}" bukan merupakan item wearable yang didukung.`
	end

	if CatalogConfig.RequireOwnership then
		local ownsAsset = false
		local successOwn = pcall(function()
			ownsAsset = MarketplaceService:PlayerOwnsAsset(player, assetId)
		end)

		if not successOwn or not ownsAsset then
			return false, nil, `Anda belum memiliki item "{productInfo.Name}".`
		end
	end

	return true, productInfo :: ProductInfo, nil
end

local function applyAssetToBuckets(buckets, propertyName: string, assetId: number)
	local bucket = buckets[propertyName]
	if not bucket then
		bucket = {}
		buckets[propertyName] = bucket
	end

	table.insert(bucket, assetId)
end

local function itemsToBuckets(items: { EquippedItem })
	local buckets = {}

	for _, item in ipairs(items) do
		applyAssetToBuckets(buckets, item.propertyName, item.assetId)
	end

	return buckets
end

local function sameAssetIds(left: { number }?, right: { number }?): boolean
	left = left or {}
	right = right or {}

	if #left ~= #right then
		return false
	end

	for index, assetId in ipairs(left) do
		if right[index] ~= assetId then
			return false
		end
	end

	return true
end

local function setDescriptionProperty(
	description: HumanoidDescription,
	propertyName: string,
	assetIds: { number }?
)
	assetIds = assetIds or {}

	local success, currentValue = pcall(function()
		return description[propertyName]
	end)
	if not success then
		return
	end

	if type(currentValue) == "string" then
		description[propertyName] = joinCsv(assetIds)
	elseif type(currentValue) == "number" then
		description[propertyName] = assetIds[#assetIds] or 0
	end
end

local function buildDescriptionFromDesiredIds(
	player: Player,
	baseDescription: HumanoidDescription,
	currentItems: { EquippedItem },
	desiredIds: { number }
): (boolean, HumanoidDescription?, string?)
	local description = baseDescription:Clone()

	local currentBuckets = itemsToBuckets(currentItems)
	local desiredBuckets = {}
	local touchedProperties = {}

	for _, assetId in ipairs(desiredIds) do
		local ok, productInfo, message = validateProduct(player, assetId)
		if not ok or not productInfo then
			return false, nil, message
		end

		local propertyName = CatalogConfig.AssetTypeToProperty[productInfo.AssetTypeId]
		touchedProperties[propertyName] = true
		applyAssetToBuckets(desiredBuckets, propertyName, assetId)
	end

	for propertyName in pairs(currentBuckets) do
		if not sameAssetIds(currentBuckets[propertyName], desiredBuckets[propertyName]) then
			touchedProperties[propertyName] = true
		end
	end

	for propertyName in pairs(touchedProperties) do
		setDescriptionProperty(description, propertyName, desiredBuckets[propertyName])
	end

	return true, description, nil
end

local function handleGetEquipped(player: Player)
	local state = getOrCreateState(player)
	local originalState = originalStates[player.UserId]

	if state then
		print(
			`[AvatarApplyService] Equipped snapshot for {player.Name}; items=[{describeItems(
				state.items
			)}]`
		)
	else
		warn(`[AvatarApplyService] Equipped snapshot unavailable for {player.Name}.`)
	end

	return {
		success = state ~= nil,
		message = "Equipped snapshot loaded.",
		equippedItems = if state then state.items else {},
		originalItems = if originalState then originalState.items else {},
		equippedItemIds = if state then state.itemIds else {},
	}
end

local function handleApplyDescription(player: Player, payload: any)
	if applyingByUserId[player.UserId] then
		return {
			success = false,
			code = "APPLY_IN_PROGRESS",
			message = "Apply is already running",
			revision = payload.revision,
		}
	end

	applyingByUserId[player.UserId] = true
	
	print("[Apply:Server] received revision=" .. tostring(payload.revision))

	local ok, result = pcall(function()
		local valid, reason = HumanoidDescriptionSerializer.validateSnapshot(payload.description)
		if not valid then
			return {
				success = false,
				code = "INVALID_DESCRIPTION",
				message = reason,
				revision = payload.revision,
			}
		end
		
		print("[Apply:Server] description snapshot summary:\n" .. HumanoidDescriptionSerializer.debugPrint(payload.description))

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not humanoid then
			return {
				success = false,
				code = "NO_HUMANOID",
				message = "Character humanoid not found",
				revision = payload.revision,
			}
		end

		local description = HumanoidDescriptionSerializer.deserialize(payload.description)

		humanoid:ApplyDescription(description)

		-- Use the description we just successfully applied, 
		-- because GetAppliedDescription() can be buggy with 2D clothing asset vs image IDs.
		local appliedSnapshot = HumanoidDescriptionSerializer.serialize(description)

		-- cache for respawn
		PlayerAppliedDescriptions[player.UserId] = appliedSnapshot
		
		print("[Apply:Server] applied revision=" .. tostring(payload.revision))
		print("[Apply:Server] applied snapshot summary:\n" .. HumanoidDescriptionSerializer.debugPrint(appliedSnapshot))

		return {
			success = true,
			revision = payload.revision,
			description = appliedSnapshot,
			message = "Outfit applied successfully."
		}
	end)

	applyingByUserId[player.UserId] = nil

	if not ok then
		warn("[AvatarApplyService] ApplyDescription error:", result)
		return {
			success = false,
			code = "APPLY_ERROR",
			message = "Apply failed",
			revision = payload.revision,
		}
	end

	return result
end

function AvatarApplyService.init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid
			if not humanoid then
				return
			end

			local cachedSnapshot = PlayerAppliedDescriptions[player.UserId]
			if cachedSnapshot then
				task.delay(0.5, function()
					if character.Parent then
						local description = HumanoidDescriptionSerializer.deserialize(cachedSnapshot)
						humanoid:ApplyDescription(description)
					end
				end)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerAppliedDescriptions[player.UserId] = nil
	end)

	ApplyAvatarRemote.OnServerInvoke = function(player: Player, payload: any)
		if type(payload) == "table" and payload.action == "ApplyDescription" then
			return handleApplyDescription(player, payload)
		end
		
		-- Fallback to GetEquipped if needed, though mostly Phase 6 handles via drafts now
		if type(payload) == "table" and payload.action == "GetEquipped" then
			return { success = true, equippedItems = {} } -- Stub for UI if it still requests
		end

		return { success = false, message = "Unknown action" }
	end
end

return AvatarApplyService
