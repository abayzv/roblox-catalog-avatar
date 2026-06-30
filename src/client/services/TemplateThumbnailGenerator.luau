local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HumanoidDescriptionSerializer =
	require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)

local THUMBNAIL_JOB_DELAY = 0.08
local MAX_STATIC_THUMBNAIL_CACHE = 20

local TemplateThumbnailGenerator = {}

-- Internal State
local queue = {}
local isProcessing = false
local staticModelCache = {}
local cacheOrder = {}
local inFlightJobs = {}
local activePageToken = nil
local jobCounter = 0

local function getBaseRig()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local rig = assets:FindFirstChild("BaseThumbnailRig")
		if rig and rig:IsA("Model") then
			return rig
		end
	end

	return nil
end

local function sanitizeStaticAvatar(model: Model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("Humanoid") then
			-- Mode B: StaticWithHumanoidFallback
			-- Keeping Humanoid because removing it breaks 2D clothing composites and dynamic head textures
			inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			inst.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			inst.EvaluateStateMachine = false
		elseif inst:IsA("Animator") then
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

	-- No BreakJoints, keep Motor6D, Weld, Attachment, WrapLayer, etc. intact
end

local function positionCamera(camera: Camera, staticModel: Model)
	-- Rotate model to face camera and place it at origin
	staticModel:PivotTo(CFrame.Angles(0, math.rad(180), 0))

	local boundingCFrame, boundingSize = staticModel:GetBoundingBox()
	local center = boundingCFrame.Position
	local height = math.max(boundingSize.Y, 5)
	local width = math.max(boundingSize.X, boundingSize.Z, 3)
	local distance = math.max(height * 2.65, width * 3.1, 13)
	local target = center + Vector3.new(0, height * 0.04, 0)
	local cameraPosition = target + Vector3.new(0, height * 0.04, distance)

	camera.FieldOfView = 31
	camera.CFrame = CFrame.new(cameraPosition, target)
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

local function clearInFlightJobs()
	inFlightJobs = {}
end

local function clearInFlightJob(templateId: string, pageToken: string?)
	local inFlight = inFlightJobs[templateId]
	if not inFlight then
		return
	end

	if pageToken and inFlight.pageToken ~= pageToken then
		return
	end

	inFlightJobs[templateId] = nil
end

local function addWaiter(
	templateId: string,
	pageToken: string?,
	viewportFrame: ViewportFrame,
	options: table?
)
	local inFlight = inFlightJobs[templateId]
	if not inFlight then
		return
	end

	for _, waiter in ipairs(inFlight.waiters) do
		if waiter.viewportFrame == viewportFrame then
			waiter.pageToken = pageToken
			waiter.onRendered = options and options.onRendered
			waiter.onFailed = options and options.onFailed
			return
		end
	end

	table.insert(inFlight.waiters, {
		pageToken = pageToken,
		viewportFrame = viewportFrame,
		onRendered = options and options.onRendered,
		onFailed = options and options.onFailed,
	})
end

local function failWaiters(templateId: string, pageToken: string?)
	local inFlight = inFlightJobs[templateId]
	clearInFlightJob(templateId, pageToken)

	if not inFlight then
		return
	end

	if pageToken and inFlight.pageToken ~= pageToken then
		return
	end

	for _, waiter in ipairs(inFlight.waiters) do
		if waiter.pageToken == pageToken and waiter.onFailed then
			task.defer(waiter.onFailed)
		end
	end
end

local function renderWaiters(templateId: string, pageToken: string?, staticModel: Model)
	local inFlight = inFlightJobs[templateId]
	clearInFlightJob(templateId, pageToken)

	if not inFlight then
		return
	end

	if pageToken and inFlight.pageToken ~= pageToken then
		return
	end

	for _, waiter in ipairs(inFlight.waiters) do
		if waiter.pageToken == pageToken then
			if waiter.viewportFrame and waiter.viewportFrame.Parent then
				local clone = staticModel:Clone()
				renderStaticModelToViewport(waiter.viewportFrame, clone)
				if waiter.onRendered then
					task.defer(waiter.onRendered)
				end
			elseif waiter.onFailed then
				task.defer(waiter.onFailed)
			end
		end
	end
end

local function processJob(job)
	-- Double check page token before processing
	if job.pageToken ~= activePageToken then
		clearInFlightJob(job.templateId, job.pageToken)
		return
	end

	-- Check cache again in case it was loaded while waiting
	if staticModelCache[job.templateId] then
		renderWaiters(job.templateId, job.pageToken, staticModelCache[job.templateId])
		return
	end

	local baseRig = getBaseRig()
	if not baseRig then
		warn("[TemplateThumbnailGenerator] Cannot generate thumbnail: BaseThumbnailRig missing.")
		failWaiters(job.templateId, job.pageToken)
		return
	end

	local generatorRig = baseRig:Clone()

	local hrp = generatorRig:FindFirstChild("HumanoidRootPart")
	if hrp and not generatorRig.PrimaryPart then
		generatorRig.PrimaryPart = hrp
	end

	-- [Real Flow - Mode B: StaticWithHumanoidFallback]
	-- 1. Generate rig and place in temporary Workspace (fallback/workaround to ensure ApplyDescription loads assets)
	-- 2. Call ApplyDescriptionResetAsync
	-- 3. Clone generated result
	-- 4. Destroy generator rig
	-- 5. Sanitize clone (keep Humanoid to prevent 2D clothing composite destruction, remove Animator, keep all joints)
	-- 6. Render static clone to ViewportFrame

	-- Note: Placing in Workspace is a temporary workaround because ApplyDescription
	-- sometimes fails to fetch and build Layered Clothing meshes in ReplicatedStorage.
	-- We place it high in the sky to avoid FallenPartsDestroyHeight.
	generatorRig:PivotTo(CFrame.new(0, 100000, 0))
	generatorRig.Parent = game.Workspace

	local humanoid = generatorRig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		generatorRig:Destroy()
		warn("[TemplateThumbnailGenerator] Generator rig missing Humanoid")
		failWaiters(job.templateId, job.pageToken)
		return
	end

	local description = HumanoidDescriptionSerializer.deserialize(job.descriptionSnapshot)

	local ok, err = pcall(function()
		humanoid:ApplyDescriptionResetAsync(description, Enum.AssetTypeVerification.Default)
	end)

	if not ok then
		generatorRig:Destroy()
		warn("[TemplateThumbnailGenerator] Failed to apply description:", err)
		failWaiters(job.templateId, job.pageToken)
		return
	end

	-- Make sure we are still on the same page after the async call!
	if job.pageToken ~= activePageToken then
		generatorRig:Destroy()
		clearInFlightJob(job.templateId, job.pageToken)
		return
	end

	local staticModel = generatorRig:Clone()
	generatorRig:Destroy()

	sanitizeStaticAvatar(staticModel)

	-- Cache the sanitized model
	addToCache(job.templateId, staticModel)

	renderWaiters(job.templateId, job.pageToken, staticModel)
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
		clearInFlightJobs()
	end

	if staticModelCache[templateId] then
		if not viewportFrame or not viewportFrame.Parent then
			if options and options.onFailed then
				task.defer(options.onFailed)
			end
			return
		end

		local clone = staticModelCache[templateId]:Clone()
		renderStaticModelToViewport(viewportFrame, clone)
		if options and options.onRendered then
			task.defer(options.onRendered)
		end
		return
	end

	if inFlightJobs[templateId] then
		addWaiter(templateId, activePageToken, viewportFrame, options)
	else
		jobCounter += 1
		inFlightJobs[templateId] = {
			pageToken = activePageToken,
			waiters = {},
		}
		addWaiter(templateId, activePageToken, viewportFrame, options)
		table.insert(queue, {
			jobId = jobCounter,
			pageToken = activePageToken,
			templateId = templateId,
			descriptionSnapshot = descriptionSnapshot,
		})
	end

	task.spawn(processQueue)
end

function TemplateThumbnailGenerator.cancelPage(pageToken: string)
	if activePageToken == pageToken then
		activePageToken = nil
		queue = {}
		clearInFlightJobs()
	end
end

function TemplateThumbnailGenerator.clearCache()
	for _, model in pairs(staticModelCache) do
		model:Destroy()
	end
	staticModelCache = {}
	cacheOrder = {}
	clearInFlightJobs()
end

return TemplateThumbnailGenerator
