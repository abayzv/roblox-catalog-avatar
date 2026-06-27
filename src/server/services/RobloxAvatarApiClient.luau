local HttpService = game:GetService("HttpService")

local RobloxAvatarApiClient = {}

local AVATAR_API_BASE = "https://avatar.roproxy.com/v1"

function RobloxAvatarApiClient.getUserOutfits(userId: number)
	local url = AVATAR_API_BASE .. "/users/" .. tostring(userId) .. "/outfits?page=1&itemsPerPage=25"
	local success, response = pcall(function()
		return HttpService:GetAsync(url)
	end)
	
	if not success then
		warn("[RobloxAvatarApiClient] Failed to fetch outfits for user", userId, response)
		return nil
	end
	
	local decodeSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)
	
	if not decodeSuccess or not data or not data.data then
		warn("[RobloxAvatarApiClient] Failed to decode outfits response")
		return nil
	end
	
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

function RobloxAvatarApiClient.getOutfitThumbnails(userOutfitIds: {number})
	if #userOutfitIds == 0 then return {} end
	
	-- Note: Roblox thumbnails API uses thumbnails.roblox.com
	local idsString = table.concat(userOutfitIds, ",")
	local url = "https://thumbnails.roproxy.com/v1/users/outfits?userOutfitIds=" .. idsString .. "&size=150x150&format=Png&isCircular=false"
	
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
