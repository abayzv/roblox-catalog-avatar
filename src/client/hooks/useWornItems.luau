local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local AvatarAppearanceClient = require(script.Parent.Parent.services.AvatarAppearanceClient)
local WornItemExtractor = require(ReplicatedStorage.Shared.avatar.WornItemExtractor)
local ItemDetailsService = require(script.Parent.Parent.services.ItemDetailsService)

export type WornItemWithDetails = WornItemExtractor.WornItem & {
	name: string,
	price: number,
	creator: string,
	image: string,
	isFree: boolean,
	isOffSale: boolean,
}

export type UseWornItemsResult = {
	wornItems: { WornItemWithDetails },
	isLoading: boolean,
	error: string?,
	refresh: () -> (),
}

local function useWornItems(): UseWornItemsResult
	local wornItems, setWornItems = React.useState({})
	local isLoading, setIsLoading = React.useState(true)
	local error, setError = React.useState(nil :: string?)
	local hasInitialLoad, setHasInitialLoad = React.useState(false)

	local processSnapshot = React.useCallback(function(snapshot)
		if not snapshot then
			return
		end
		-- Only show loading skeleton on first load
		if not hasInitialLoad then
			setIsLoading(true)
		end
		setError(nil)

		task.spawn(function()
			local worn = WornItemExtractor.extract(snapshot)
			local itemsWithDetails = {}

			if #worn > 0 then
				local itemsToFetch = {}
				for _, item in ipairs(worn) do
					table.insert(itemsToFetch, { id = item.id, itemType = item.itemType })
				end
				local details = ItemDetailsService.resolveDetails(itemsToFetch)

				for _, item in ipairs(worn) do
					local combined = table.clone(item)
					local cacheKey = item.itemType .. ":" .. item.id
					local detail = details[cacheKey]

					combined.name = detail and detail.name or ("Item " .. item.id)
					combined.price = detail and detail.price or 0
					combined.creator = detail and detail.creator or "Unknown"
					combined.image = detail and detail.image
						or (
							"rbxthumb://type="
							.. (item.itemType == "Bundle" and "BundleThumbnail" or "Asset")
							.. "&id="
							.. item.id
							.. "&w=150&h=150"
						)
					combined.isFree = detail and detail.isFree or false
					combined.isOffSale = detail and detail.isOffSale or false
					table.insert(itemsWithDetails, combined)
				end
			end

			setWornItems(itemsWithDetails)
			setIsLoading(false)
			setHasInitialLoad(true)
		end)
	end, {})

	local refresh = React.useCallback(function()
		task.spawn(function()
			local state = AvatarAppearanceClient.fetchStateAsync()
			processSnapshot(state.liveSnapshot)
		end)
	end, { processSnapshot })

	React.useEffect(function()
		-- Initial fetch
		refresh()

		-- Subscribe to changes
		local unsubscribe = AvatarAppearanceClient.subscribe(function(state)
			processSnapshot(state.liveSnapshot)
		end)

		return function()
			unsubscribe()
		end
	end, { refresh, processSnapshot })

	return {
		wornItems = wornItems,
		isLoading = isLoading,
		error = error,
		refresh = refresh,
	}
end

return useWornItems
