local HttpService = game:GetService("HttpService")

local RobloxAvatarApiClient = {}

local AVATAR_API_BASE = "https://avatar.roproxy.com/v1"

local cache = {}
local CACHE_DURATION = 60

function RobloxAvatarApiClient.getUserOutfits(userId: number)
	local now = os.time()
	if cache[userId] and now - cache[userId].timestamp < CACHE_DURATION then
		return cache[userId].data, nil
	end

	local url = AVATAR_API_BASE
		.. "/users/"
		.. tostring(userId)
		.. "/outfits?page=1&itemsPerPage=25"
	print("[RobloxAvatarApiClient] Fetching outfits from:", url)
	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if not success then
		warn("[RobloxAvatarApiClient] Failed to fetch outfits for user", userId, response)
		return nil, tostring(response)
	end

	local decodeSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not decodeSuccess or not data then
		warn("[RobloxAvatarApiClient] Failed to decode outfits response")
		return nil
	end

	if not data.data then
		warn("[RobloxAvatarApiClient] API response missing 'data' field. Full response:", response)
		return nil
	end

	print("[RobloxAvatarApiClient] Successfully decoded outfits. Count:", #data.data)

	cache[userId] = {
		timestamp = now,
		data = data.data,
	}

	return data.data
end

function RobloxAvatarApiClient.getOutfitDetails(userOutfitId: number)
	local url = AVATAR_API_BASE .. "/outfits/" .. tostring(userOutfitId) .. "/details"
	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if not success then
		warn("[RobloxAvatarApiClient] Failed to fetch outfit details", userOutfitId, response)
		return nil
	end

	local decodeSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not decodeSuccess or not data then
		warn("[RobloxAvatarApiClient] Failed to decode outfit details response")
		return nil
	end

	return data
end

function RobloxAvatarApiClient.getOutfitThumbnails(userOutfitIds: { number })
	if #userOutfitIds == 0 then
		return {}
	end

	-- Note: Roblox thumbnails API uses thumbnails.roblox.com
	local idsString = table.concat(userOutfitIds, ",")
	local url = "https://thumbnails.roproxy.com/v1/users/outfits?userOutfitIds="
		.. idsString
		.. "&size=150x150&format=Png&isCircular=false"

	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if not success then
		warn("[RobloxAvatarApiClient] Failed to fetch outfit thumbnails", response)
		return {}
	end

	local decodeSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not decodeSuccess or not data or not data.data then
		warn("[RobloxAvatarApiClient] Failed to decode outfit thumbnails")
		return {}
	end

	local thumbnailsMap = {}
	for _, item in ipairs(data.data) do
		thumbnailsMap[item.targetId] = {
			imageUrl = item.imageUrl,
			state = item.state,
		}
	end

	return thumbnailsMap
end

return RobloxAvatarApiClient
