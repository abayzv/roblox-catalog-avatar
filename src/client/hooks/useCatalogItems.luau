local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local CatalogTypes = require(ReplicatedStorage.Shared.types.CatalogTypes)
local CatalogService = require(script.Parent.Parent.services.CatalogService)
local CatalogWarmupQueue = require(script.Parent.Parent.services.CatalogWarmupQueue)
local PreviewPayloadCache = require(script.Parent.Parent.services.PreviewPayloadCache)

export type UseCatalogItemsResult = {
	items: { CatalogTypes.CatalogItem },
	readyKeys: { [string]: boolean },
	status: "Idle" | "Loading" | "FetchingNextPage" | "Error",
	loadNextPage: () -> (),
	hasNextPage: boolean,
	isLimitReached: boolean,
}

local SearchCache = {}

local function useCatalogItems(category: string, subCategory: string, searchQuery: string): UseCatalogItemsResult
	local items, setItems = React.useState({})
	local readyKeys, setReadyKeys = React.useState({})
	local status, setStatus = React.useState("Loading")
	local hasNextPage, setHasNextPage = React.useState(true)
	local isLimitReached, setIsLimitReached = React.useState(false)
	
	-- Keep track of active request so old requests don't override new ones (Request Token)
	local activeRequestToken = React.useRef(0)
	local pageCount = React.useRef(0)

	local fetchItems = React.useCallback(function(isNextPage: boolean)
		local isSearchMode = searchQuery ~= ""
		local MAX_PAGES = if isSearchMode then 2 else 3
		local cacheKey = `{category}_{subCategory}_{searchQuery}`
		
		if not isNextPage then
			setStatus("Loading")
			setItems({})
			setHasNextPage(true)
			setIsLimitReached(false)
			pageCount.current = 0
			
			activeRequestToken.current += 1
		else
			if
				not hasNextPage
				or status == "Loading"
				or status == "FetchingNextPage"
				or status == "Error"
			then
				return
			end
			-- Check hard limit
			if pageCount.current >= MAX_PAGES or #items >= 90 then
				setHasNextPage(false)
				setIsLimitReached(true)
				return
			end

			setStatus("FetchingNextPage")
		end

		local currentToken = activeRequestToken.current

		task.spawn(function()
			-- Check cache only for initial page
			if not isNextPage then
				if SearchCache[cacheKey] then
					if activeRequestToken.current ~= currentToken then return end
					local cachedData = SearchCache[cacheKey]
					setItems(cachedData.items)
					pageCount.current = 1
					setHasNextPage(cachedData.nextCursor ~= nil and pageCount.current < MAX_PAGES)
					setIsLimitReached(pageCount.current >= MAX_PAGES)
					setStatus("Idle")
					CatalogWarmupQueue.warmup(cachedData.items, currentToken, activeRequestToken)
					return
				end
			end

			-- Artificial delay for pagination so it doesn't spam instantly
			if isNextPage then
				task.wait(0.4)
			end
			
			local params = {
				category = category,
				subCategory = subCategory,
				searchQuery = searchQuery,
				cursor = if isNextPage then "next" else nil,
			}
			
			local result = CatalogService.fetchPage(params)
			
			-- If request was cancelled / new request started, ignore results
			if activeRequestToken.current ~= currentToken then
				return
			end
			
			if result.isThrottled then
				setStatus("Error")
				return
			end
			
			setItems(function(prevItems)
				local newItems = if isNextPage then table.clone(prevItems) else {}
				for _, item in ipairs(result.items) do
					table.insert(newItems, item)
				end
				
				-- Save to cache if it's the first page
				if not isNextPage then
					SearchCache[cacheKey] = {
						items = newItems,
						nextCursor = result.nextCursor,
					}
				end
				
				return newItems
			end)
			
			pageCount.current += 1
			
			local reachedLimit = pageCount.current >= MAX_PAGES or (isNextPage and (#items + #result.items) >= 90)
			setHasNextPage(result.nextCursor ~= nil and not reachedLimit)
			setIsLimitReached(reachedLimit)
			setStatus("Idle")
			
			-- Warmup new items with request token
			CatalogWarmupQueue.warmup(result.items, currentToken, activeRequestToken)
		end)
	end, { category, subCategory, searchQuery, status, hasNextPage, items })

	-- Effect to load initial items when deps change
	React.useEffect(function()
		fetchItems(false)
		
		return function()
			activeRequestToken.current += 1 -- Cancel pending request
		end
	end, { category, subCategory, searchQuery })

	-- Effect to listen for payload readiness
	React.useEffect(function()
		local connections = {}
		local mounted = true
		
		for _, item in ipairs(items) do
			if item.key and not readyKeys[item.key] then
				if PreviewPayloadCache.has(item.key) then
					setReadyKeys(function(prev)
						local nextMap = table.clone(prev)
						nextMap[item.key] = true
						return nextMap
					end)
				else
					local disconnect = PreviewPayloadCache.listen(item.key, function()
						if not mounted then return end
						setReadyKeys(function(prev)
							local nextMap = table.clone(prev)
							nextMap[item.key] = true
							return nextMap
						end)
					end)
					table.insert(connections, disconnect)
				end
			end
		end
		
		return function()
			mounted = false
			for _, disconnect in ipairs(connections) do
				disconnect()
			end
		end
	end, { items })

	return {
		items = items,
		readyKeys = readyKeys,
		status = status,
		loadNextPage = function()
			fetchItems(true)
		end,
		hasNextPage = hasNextPage,
		isLimitReached = isLimitReached,
	}
end

return useCatalogItems
