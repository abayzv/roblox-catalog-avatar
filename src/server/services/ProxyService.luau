local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProxyService = {}
local bundleCache = {} -- [assetId] = bundleId

local remoteName = "ResolveBundleFromAssetRemote"
local remote = ReplicatedStorage:FindFirstChild(remoteName)
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = remoteName
	remote.Parent = ReplicatedStorage
end

function ProxyService.initialize()
	remote.OnServerInvoke = function(player, assetIds)
		if type(assetIds) ~= "table" then
			return {}
		end

		local results = {}
		local toFetch = {}

		for _, assetId in ipairs(assetIds) do
			if type(assetId) == "number" or type(assetId) == "string" then
				local id = tonumber(assetId)
				if bundleCache[id] ~= nil then
					if bundleCache[id] ~= 0 then
						results[tostring(id)] = bundleCache[id]
					end
				else
					table.insert(toFetch, id)
				end
			end
		end

		for _, assetId in ipairs(toFetch) do
			local url = "https://roblox-catalog-bundle-proxy.abayzv.workers.dev/assets/"
				.. assetId
				.. "/bundles"
			local ok, response = pcall(function()
				return HttpService:GetAsync(url)
			end)

			local bundleId = 0
			if ok and response then
				local okDecode, decoded = pcall(function()
					return HttpService:JSONDecode(response)
				end)
				if
					okDecode
					and decoded
					and decoded.data
					and decoded.data[1]
					and decoded.data[1].id
				then
					bundleId = decoded.data[1].id
				end
			end

			bundleCache[assetId] = bundleId
			if bundleId ~= 0 then
				results[tostring(assetId)] = bundleId
			end
		end

		return results
	end
end

return ProxyService
