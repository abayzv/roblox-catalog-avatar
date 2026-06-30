local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local usePreviewState = require(script.Parent.usePreviewState)
local PreviewPayloadCache = require(script.Parent.Parent.services.PreviewPayloadCache)
local ItemDetailsService = require(script.Parent.Parent.services.ItemDetailsService)
local CommerceService = require(script.Parent.Parent.services.CommerceService)

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
	
	local ownedKeys, setOwnedKeys = React.useState({})
	local itemDetails, setItemDetails = React.useState({})
	local isLoading, setIsLoading = React.useState(true)

	React.useEffect(function()
		local isMounted = true
		local cleanupFns = {}
		
		-- Gather items
		local toResolve = {}
		local toFetchDetails = {}
		
		for key, isEquipped in pairs(equippedKeys) do
			if isEquipped then
				local payload = PreviewPayloadCache.get(key)
				if payload and payload.kind ~= "Emote" then
					table.insert(toResolve, {
						key = payload.key,
						id = payload.id,
						itemType = payload.itemType,
					})
					table.insert(toFetchDetails, {
						id = payload.id,
						itemType = payload.itemType,
					})
				end
			end
		end

		if #toResolve == 0 then
			setIsLoading(false)
			return
		end

		setIsLoading(true)

		-- Start background fetch for ownership
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

		-- Start background fetch for item details
		task.spawn(function()
			local details = ItemDetailsService.resolveDetails(toFetchDetails)
			if not isMounted then return end
			
			setItemDetails(function(prev)
				local nextState = table.clone(prev)
				for k, v in pairs(details) do
					nextState[k] = v
				end
				return nextState
			end)
			
			setIsLoading(false)
		end)

		return function()
			isMounted = false
			for _, fn in ipairs(cleanupFns) do
				fn()
			end
		end
	end, { equippedKeys })

	local checkoutItems = React.useMemo(function()
		if isLoading then return {} end
		
		local items = {}
		for key, isEquipped in pairs(equippedKeys) do
			if isEquipped then
				local payload = PreviewPayloadCache.get(key)
				if payload and payload.kind ~= "Emote" then
					local isOwned = ownedKeys[key] == true
					
					if not isOwned then
						local detailKey = payload.itemType .. ":" .. payload.id
						local detail = itemDetails[detailKey]
						
						if detail then
							local checkoutItem: CheckoutItem = {
								key = payload.key,
								id = payload.id,
								itemType = payload.itemType,
								property = payload.itemType, -- Use ItemType as property since Bundles don't have Accessory properties
								name = detail.name,
								price = detail.price,
								creator = detail.creator,
								image = detail.image,
								isFree = detail.isFree,
								isOffSale = detail.isOffSale,
								isOwned = isOwned,
							}
							table.insert(items, checkoutItem)
						end
					end
				end
			end
		end
		
		-- Sort by id just to have consistent order
		table.sort(items, function(a, b) return a.id < b.id end)
		
		return items
	end, { equippedKeys, ownedKeys, itemDetails, isLoading })

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
