local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)
local CatalogConfig = require(ReplicatedStorage.Shared.config.CatalogConfig)

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

local MAX_APPLY_ITEMS = 120
local appliedStates: { [number]: EquippedState } = {}
local originalStates: { [number]: EquippedState } = {}
local resolvedAssetCache: { [number]: number } = {}

type CachedProductValidation = {
	ok: boolean,
	assetTypeId: number?,
	name: string?,
	message: string?,
}

local productValidationCache: { [number]: CachedProductValidation } = {}
local productValidationInFlight: { [number]: boolean } = {}
local ownershipValidationCache: { [number]: { [number]: boolean } } = {}

local PRELOAD_APPLY_ITEMS_LIMIT = 120
local PRELOAD_THROTTLE_SECONDS = 0.03

-- true = safer fallback: if client preload did not run, Apply still works, but may be slow once.
-- false = strict cache-only apply: faster failure if item was never preloaded.
local APPLY_FETCH_ON_MISSING_CACHE = true

local ACCESSORY_TYPE_TO_PROPERTY = {
	[Enum.AccessoryType.Back] = "BackAccessory",
	[Enum.AccessoryType.Face] = "FaceAccessory",
	[Enum.AccessoryType.Front] = "FrontAccessory",
	[Enum.AccessoryType.Hair] = "HairAccessory",
	[Enum.AccessoryType.Hat] = "HatAccessory",
	[Enum.AccessoryType.Neck] = "NeckAccessory",
	[Enum.AccessoryType.Shoulder] = "ShouldersAccessory",
	[Enum.AccessoryType.Waist] = "WaistAccessory",
	[Enum.AccessoryType.TShirt] = "TShirtAccessory",
	[Enum.AccessoryType.Shirt] = "ShirtAccessory",
	[Enum.AccessoryType.Pants] = "PantsAccessory",
	[Enum.AccessoryType.Jacket] = "JacketAccessory",
	[Enum.AccessoryType.Sweater] = "SweaterAccessory",
	[Enum.AccessoryType.Shorts] = "ShortsAccessory",
	[Enum.AccessoryType.LeftShoe] = "LeftShoeAccessory",
	[Enum.AccessoryType.RightShoe] = "RightShoeAccessory",
	[Enum.AccessoryType.DressSkirt] = "DressSkirtAccessory",
	[Enum.AccessoryType.Eyebrow] = "EyebrowAccessory",
	[Enum.AccessoryType.Eyelash] = "EyelashAccessory",
}

local LAYERED_ACCESSORY_PROPERTY_TO_TYPE = {
	TShirtAccessory = Enum.AccessoryType.TShirt,
	ShirtAccessory = Enum.AccessoryType.Shirt,
	PantsAccessory = Enum.AccessoryType.Pants,
	JacketAccessory = Enum.AccessoryType.Jacket,
	SweaterAccessory = Enum.AccessoryType.Sweater,
	ShortsAccessory = Enum.AccessoryType.Shorts,
	LeftShoeAccessory = Enum.AccessoryType.LeftShoe,
	RightShoeAccessory = Enum.AccessoryType.RightShoe,
	DressSkirtAccessory = Enum.AccessoryType.DressSkirt,
	EyebrowAccessory = Enum.AccessoryType.Eyebrow,
	EyelashAccessory = Enum.AccessoryType.Eyelash,
}

local function setLayeredAccessoryProperty(
	description: HumanoidDescription,
	propertyName: string,
	assetIds: { number }?
): boolean
	local accessoryType = LAYERED_ACCESSORY_PROPERTY_TO_TYPE[propertyName]
	if not accessoryType then
		return false
	end

	assetIds = assetIds or {}

	local accessories = description:GetAccessories(true)

	for i = #accessories, 1, -1 do
		if accessories[i].AccessoryType == accessoryType then
			table.remove(accessories, i)
		end
	end

	for order, assetId in ipairs(assetIds) do
		table.insert(accessories, {
			AssetId = assetId,
			AccessoryType = accessoryType,
			IsLayered = true,
			Order = order,
		})
	end

	description:SetAccessories(accessories, true)
	return true
end

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

	-- Apply/preload payloads may come from different client callsites.
	-- Keep this tolerant so cache prewarming and real apply use the exact same parser.
	if payload.itemIds ~= nil then
		return normalizeAssetIds(payload.itemIds)
	end

	if payload.assetIds ~= nil then
		return normalizeAssetIds(payload.assetIds)
	end

	if payload.ids ~= nil then
		return normalizeAssetIds(payload.ids)
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

