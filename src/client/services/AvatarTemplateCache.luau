local AvatarTemplateCache = {}

type CacheEntry = {
	timestamp: number,
	items: { any },
	hasNextPage: boolean,
}

local cacheData: { [string]: CacheEntry } = {}

local function getKey(mode: string, page: number?): string
	return mode .. ":page:" .. tostring(page or 1)
end

function AvatarTemplateCache.get(mode: string, page: number?): { any }?
	local entry = cacheData[getKey(mode, page)]
	if entry then
		return entry.items
	end
	return nil
end

function AvatarTemplateCache.getHasNextPage(mode: string, page: number?): boolean
	local entry = cacheData[getKey(mode, page)]
	return if entry then entry.hasNextPage else false
end

function AvatarTemplateCache.set(mode: string, items: { any }, page: number?, hasNextPage: boolean?)
	cacheData[getKey(mode, page)] = {
		timestamp = os.time(),
		items = items,
		hasNextPage = hasNextPage == true,
	}
end

function AvatarTemplateCache.add(mode: string, item: any)
	local key = getKey(mode, 1)
	if cacheData[key] then
		table.insert(cacheData[key].items, 1, item)
	end
end

function AvatarTemplateCache.clear(mode: string)
	for key in pairs(cacheData) do
		if string.sub(key, 1, #mode + 6) == mode .. ":page:" then
			cacheData[key] = nil
		end
	end
end

function AvatarTemplateCache.isStale(mode: string, maxAgeSeconds: number, page: number?): boolean
	local entry = cacheData[getKey(mode, page)]
	if not entry or entry.timestamp == 0 then
		return true
	end
	return (os.time() - entry.timestamp) > maxAgeSeconds
end

return AvatarTemplateCache
