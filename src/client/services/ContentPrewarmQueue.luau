local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ContentPrewarmQueue = {}

local MAX_CONCURRENT = 2
local currentProcessing = 0
local queue = {}
local processingSet = {} -- to avoid prewarming the same item multiple times
local prewarmedSet = {}
local dummyPool = {}

local function getDummyRig()
	if #dummyPool > 0 then
		return table.remove(dummyPool)
	end

	-- We clone the local player's character as the base rig
	local localPlayer = Players.LocalPlayer
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

	local previousArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = previousArchivable

	if clone then
		clone.Name = "PrewarmRig"
		-- Place in Workspace but far away so physics runs but it's not visible
		clone.Parent = Workspace
		local rootPart = clone:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.Anchored = true
		end
		clone:PivotTo(CFrame.new(0, 10000, 0))
	end

	return clone
end

local function releaseDummyRig(rig)
	if rig then
		table.insert(dummyPool, rig)
	end
end

local function applyPayloadToDescription(description, payload)
	if payload.propertyName and payload.assetIds then
		if #payload.assetIds > 0 then
			local id = tostring(payload.assetIds[#payload.assetIds])
			local pcallOk = pcall(function()
				description[payload.propertyName] = id
			end)
		end
	end

	if payload.bodyParts then
		for partName, assetId in pairs(payload.bodyParts) do
			pcall(function()
				description[partName] = assetId
			end)
		end
	end

	if payload.animations then
		for animName, assetId in pairs(payload.animations) do
			pcall(function()
				description[animName] = assetId
			end)
		end
	end
end

local function processQueue()
	while #queue > 0 and currentProcessing < MAX_CONCURRENT do
		local payload = table.remove(queue, 1)

		if prewarmedSet[payload.key] then
			continue
		end

		currentProcessing += 1
		prewarmedSet[payload.key] = true

		task.spawn(function()
			local rig = getDummyRig()
			if rig then
				local humanoid = rig:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local description = Instance.new("HumanoidDescription")
					applyPayloadToDescription(description, payload)

					pcall(function()
						-- This forces Roblox to download and cache the asset's meshes/textures
						humanoid:ApplyDescription(description)
					end)
				end
				releaseDummyRig(rig)
			end

			currentProcessing -= 1
			processQueue()
		end)
	end
end

function ContentPrewarmQueue.queueItems(payloads, limit)
	local count = 0
	for _, payload in ipairs(payloads) do
		if count >= limit then
			break
		end

		-- Only queue if it has assetIds or bodyParts or animations (not Failed)
		if payload.kind == "Emote" or payload.kind == "AnimationBundle" then
			-- Skip prewarm for emotes and animation bundles, they resolve lazily or parse directly
			continue
		end

		if
			payload.kind ~= "Failed"
			and not prewarmedSet[payload.key]
			and not processingSet[payload.key]
		then
			processingSet[payload.key] = true
			table.insert(queue, payload)
			count += 1
		end
	end

	processQueue()
end

return ContentPrewarmQueue
