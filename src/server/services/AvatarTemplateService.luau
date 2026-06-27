local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local AvatarTemplateTypes = require(ReplicatedStorage.Shared.types.AvatarTemplateTypes)
local AvatarAppearanceService = require(script.Parent.AvatarAppearanceService)

local AvatarTemplateService = {}

local DataStoreService = game:GetService("DataStoreService")

local AvatarTemplateById = DataStoreService:GetDataStore("AvatarTemplateById_v1")
local CodeToTemplateId = DataStoreService:GetDataStore("CodeToTemplateId_v1")
local RecentAvatarTemplateIndex = DataStoreService:GetOrderedDataStore("RecentAvatarTemplateIndex_v1")
local UserAvatarTemplateIndex = DataStoreService:GetOrderedDataStore("UserAvatarTemplateIndex_v1")

local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

local function generateUniqueCode(): string
	local maxAttempts = 5
	for attempt = 1, maxAttempts do
		local code = ""
		for i = 1, 5 do
			local index = math.random(1, #ALPHABET)
			code ..= string.sub(ALPHABET, index, index)
		end
		
		-- Check DataStore directly
		local success, result = pcall(function()
			return CodeToTemplateId:GetAsync("code:" .. code)
		end)
		
		-- If success and result is nil, the code is unique
		if success and result == nil then
			return code
		end
	end
	return "ERROR" -- Fallback if collision persists
end

local function saveTemplateToDataStore(record: AvatarTemplateTypes.AvatarTemplateRecord): boolean
	local success, err = pcall(function()
		-- Write to main store
		AvatarTemplateById:SetAsync("template:" .. record.templateId, record)
		
		-- Write code mapping
		CodeToTemplateId:SetAsync("code:" .. record.code, {
			templateId = record.templateId,
			createdAt = record.createdAt,
		})
		
		-- Write to recent ordered index
		RecentAvatarTemplateIndex:SetAsync(record.templateId, record.createdAt)
		
		-- Write to user's ordered index
		local UserIndex = DataStoreService:GetOrderedDataStore("UserAvatarTemplateIndex_v1", tostring(record.creatorUserId))
		UserIndex:SetAsync(record.templateId, record.createdAt)
	end)
	
	if not success then
		warn("[AvatarTemplateService] Failed to save template to DataStore:", err)
		return false
	end
	
	return true
end

local function getTemplateFromDataStore(templateId: string): AvatarTemplateTypes.AvatarTemplateRecord?
	local success, result = pcall(function()
		return AvatarTemplateById:GetAsync("template:" .. templateId)
	end)
	
	if success and result then
		return result
	end
	
	return nil
end

local function getTemplateByCodeFromDataStore(code: string): AvatarTemplateTypes.AvatarTemplateRecord?
	local success, result = pcall(function()
		return CodeToTemplateId:GetAsync("code:" .. code)
	end)
	
	if success and result and result.templateId then
		return getTemplateFromDataStore(result.templateId)
	end
	
	return nil
end

local function listTemplatesFromDataStore(limit: number, mode: string?, userId: number?)
	local success, pages = pcall(function()
		local indexToUse = RecentAvatarTemplateIndex
		if mode == "mine" and userId then
			indexToUse = DataStoreService:GetOrderedDataStore("UserAvatarTemplateIndex_v1", tostring(userId))
		end
		return indexToUse:GetSortedAsync(false, limit)
	end)
	
	if not success or not pages then
		warn("[AvatarTemplateService] Failed to fetch template index:", pages)
		return {}
	end
	
	local successPage, currentPage = pcall(function()
		return pages:GetCurrentPage()
	end)
	
	if not successPage or not currentPage then
		return {}
	end
	
	local results = {}
	for _, item in ipairs(currentPage) do
		local templateId = item.key
		local record = getTemplateFromDataStore(templateId)
		if record then
			table.insert(results, record)
		end
	end
	
	return results
end

function AvatarTemplateService.getTemplate(templateId: string): AvatarTemplateTypes.AvatarTemplateRecord?
	return getTemplateFromDataStore(templateId)
end

function AvatarTemplateService.listTemplates(player: Player, params: any): AvatarTemplateTypes.ListTemplatesResponse
	local limit = params and params.limit or 30
	local query = params and params.query
	local mode = params and params.mode or "all"
	if query then query = string.lower(query) end
	
	local recentRecords = listTemplatesFromDataStore(limit, mode, player.UserId)
	local cards = {}
	local count = 0
	
	for _, record in ipairs(recentRecords) do
		local matches = true
		if query and query ~= "" then
			local codeMatch = string.find(string.lower(record.code), query, 1, true)
			local nameMatch = string.find(string.lower(record.name), query, 1, true)
			if not codeMatch and not nameMatch then
				matches = false
			end
		end
		
		if matches then
			local card: AvatarTemplateTypes.AvatarTemplateCardData = {
				templateId = record.templateId,
				code = record.code,
				name = record.name,
				creatorUsername = record.creatorUsername,
				thumbnailUrl = record.thumbnail.imageUrl,
				thumbnailState = record.thumbnail.state,
				loadCount = record.loadCount,
				descriptionSnapshot = record.descriptionSnapshot,
			}
			table.insert(cards, card)
			count += 1
			if count >= limit then
				break
			end
		end
	end
	
	return {
		success = true,
		templates = cards,
		nextCursor = nil,
	}
end

function AvatarTemplateService.saveCurrentAvatarAsTemplate(player: Player): AvatarTemplateTypes.SaveTemplateResponse
	local liveSnapshot = AvatarAppearanceService.getLiveSnapshot(player)
	
	if not liveSnapshot then
		return {
			success = false,
			error = "No LiveSnapshot found. Cannot save template.",
		}
	end
	
	local templateId = HttpService:GenerateGUID(false)
	local code = generateUniqueCode()
	local globalCount = 0 -- In DataStore MVP we won't show global count easily, use random for dummy name
	
	local newRecord: AvatarTemplateTypes.AvatarTemplateRecord = {
		templateId = templateId,
		code = code,
		name = `Template {math.random(1000, 9999)}`,
		creatorUserId = player.UserId,
		creatorUsername = player.Name,
		creatorDisplayName = player.DisplayName,
		descriptionSnapshot = table.clone(liveSnapshot),
		thumbnail = {
			imageUrl = nil,
			state = "Placeholder",
		},
		loadCount = 0,
		createdAt = os.time(),
		updatedAt = os.time(),
		version = 1,
	}
	
	local success = saveTemplateToDataStore(newRecord)
	if not success then
		return {
			success = false,
			error = "Failed to save template to database."
		}
	end
	
	local card: AvatarTemplateTypes.AvatarTemplateCardData = {
		templateId = newRecord.templateId,
		code = newRecord.code,
		name = newRecord.name,
		creatorUsername = newRecord.creatorUsername,
		thumbnailUrl = newRecord.thumbnail.imageUrl,
		thumbnailState = newRecord.thumbnail.state,
		loadCount = newRecord.loadCount,
		descriptionSnapshot = newRecord.descriptionSnapshot,
	}
	
	return {
		success = true,
		template = card,
	}
end

local loadCooldowns = {} :: { [number]: number }
local saveCooldowns = {} :: { [number]: number }

local LOAD_COOLDOWN = 1 -- 1 second between loads
local SAVE_COOLDOWN = 3 -- 3 seconds between saves

function AvatarTemplateService.saveTemplate(player: Player): any
	local now = os.time()
	local lastSave = saveCooldowns[player.UserId] or 0
	if now - lastSave < SAVE_COOLDOWN then
		return { success = false, error = "Please wait before saving another template." }
	end
	
	local appearanceState = AvatarAppearanceService.getState(player)
	if not appearanceState or not appearanceState.liveSnapshot then
		return { success = false, error = "No live snapshot available" }
	end

	saveCooldowns[player.UserId] = now

	local code = generateUniqueCode()
	
	local record: AvatarTemplateTypes.AvatarTemplateRecord = {
		templateId = "Tpl_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)),
		code = code,
		name = player.Name .. "'s Avatar",
		creatorId = player.UserId,
		creatorUsername = player.Name,
		createdAt = os.time(),
		thumbnail = {
			imageUrl = nil,
			state = "Placeholder",
		},
		snapshot = appearanceState.liveSnapshot,
		isPublic = true,
		loadCount = 0,
	}
	
	local success = saveTemplateToDataStore(record)
	
	if not success then
		return {
			success = false,
			error = "Failed to save template to database."
		}
	end
	
	return {
		success = true,
		template = record,
	}
end

function AvatarTemplateService.loadTemplate(player: Player, templateId: string): AvatarTemplateTypes.LoadTemplateResponse
	local now = os.time()
	local lastLoad = loadCooldowns[player.UserId] or 0
	if now - lastLoad < LOAD_COOLDOWN then
		return { success = false, error = "Please wait before loading another template." }
	end
	
	local template = getTemplateFromDataStore(templateId)
	if not template then
		return {
			success = false,
			error = "Template not found",
		}
	end
	
	loadCooldowns[player.UserId] = now
	
	local success, err = AvatarAppearanceService.applyDescriptionSnapshot(player, template.snapshot, "avatar_loader")
	if not success then
		return {
			success = false,
			error = err,
		}
	end
	
	template.loadCount += 1
	template.updatedAt = os.time()
	
	local liveSnapshot = AvatarAppearanceService.getLiveSnapshot(player)
	local liveRevision = AvatarAppearanceService.getLiveRevision(player)
	
	return {
		success = true,
		liveSnapshot = liveSnapshot,
		liveRevision = liveRevision,
		templateId = templateId,
	}
end

local function normalizeCode(query: string): string?
	local q = string.upper(query)
	q = string.gsub(q, "%s+", "")
	if string.match(q, "^[A-Z2-9]+$") and #q == 5 then
		return q
	end
	return nil
end

function AvatarTemplateService.searchAvatarLoader(player: Player, query: string?): AvatarTemplateTypes.SearchAvatarLoaderResponse
	local q = if query then string.gsub(query, "^%s*(.-)%s*$", "%1") else ""
	if q == "" then
		return { success = true, resultType = "empty", message = "Please enter a code or username." }
	end

	-- 1. Try code lookup (direct load)
	local code = normalizeCode(q)
	if code then
		local template = getTemplateByCodeFromDataStore(code)
		if template then
			local loadResult = AvatarTemplateService.loadTemplate(player, template.templateId)
			if loadResult.success then
				return {
					success = true,
					resultType = "loaded_template_code",
					liveSnapshot = loadResult.liveSnapshot,
					liveRevision = loadResult.liveRevision,
					code = template.code,
				}
			else
				return {
					success = false,
					resultType = "error",
					message = "Failed to load template code: " .. tostring(loadResult.error),
				}
			end
		end
	end
	
	-- 2. Try Roblox user lookup (direct load)
	local targetUserId = tonumber(q)
	local targetUsername = q
	if not targetUserId then
		local success, userId = pcall(function()
			local Players = game:GetService("Players")
			return Players:GetUserIdFromNameAsync(q)
		end)
		if success and userId then
			targetUserId = userId
		end
	else
		pcall(function()
			targetUsername = game:GetService("Players"):GetNameFromUserIdAsync(targetUserId)
		end)
	end
	
	if targetUserId then
		local success, description = pcall(function()
			return game:GetService("Players"):GetHumanoidDescriptionFromUserId(targetUserId)
		end)
		
		if success and description then
			local HumanoidDescriptionSerializer = require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)
			local snapshot = HumanoidDescriptionSerializer.serialize(description)
			description:Destroy()
			
			local applySuccess, err = AvatarAppearanceService.applyDescriptionSnapshot(player, snapshot, "avatar_loader_username")
			if applySuccess then
				return {
					success = true,
					resultType = "loaded_username_avatar",
					liveSnapshot = AvatarAppearanceService.getLiveSnapshot(player),
					liveRevision = AvatarAppearanceService.getLiveRevision(player),
					resolvedUserId = targetUserId,
					resolvedUsername = targetUsername,
				}
			else
				return {
					success = false,
					resultType = "error",
					message = "Failed to apply user avatar: " .. tostring(err),
				}
			end
		end
	end
	
	-- 3. Template name fallback
	local recentRecords = listRecentTemplatesFromDataStore(30)
	local cards = {}
	local qLower = string.lower(q)
	
	for _, record in ipairs(recentRecords) do
		local nameMatch = string.find(string.lower(record.name), qLower, 1, true)
		if nameMatch then
			local card: AvatarTemplateTypes.AvatarTemplateCardData = {
				templateId = record.templateId,
				code = record.code,
				name = record.name,
				creatorUsername = record.creatorUsername,
				thumbnailUrl = record.thumbnail.imageUrl,
				thumbnailState = record.thumbnail.state,
				loadCount = record.loadCount,
				descriptionSnapshot = record.descriptionSnapshot,
			}
			table.insert(cards, card)
		end
	end
	
	if #cards > 0 then
		return {
			success = true,
			resultType = "template_results",
			templates = cards,
		}
	end
	
	-- 4. Nothing found
	return {
		success = true,
		resultType = "empty",
		message = "Template atau username tidak ditemukan.",
	}
