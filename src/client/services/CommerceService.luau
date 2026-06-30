local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local CommerceService = {}

local ownershipCache = {}
local listeners = {}

function CommerceService.isCached(key: string): boolean
	return ownershipCache[key] ~= nil
end

function CommerceService.getOwnership(key: string): boolean?
	return ownershipCache[key]
end

function CommerceService.listen(key: string, callback: (boolean) -> ()): () -> ()
	if not listeners[key] then
		listeners[key] = {}
	end
	table.insert(listeners[key], callback)

	-- Immediately fire if already cached
	if ownershipCache[key] ~= nil then
		task.spawn(callback, ownershipCache[key])
	end

	return function()
		if listeners[key] then
			local idx = table.find(listeners[key], callback)
			if idx then
				table.remove(listeners[key], idx)
			end
		end
	end
end

local function setOwnership(key: string, isOwned: boolean)
	ownershipCache[key] = isOwned
	if listeners[key] then
		for _, cb in ipairs(listeners[key]) do
			task.spawn(cb, isOwned)
		end
	end
end

function CommerceService.resolveOwnership(itemType: string, id: number, key: string)
	local player = Players.LocalPlayer
	if not player then
		return
	end

	if ownershipCache[key] ~= nil then
		return
	end

	task.spawn(function()
		local success, owns = false, false
		if itemType == "Asset" then
			success, owns = pcall(function()
				return MarketplaceService:PlayerOwnsAsset(player, id)
			end)
		elseif itemType == "Bundle" then
			success, owns = pcall(function()
				return MarketplaceService:PlayerOwnsBundle(player, id)
			end)
		end

		if success then
			setOwnership(key, owns)
		else
			-- Fallback to false if failed to fetch
			setOwnership(key, false)
		end
	end)
end

function CommerceService.resolveBatch(items)
	for _, item in ipairs(items) do
		-- Only resolve if not provided by SearchCatalog (if it was, it would already be true or false)
		-- Since we set item.isOwned from rawItem.IsOwned, it could be nil if the API didn't provide it
		if item.key and ownershipCache[item.key] == nil then
			if type(item.isOwned) == "boolean" then
				setOwnership(item.key, item.isOwned)
			else
				CommerceService.resolveOwnership(item.itemType, item.id, item.key)
			end
		end
	end
end

-- Listen to purchases to automatically update ownership cache
MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
	if isPurchased and player == Players.LocalPlayer then
		setOwnership("Asset:" .. tostring(assetId), true)
	end
end)

MarketplaceService.PromptBundlePurchaseFinished:Connect(function(player, bundleId, isPurchased)
	if isPurchased and player == Players.LocalPlayer then
		setOwnership("Bundle:" .. tostring(bundleId), true)
	end
end)

return CommerceService