local function appendDescriptionAccessoryItems(
	items: { EquippedItem },
	seen: { [number]: boolean },
	description: HumanoidDescription
)
	local success, accessories = pcall(function()
		return description:GetAccessories(true)
	end)

	if not success or type(accessories) ~= "table" then
		return
	end

	for _, accessoryInfo in ipairs(accessories) do
		local propertyName = ACCESSORY_TYPE_TO_PROPERTY[accessoryInfo.AccessoryType]
		local assetId = tonumber(accessoryInfo.AssetId)

		if propertyName and assetId then
			addSupportedItem(items, seen, assetId, propertyName)
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
		if propertyName == "EmoteAnimation" then
			local emotes = description:GetEmotes()
			if emotes then
				for _, emoteData in pairs(emotes) do
					for _, assetId in ipairs(emoteData) do
						addSupportedItem(items, seen, assetId, propertyName)
					end
				end
			end
			continue
		end

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

	appendDescriptionAccessoryItems(items, seen, description)
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

local function fetchAndCacheProductValidation(assetId: number): CachedProductValidation
	local cached = productValidationCache[assetId]
	if cached then
		return cached
	end

	while productValidationInFlight[assetId] do
		task.wait(0.05)

		cached = productValidationCache[assetId]
		if cached then
			return cached
		end
	end

	productValidationInFlight[assetId] = true

	local success, productInfo = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
	end)

	local result: CachedProductValidation

	if not success or not productInfo then
		warn(`[AvatarApplyService] Failed to fetch info for AssetId: {assetId}`)
		result = {
			ok = false,
			message = `Gagal memuat data untuk item dengan ID: {assetId}.`,
		}
	else
		local assetTypeId = productInfo.AssetTypeId
		local propertyName = CatalogConfig.AssetTypeToProperty[assetTypeId]

		if not propertyName then
			warn(
				`[AvatarApplyService] Unsupported AssetTypeId: {assetTypeId} (Asset: {assetId})`
			)

			result = {
				ok = false,
				assetTypeId = assetTypeId,
				name = productInfo.Name,
				message = `Item "{productInfo.Name}" bukan merupakan item wearable yang didukung.`,
			}
		else
			result = {
				ok = true,
				assetTypeId = assetTypeId,
				name = productInfo.Name,
			}
		end
	end

	productValidationCache[assetId] = result
	productValidationInFlight[assetId] = nil

	return result
end

local function playerOwnsAssetCached(player: Player, assetId: number): boolean
	local userCache = ownershipValidationCache[player.UserId]

	if not userCache then
		userCache = {}
		ownershipValidationCache[player.UserId] = userCache
	end

	if userCache[assetId] ~= nil then
		return userCache[assetId]
	end

	local ownsAsset = false
	local success = pcall(function()
		ownsAsset = MarketplaceService:PlayerOwnsAsset(player, assetId)
	end)

	local result = success and ownsAsset
	userCache[assetId] = result

	return result
end

local function validateProductForPreload(player: Player, assetId: number)
	local cached = fetchAndCacheProductValidation(assetId)

	if not cached.ok then
		return
	end

	if CatalogConfig.RequireOwnership then
		playerOwnsAssetCached(player, assetId)
	end
end

local function getPreloadedValidationForApply(
	player: Player,
	assetId: number
): (boolean, ProductInfo?, string?)
	local cached = productValidationCache[assetId]
	local startedAt = os.clock()

	-- If preload is already running, wait briefly instead of failing instantly.
	while not cached and productValidationInFlight[assetId] and os.clock() - startedAt < 3 do
		task.wait(0.05)
		cached = productValidationCache[assetId]
	end

	if not cached then
		warn(
			`[AvatarApplyService] Asset {assetId} was not preloaded before Apply. Falling back={APPLY_FETCH_ON_MISSING_CACHE}.`
		)

		if not APPLY_FETCH_ON_MISSING_CACHE then
			task.spawn(function()
				validateProductForPreload(player, assetId)
			end)

			return false, nil, `Item {assetId} belum masuk cache preload. Coba apply lagi sebentar.`
		end

		cached = fetchAndCacheProductValidation(assetId)
	end

	if not cached.ok then
		return false, nil, cached.message
	end

	if CatalogConfig.RequireOwnership then
		local ownsAsset = playerOwnsAssetCached(player, assetId)

		if not ownsAsset then
			return false, nil, `Anda belum memiliki item "{cached.name or tostring(assetId)}".`
		end
	end

	return true, {
		AssetTypeId = cached.assetTypeId :: number,
		Name = cached.name or tostring(assetId),
	}, nil
end

