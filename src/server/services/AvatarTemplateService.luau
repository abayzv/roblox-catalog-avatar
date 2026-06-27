local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local AvatarTemplateTypes = require(ReplicatedStorage.Shared.types.AvatarTemplateTypes)
local AvatarAppearanceService = require(script.Parent.AvatarAppearanceService)

local AvatarTemplateService = {}

local DataStoreService = game:GetService("DataStoreService")

local AvatarTemplateById = DataStoreService:GetDataStore("AvatarTemplateById_v1")
local CodeToTemplateId = DataStoreService:GetDataStore("CodeToTemplateId_v1")
local RecentAvatarTemplateIndex = DataStoreService:GetOrderedDataStore("RecentAvatarTemplateIndex_v1")

local mockStore = {
	templatesById = {} :: { [string]: AvatarTemplateTypes.AvatarTemplateRecord },
	templateIndex = {} :: { string }, -- List of templateIds
	codeToTemplateId = {} :: { [string]: string },
}

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

local function listRecentTemplatesFromDataStore(limit: number)
	local success, pages = pcall(function()
		return RecentAvatarTemplateIndex:GetSortedAsync(false, limit)
	end)
	
	if not success or not pages then
		warn("[AvatarTemplateService] Failed to fetch recent template index:", pages)
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
	return mockStore.templatesById[templateId]
end

function AvatarTemplateService.listTemplates(player: Player, params: any): AvatarTemplateTypes.ListTemplatesResponse
	local limit = params and params.limit or 30
	local query = params and params.query
	if query then query = string.lower(query) end
	
	local cards = {}
	local count = 0
	
	-- For MVP, just return recent from index (last added first)
	for i = #mockStore.templateIndex, 1, -1 do
		local templateId = mockStore.templateIndex[i]
		local record = mockStore.templatesById[templateId]
		
		if record then
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
				}
				table.insert(cards, card)
				count += 1
				if count >= limit then
					break
				end
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
	local globalCount = #mockStore.templateIndex
	
	local newRecord: AvatarTemplateTypes.AvatarTemplateRecord = {
		templateId = templateId,
		code = code,
		name = `Template {globalCount + 1}`,
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
	
	mockStore.templatesById[templateId] = newRecord
	table.insert(mockStore.templateIndex, templateId)
	mockStore.codeToTemplateId[code] = templateId
	
	local card: AvatarTemplateTypes.AvatarTemplateCardData = {
		templateId = newRecord.templateId,
		code = newRecord.code,
		name = newRecord.name,
		creatorUsername = newRecord.creatorUsername,
		thumbnailUrl = newRecord.thumbnail.imageUrl,
		thumbnailState = newRecord.thumbnail.state,
		loadCount = newRecord.loadCount,
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
	
	-- Keep mockStore updated for now so listTemplates doesn't break until we refactor it
	mockStore.templatesById[record.templateId] = record
	mockStore.codeToTemplateId[code] = record.templateId
	table.insert(mockStore.templateIndex, 1, record.templateId)
	
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
	
	local template = mockStore.templatesById[templateId]
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
		return AvatarTemplateService.saveTemplate(player)
	end
end

return AvatarTemplateService
