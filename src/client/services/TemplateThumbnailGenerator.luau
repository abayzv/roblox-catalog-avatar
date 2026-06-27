local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local HumanoidDescriptionSerializer = require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)

local TEMPLATE_CARD_PAGE_SIZE = 10
local THUMBNAIL_JOB_DELAY = 0.08
local MAX_STATIC_THUMBNAIL_CACHE = 20
local ENABLE_BREAK_JOINTS_FOR_STATIC_THUMBNAIL = false

local TemplateThumbnailGenerator = {}

-- Internal State
local queue = {}
local isProcessing = false
local staticModelCache = {}
local cacheOrder = {}
local activePageToken = nil
local jobCounter = 0

local generatorWorldModel = Instance.new("WorldModel")
generatorWorldModel.Name = "ThumbnailGeneratorContainer"
if not RunService:IsServer() then
	pcall(function() generatorWorldModel.Parent = ReplicatedStorage end)
end

local function getBaseRig()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local rig = assets:FindFirstChild("BaseThumbnailRig")
		if rig and rig:IsA("Model") then
			return rig
		end
	end
	
	-- Fallback if rig is missing (though user confirmed they have it)
	warn("[TemplateThumbnailGenerator] BaseThumbnailRig not found in ReplicatedStorage.Assets! Using empty model fallback.")
	local m = Instance.new("Model")
	local h = Instance.new("Humanoid")
	h.Parent = m
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Parent = m
	m.PrimaryPart = hrp
	return m
end

local function sanitizeStaticAvatar(model: Model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("Humanoid") then
			inst:Destroy()
		elseif inst:IsA("Animator") then
			inst:Destroy()
		elseif inst:IsA("AnimationController") then
			inst:Destroy()
		elseif inst:IsA("Animation") then
			inst:Destroy()
		elseif inst:IsA("Script") or inst:IsA("LocalScript") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanTouch = false
			inst.CanQuery = false
			inst.Massless = true
		end
	end
	
	if ENABLE_BREAK_JOINTS_FOR_STATIC_THUMBNAIL then
		model:BreakJoints()
	end
end

local function positionCamera(camera: Camera, staticModel: Model)
	local boundingCFrame, boundingSize = staticModel:GetBoundingBox()
	local center = boundingCFrame.Position
	local height = math.max(boundingSize.Y, 5)
	local width = math.max(boundingSize.X, boundingSize.Z, 3)
	local distance = math.max(height * 2.65, width * 3.1, 13)
	local target = center + Vector3.new(0, height * 0.04, 0)
	local cameraPosition = target + Vector3.new(0, height * 0.04, distance)

	camera.FieldOfView = 31
	camera.CFrame = CFrame.new(cameraPosition, target)
	
	-- Rotate model to face camera
	staticModel:PivotTo(CFrame.Angles(0, math.rad(180), 0))
end

function TemplateThumbnailGenerator.clearViewport(viewportFrame: ViewportFrame)
	for _, child in ipairs(viewportFrame:GetChildren()) do
		child:Destroy()
	end
	viewportFrame.CurrentCamera = nil
end

local function renderStaticModelToViewport(viewportFrame: ViewportFrame, staticModel: Model)
	TemplateThumbnailGenerator.clearViewport(viewportFrame)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewportFrame

	staticModel.Parent = worldModel

	local camera = Instance.new("Camera")
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	positionCamera(camera, staticModel)
end

local function addToCache(templateId: string, staticModel: Model)
	if staticModelCache[templateId] then
		-- Move to front of LRU
		for i, id in ipairs(cacheOrder) do
			if id == templateId then
				table.remove(cacheOrder, i)
				break
			end
		end
	else
		-- Evict if full
		if #cacheOrder >= MAX_STATIC_THUMBNAIL_CACHE then
			local oldestTemplateId = table.remove(cacheOrder, 1)
			local cached = staticModelCache[oldestTemplateId]
			if cached then
				cached:Destroy()
			end
			staticModelCache[oldestTemplateId] = nil
		end
	end
	
	table.insert(cacheOrder, templateId)
	staticModelCache[templateId] = staticModel
end

local function processJob(job)
	-- Double check page token before processing
	if job.pageToken ~= activePageToken then
		return
	end
	
	-- Check cache again in case it was loaded while waiting
	if staticModelCache[job.templateId] then
		local clone = staticModelCache[job.templateId]:Clone()
		renderStaticModelToViewport(job.viewportFrame, clone)
		return
	end
	
	local generatorRig = getBaseRig():Clone()
	generatorRig.Parent = generatorWorldModel

	local humanoid = generatorRig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		generatorRig:Destroy()
		warn("[TemplateThumbnailGenerator] Generator rig missing Humanoid")
		return
	end

	local description = HumanoidDescriptionSerializer.deserialize(job.descriptionSnapshot)

	local ok, err = pcall(function()
		humanoid:ApplyDescriptionResetAsync(
			description,
			Enum.AssetTypeVerification.Default
		)
	end)

	if not ok then
		generatorRig:Destroy()
		warn("[TemplateThumbnailGenerator] Failed to apply description:", err)
		return
	end
	
	-- Make sure we are still on the same page after the async call!
	if job.pageToken ~= activePageToken then
		generatorRig:Destroy()
		return
	end

	local staticModel = generatorRig:Clone()
	generatorRig:Destroy()

	sanitizeStaticAvatar(staticModel)
	
	-- Cache the sanitized model
	addToCache(job.templateId, staticModel)

	-- Render a clone to the Viewport
	if job.viewportFrame and job.viewportFrame.Parent then
		local cloneToRender = staticModel:Clone()
		renderStaticModelToViewport(job.viewportFrame, cloneToRender)
	end
end

local function processQueue()
	if isProcessing then
		return
	end

	isProcessing = true

	while #queue > 0 do
		local job = table.remove(queue, 1)

		if job.pageToken == activePageToken then
			processJob(job)
			task.wait(THUMBNAIL_JOB_DELAY)
		end
	end

	isProcessing = false
end

function TemplateThumbnailGenerator.renderTemplateCard(
	templateId: string,
	descriptionSnapshot: table,
	viewportFrame: ViewportFrame,
	options: table?
)
	local pageToken = options and options.pageToken
	
	-- Auto-set active page token if not provided or different
	if pageToken and activePageToken ~= pageToken then
		activePageToken = pageToken
		queue = {} -- clear old jobs
	end
	
	if staticModelCache[templateId] then
		local clone = staticModelCache[templateId]:Clone()
		renderStaticModelToViewport(viewportFrame, clone)
		return
	end
	
	jobCounter += 1
	table.insert(queue, {
		jobId = jobCounter,
		pageToken = activePageToken,
		templateId = templateId,
		descriptionSnapshot = descriptionSnapshot,
		viewportFrame = viewportFrame,
	})
	
	task.spawn(processQueue)
end

function TemplateThumbnailGenerator.cancelPage(pageToken: string)
	if activePageToken == pageToken then
		activePageToken = nil
		queue = {}
	end
end

function TemplateThumbnailGenerator.clearCache()
	for _, model in pairs(staticModelCache) do
		model:Destroy()
	end
	staticModelCache = {}
	cacheOrder = {}
end

return TemplateThumbnailGenerator
