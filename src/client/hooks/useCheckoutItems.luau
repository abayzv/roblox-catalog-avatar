local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local usePreviewState = require(script.Parent.usePreviewState)
local PreviewPayloadCache = require(script.Parent.Parent.services.PreviewPayloadCache)
local ItemDetailsService = require(script.Parent.Parent.services.ItemDetailsService)
local CommerceService = require(script.Parent.Parent.services.CommerceService)
local AvatarAppearanceClient = require(script.Parent.Parent.services.AvatarAppearanceClient)
local WornItemExtractor = require(ReplicatedStorage.Shared.avatar.WornItemExtractor)

export type CheckoutItem = {
	key: string,
	id: number,
	itemType: string,
	property: string,
	name: string,
	price: number,
	creator: string,
	image: string,
	isFree: boolean,
	isOffSale: boolean,
	isOwned: boolean,
}

local function useCheckoutItems()
	local equippedKeys = usePreviewState()
	local activeSnapshot, setActiveSnapshot = React.useState(nil)
	
	React.useEffect(function()
		local function getSnapshot(s)
			if s.optimisticState and s.optimisticState.isOptimistic then
				return s.optimisticState.predictedSnapshot
			end
			return s.liveSnapshot
		end

		local state = AvatarAppearanceClient.getState()
		if state then
			setActiveSnapshot(getSnapshot(state))
		end

		local unsubscribe = AvatarAppearanceClient.subscribe(function(newState)
			if newState then
				setActiveSnapshot(getSnapshot(newState))
			end
		end)
		return unsubscribe
	end, {})
	
	local ownedKeys, setOwnedKeys = React.useState({})
	local itemDetails, setItemDetails = React.useState({})
	local validItems, setValidItems = React.useState({})
	local hiddenAssets, setHiddenAssets = React.useState({})
	local isLoading, setIsLoading = React.useState(true)

	React.useEffect(function()
		local isMounted = true
		local cleanupFns = {}
		
		if not activeSnapshot then
			setIsLoading(false)
			return
		end

		setIsLoading(true)

		task.spawn(function()
			local rawWorn = WornItemExtractor.extract(activeSnapshot)
			local bodyPartIds = {}
			for _, item in ipairs(rawWorn) do
				local p = item.property
				if p == "Head" or p == "Torso" or p == "LeftArm" or p == "RightArm" or p == "LeftLeg" or p == "RightLeg" then
					table.insert(bodyPartIds, item.id)
				end
			end

			local resolvedBundlesMap = {}
			if #bodyPartIds > 0 then
				resolvedBundlesMap = ItemDetailsService.resolveBundlesFromAssets(bodyPartIds)
			end
			
			if not isMounted then return end

			local toResolve = {}
			local toFetchDetails = {}
			local addedKeys = {}

			local function addTarget(key, id, itemType, property)
				if addedKeys[key] then return end
				addedKeys[key] = true
				table.insert(toResolve, { key = key, id = id, itemType = itemType, property = property })
				table.insert(toFetchDetails, { id = id, itemType = itemType })
			end

			for key, isEquipped in pairs(equippedKeys) do
				if isEquipped then
					local payload = PreviewPayloadCache.get(key)
					if payload and payload.kind ~= "Emote" then
						addTarget(payload.key, payload.id, payload.itemType, payload.itemType)
					end
				end
			end

			for _, bundleId in pairs(resolvedBundlesMap) do
				local key = "Bundle:" .. bundleId
				addTarget(key, bundleId, "Bundle", "Bundle")
			end

			for _, item in ipairs(rawWorn) do
				local key = "Asset:" .. item.id
				addTarget(key, item.id, "Asset", item.property)
			end

			local details = ItemDetailsService.resolveDetails(toFetchDetails)
			if not isMounted then return end

			local newHiddenAssets = {}
			for key, _ in pairs(addedKeys) do
				local detail = details[key]
				if detail and detail.bundledItemIds then
					for bId, _ in pairs(detail.bundledItemIds) do
						newHiddenAssets[bId] = true
					end
				end
			end

			CommerceService.resolveBatch(toResolve)
			for _, item in ipairs(toResolve) do
				local unsubscribe = CommerceService.listen(item.key, function(isOwned)
					if not isMounted then return end
					setOwnedKeys(function(prev)
						if prev[item.key] == isOwned then return prev end
						local nextState = table.clone(prev)
						nextState[item.key] = isOwned
						return nextState
					end)
				end)
				table.insert(cleanupFns, unsubscribe)
			end
			
			setItemDetails(function(prev)
				local nextState = table.clone(prev)
				for k, v in pairs(details) do
					nextState[k] = v
				end
				return nextState
			end)
			
			setValidItems(toResolve)
			setHiddenAssets(newHiddenAssets)
			setIsLoading(false)
		end)

		return function()
			isMounted = false
			for _, fn in ipairs(cleanupFns) do
				fn()
			end
		end
	end, { equippedKeys, activeSnapshot })

	local checkoutItems = React.useMemo(function()
		if isLoading then return {} end
		
		local items = {}
		for _, vItem in ipairs(validItems) do
			if vItem.itemType == "Asset" and hiddenAssets[vItem.id] then
				continue
			end
			
			local isOwned = ownedKeys[vItem.key] == true
			if not isOwned then
				local detail = itemDetails[vItem.key]
				if detail then
					table.insert(items, {
						key = vItem.key,
						id = vItem.id,
						itemType = vItem.itemType,
						property = vItem.property,
						name = detail.name,
						price = detail.price,
						creator = detail.creator,
						image = detail.image,
						isFree = detail.isFree,
						isOffSale = detail.isOffSale,
						isOwned = isOwned,
					})
				end
			end
		end
		
		table.sort(items, function(a, b) return a.id < b.id end)
		return items
	end, { validItems, ownedKeys, itemDetails, hiddenAssets, isLoading })

	local totalRobux = 0
	local buyableCount = 0
	for _, item in ipairs(checkoutItems) do
		if not item.isOffSale and not item.isFree and not item.isOwned then
			totalRobux += item.price
			buyableCount += 1
		end
	end

	return {
		items = checkoutItems,
		totalRobux = totalRobux,
		buyableCount = buyableCount,
		isLoading = isLoading,
	}
end

return useCheckoutItems
