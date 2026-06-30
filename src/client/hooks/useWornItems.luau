local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local AvatarAppearanceClient = require(script.Parent.Parent.services.AvatarAppearanceClient)
local WornItemExtractor = require(ReplicatedStorage.Shared.avatar.WornItemExtractor)
local WornItemDetailsService = require(script.Parent.Parent.services.WornItemDetailsService)

export type WornItemWithDetails = WornItemExtractor.WornItem & {
	name: string,
	price: number,
	creator: string,
	image: string,
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

	local processSnapshot = React.useCallback(function(snapshot)
		if not snapshot then return end
		setIsLoading(true)
		setError(nil)

		task.spawn(function()
			local items = WornItemExtractor.extract(snapshot)
			
			-- Resolve details
			local ids = {}
			for _, item in ipairs(items) do
				table.insert(ids, item.id)
			end
			
			local details = WornItemDetailsService.resolveDetails(ids)
			
			local itemsWithDetails = {}
			for _, item in ipairs(items) do
				local detail = details[item.id]
				local combined = table.clone(item)
				combined.name = detail and detail.name or item.property
				combined.price = detail and detail.price or 0
				combined.creator = detail and detail.creator or "Unknown"
				combined.image = detail and detail.image or ("rbxthumb://type=Asset&id=" .. item.id .. "&w=150&h=150")
				table.insert(itemsWithDetails, combined)
			end
			
			setWornItems(itemsWithDetails)
			setIsLoading(false)
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
