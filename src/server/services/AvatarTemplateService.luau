local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local AvatarTemplateTypes = require(ReplicatedStorage.Shared.types.AvatarTemplateTypes)
local AvatarAppearanceService = require(script.Parent.AvatarAppearanceService)

local AvatarTemplateService = {}

-- TODO: replace with persistent store (DataStore/database wrapper)
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
		
		if not mockStore.codeToTemplateId[code] then
			return code
		end
	end
	return "ERROR" -- Fallback if collision persists
end

function AvatarTemplateService.getTemplate(templateId: string): AvatarTemplateTypes.AvatarTemplateRecord?
	return mockStore.templatesById[templateId]
end

function AvatarTemplateService.listTemplates(player: Player, params: any): AvatarTemplateTypes.ListTemplatesResponse
	local limit = params and params.limit or 30
	local cards = {}
	
	-- For MVP, just return recent from index (last added first)
	for i = #mockStore.templateIndex, math.max(1, #mockStore.templateIndex - limit + 1), -1 do
		local templateId = mockStore.templateIndex[i]
		local record = mockStore.templatesById[templateId]
		
		if record then
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

function AvatarTemplateService.loadTemplate(player: Player, templateId: string): AvatarTemplateTypes.LoadTemplateResponse
	local template = mockStore.templatesById[templateId]
	if not template then
		return {
			success = false,
			error = "Template not found",
		}
	end
	
	local success, err = AvatarAppearanceService.applyDescriptionSnapshot(player, template.descriptionSnapshot, "avatar_loader")
	
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

return AvatarTemplateService