end

function AvatarTemplateService.loadRobloxOutfit(player: Player, userOutfitId: number): AvatarTemplateTypes.LoadTemplateResponse
	local now = os.time()
	local lastLoad = loadCooldowns[player.UserId] or 0
	if now - lastLoad < LOAD_COOLDOWN then
		return { success = false, error = "Please wait before loading another outfit." }
	end
	
	loadCooldowns[player.UserId] = now
	
	local RobloxOutfitConverter = require(script.Parent.RobloxOutfitConverter)
	local snapshot = RobloxOutfitConverter.getSnapshotFromOutfitId(userOutfitId)
	
	if not snapshot then
		return { success = false, error = "Failed to load outfit data from Roblox." }
	end
	
	local success, err = AvatarAppearanceService.applyDescriptionSnapshot(player, snapshot, "avatar_loader")
	if not success then
		return {
			success = false,
			error = err,
		}
	end
	
	local liveSnapshot = AvatarAppearanceService.getLiveSnapshot(player)
	local liveRevision = AvatarAppearanceService.getLiveRevision(player)
	
	return {
		success = true,
		liveSnapshot = liveSnapshot,
		liveRevision = liveRevision,
		templateId = "roblox_outfit_" .. userOutfitId, -- just a dummy id
	}
end

function AvatarTemplateService.init()
	local ListAvatarTemplatesRemote = require(ReplicatedStorage.Shared.remotes.ListAvatarTemplatesRemote)
	ListAvatarTemplatesRemote.OnServerInvoke = function(player: Player, params: any)
		return AvatarTemplateService.listTemplates(player, params)
	end
	
	local LoadAvatarTemplateRemote = require(ReplicatedStorage.Shared.remotes.LoadAvatarTemplateRemote)
	LoadAvatarTemplateRemote.OnServerInvoke = function(player: Player, templateId: string)
		return AvatarTemplateService.loadTemplate(player, templateId)
	end
	
	local SaveAvatarTemplateRemote = require(ReplicatedStorage.Shared.remotes.SaveAvatarTemplateRemote)
	SaveAvatarTemplateRemote.OnServerInvoke = function(player: Player)
		return AvatarTemplateService.saveCurrentAvatarAsTemplate(player)
	end
	
	local SearchAvatarLoaderRemote = require(ReplicatedStorage.Shared.remotes.SearchAvatarLoaderRemote)
	SearchAvatarLoaderRemote.OnServerInvoke = function(player: Player, query: string)
		return AvatarTemplateService.searchAvatarLoader(player, query)
	end
	
	local LoadRobloxOutfitRemote = require(ReplicatedStorage.Shared.remotes.LoadRobloxOutfitRemote)
	LoadRobloxOutfitRemote.OnServerInvoke = function(player: Player, userOutfitId: number)
		return AvatarTemplateService.loadRobloxOutfit(player, userOutfitId)
	end
end

return AvatarTemplateService
