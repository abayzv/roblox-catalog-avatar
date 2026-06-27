local AvatarTemplateCache = {}

type CacheEntry = {
	timestamp: number,
	items: { any },
}

local cacheData: { [string]: CacheEntry } = {
	all = { timestamp = 0, items = {} },
	mine = { timestamp = 0, items = {} },
}

function AvatarTemplateCache.get(mode: string): { any }?
	if cacheData[mode] then
		return cacheData[mode].items
	end
	return nil
end

function AvatarTemplateCache.set(mode: string, items: { any })
	if not cacheData[mode] then
		cacheData[mode] = { timestamp = 0, items = {} }
	end
	cacheData[mode].timestamp = os.time()
	cacheData[mode].items = items
end

function AvatarTemplateCache.add(mode: string, item: any)
	if cacheData[mode] then
		-- Insert at the beginning of the list
		table.insert(cacheData[mode].items, 1, item)
	end
end

function AvatarTemplateCache.clear(mode: string)
	if cacheData[mode] then
		cacheData[mode].timestamp = 0
		cacheData[mode].items = {}
	end
end

function AvatarTemplateCache.isStale(mode: string, maxAgeSeconds: number): boolean
	local entry = cacheData[mode]
	if not entry or entry.timestamp == 0 then
		return true
	end
	return (os.time() - entry.timestamp) > maxAgeSeconds
end

return AvatarTemplateCache