local SINGLE_SLOT_ACCESSORY_PROPERTIES = {
	-- UX rule: user can wear multiple hats, but only one hair should be active.
	-- This is a server-side safety net; client PreviewState should also enforce it.
	HairAccessory = true,
}

local function applyAssetToBuckets(buckets, propertyName: string, assetId: number)
	if SINGLE_SLOT_ACCESSORY_PROPERTIES[propertyName] then
		buckets[propertyName] = { assetId }
		return
	end

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

local function itemsToPropertyByAssetId(items: { EquippedItem }): { [number]: string }
	local propertyByAssetId = {}

	for _, item in ipairs(items) do
		propertyByAssetId[item.assetId] = item.propertyName
	end

	return propertyByAssetId
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

	if SINGLE_SLOT_ACCESSORY_PROPERTIES[propertyName] and #assetIds > 1 then
		assetIds = { assetIds[#assetIds] }
	end

	if propertyName == "EmoteAnimation" then
		local emotes = {}

		for slot, id in ipairs(assetIds) do
			if slot <= 8 then
				emotes["Emote" .. tostring(slot)] = { id }
			end
		end

		description:SetEmotes(emotes)

		local equippedEmotes = {}
		for slot = 1, math.min(#assetIds, 8) do
			table.insert(equippedEmotes, {
				Name = "Emote" .. tostring(slot),
				Slot = slot,
			})
		end

		description:SetEquippedEmotes(equippedEmotes)
		return
	end

	-- IMPORTANT: 3D / layered clothing harus lewat AccessoryBlob
	if setLayeredAccessoryProperty(description, propertyName, assetIds) then
		return
	end

	-- Existing logic untuk classic clothing, body part, animation, rigid accessories
	local success, currentValue = pcall(function()
		return description[propertyName]
	end)

	if not success then
		warn("[AvatarApplyService] Unsupported HumanoidDescription property:", propertyName)
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
	local currentPropertyByAssetId = itemsToPropertyByAssetId(currentItems)
	local desiredBuckets = {}
	local touchedProperties = {}

	for _, assetId in ipairs(desiredIds) do
		-- Most apply payloads contain the whole desired outfit, not only the newly selected item.
		-- Items that are already attached to the live character are trusted and re-bucketed
		-- from the current snapshot, so Apply does not call MarketplaceService for every
		-- existing body part/accessory on the player's avatar.
		local propertyName = currentPropertyByAssetId[assetId]

		if not propertyName then
			local ok, productInfo, message = getPreloadedValidationForApply(player, assetId)
			if not ok or not productInfo then
				return false, nil, message
			end

			propertyName = CatalogConfig.AssetTypeToProperty[productInfo.AssetTypeId]
		end

		if not propertyName then
			return false, nil, `Item {assetId} tidak punya property avatar yang didukung.`
		end

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


local function handlePreloadCatalogItems(player: Player, payload: any)
	local itemIds = getDesiredIdsFromPayload(payload)

	if not itemIds then
		return {
			success = false,
			message = "Format payload preload tidak valid.",
		}
	end

	if #itemIds > PRELOAD_APPLY_ITEMS_LIMIT then
		local limited = {}

		for index = 1, PRELOAD_APPLY_ITEMS_LIMIT do
			table.insert(limited, itemIds[index])
		end

		itemIds = limited
	end

	print(
		`[AvatarApplyService] Preload requested by {player.Name}; ids=[{table.concat(itemIds, ",")}]`
	)

	task.spawn(function()
		local okCount = 0
		local failCount = 0

		for _, assetId in ipairs(itemIds) do
			if player.Parent == nil then
				break
			end

			local success, err = pcall(function()
				validateProductForPreload(player, assetId)
			end)

			if success then
				local cached = productValidationCache[assetId]

				if cached and cached.ok then
					okCount += 1
				else
					failCount += 1
					warn(
						`[AvatarApplyService] Preload invalid asset {assetId}: {cached and cached.message or "no cache"}`
					)
				end
			else
				failCount += 1
				warn(`[AvatarApplyService] Preload error for {assetId}: {err}`)
			end

			task.wait(PRELOAD_THROTTLE_SECONDS)
		end

		print(
			`[AvatarApplyService] Preload finished for {player.Name}; ok={okCount}, failed={failCount}`
		)
	end)

	return {
		success = true,
		message = "Preload started.",
		requestedCount = #itemIds,
	}
end

local function handleApply(player: Player, payload: any)
	local desiredIds = getDesiredIdsFromPayload(payload)
	if not desiredIds then
		warn(`[AvatarApplyService] Invalid payload from {player.Name}`)
		return { success = false, message = "Format payload tidak valid." }
	end

	if #desiredIds > MAX_APPLY_ITEMS then
		return { success = false, message = `Terlalu banyak item yang dipilih sekaligus ({#desiredIds}/{MAX_APPLY_ITEMS}).` }
	end

	local character, humanoid = getCharacterHumanoid(player)
	if not character then
		return { success = false, message = "Karakter tidak ditemukan. Tunggu hingga respawn." }
	end

	if not humanoid then
		return { success = false, message = "Humanoid tidak ditemukan." }
	end

	local baseDescription = getCurrentDescription(player, humanoid)
	local liveItems = extractSupportedItems(baseDescription, character)
	local currentItems = liveItems
	print(
		`[AvatarApplyService] Apply request from {player.Name}; current=[{describeItems(
			currentItems
		)}], live=[{describeItems(liveItems)}], desired=[{table.concat(desiredIds, ",")}]`
	)
	local buildSuccess, finalDescription, buildMessage =
		buildDescriptionFromDesiredIds(player, baseDescription, currentItems, desiredIds)
	if not buildSuccess or not finalDescription then
		return { success = false, message = buildMessage or "Gagal membangun outfit final." }
	end

	local applySuccess, applyError = pcall(function()
		humanoid:ApplyDescription(finalDescription)
	end)

	if not applySuccess then
		warn(`[AvatarApplyService] Failed to apply description for {player.Name}: {applyError}`)
		return { success = false, message = "Gagal menerapkan item ke karakter." }
	end

	local state = cacheState(player, finalDescription, character)

	print(
		`[AvatarApplyService] Sukses menerapkan outfit final untuk {player.Name}; saved=[{describeItems(
			state.items
		)}]`
	)
	return {
		success = true,
		message = "Outfit berhasil diterapkan!",
		equippedItems = state.items,
		equippedItemIds = state.itemIds,
	}
end

function AvatarApplyService.init()
	Players.PlayerAdded:Connect(function(player)
		-- Cache the actual loaded character appearance before catalog preview opens.
		task.spawn(function()
			getOrCreateState(player)
		end)

		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid
			if not humanoid then
				return
			end

			local cachedState = appliedStates[player.UserId]
			if cachedState then
				task.delay(0.5, function()
					if character.Parent then
						humanoid:ApplyDescription(cachedState.description)
					end
				end)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		appliedStates[player.UserId] = nil
		originalStates[player.UserId] = nil
		ownershipValidationCache[player.UserId] = nil
	end)

	ApplyAvatarRemote.OnServerInvoke = function(player: Player, payload: any)
		if type(payload) == "table" then
			if payload.action == "GetEquipped" then
				return handleGetEquipped(player)
			elseif payload.action == "PreloadCatalogItems" then
				return handlePreloadCatalogItems(player, payload)
			elseif payload.action == "ResolvePreviewAsset" then
				local assetId = tonumber(payload.assetId)
				if not assetId then return { success = false } end
				
				if resolvedAssetCache[assetId] then
					return { success = true, result = resolvedAssetCache[assetId] }
				end

				local success, model = pcall(function()
					return game:GetService("InsertService"):LoadAsset(assetId)
				end)
				
				if success and model then
					local anim = model:FindFirstChildOfClass("Animation", true)
					if anim then
						local animId = anim.AnimationId
						model:Destroy()
						local numId = tonumber(string.match(animId, "%d+"))
						if numId then
							resolvedAssetCache[assetId] = numId
							return { success = true, result = numId }
						else
							return { success = true, result = animId }
						end
					end
					
					local clothing = model:FindFirstChildOfClass("Shirt", true)
						or model:FindFirstChildOfClass("Pants", true)
						or model:FindFirstChildOfClass("ShirtGraphic", true)
					if clothing then
						local template = clothing:IsA("ShirtGraphic") and clothing.Graphic or (clothing:IsA("Shirt") and clothing.ShirtTemplate or clothing.PantsTemplate)
						local idStr = string.match(template, "%d+")
						model:Destroy()
						if idStr then
							resolvedAssetCache[assetId] = tonumber(idStr)
							return { success = true, result = tonumber(idStr) }
						end
					end
					
					local decal = model:FindFirstChildOfClass("Decal", true)
					if decal and decal.Name == "face" then
						local idStr = string.match(decal.Texture, "%d+")
						model:Destroy()
						if idStr then
							resolvedAssetCache[assetId] = tonumber(idStr)
							return { success = true, result = tonumber(idStr) }
						end
					end
					
					model:Destroy()
				end
				return { success = false }
			end
		end

		return handleApply(player, payload)
	end
end

return AvatarApplyService
