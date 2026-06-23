local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Theme = require(script.Parent.Parent.theme.Theme)
local usePreviewState = require(script.Parent.Parent.Parent.hooks.usePreviewState)

local LOCAL_PLAYER = Players.LocalPlayer
local INITIAL_RIG_YAW = math.rad(180)
local DRAG_ROTATION_SPEED = 0.011
local IDLE_ANIMATION_BY_RIG_TYPE = {
	[Enum.HumanoidRigType.R6] = "rbxassetid://180435571",
	[Enum.HumanoidRigType.R15] = "rbxassetid://507766666",
}

local function splitCsv(value: string?): { string }
	local values = {}
	if not value or value == "" then
		return values
	end

	for token in string.gmatch(value, "[^,]+") do
		local trimmed = string.gsub(token, "^%s*(.-)%s*$", "%1")
		if trimmed ~= "" then
			table.insert(values, trimmed)
		end
	end

	return values
end

local function joinUniqueCsv(existing: string?, assetIds: { string }): string
	local seen = {}
	local values = {}

	for _, value in ipairs(splitCsv(existing)) do
		if not seen[value] then
			seen[value] = true
			table.insert(values, value)
		end
	end

	for _, assetId in ipairs(assetIds) do
		if assetId ~= "" and not seen[assetId] then
			seen[assetId] = true
			table.insert(values, assetId)
		end
	end

	return table.concat(values, ",")
end

local function prepareRig(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function pivotRig(model: Model, yaw: number?)
	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		model.PrimaryPart = humanoidRootPart
	end

	model:PivotTo(CFrame.Angles(0, yaw or INITIAL_RIG_YAW, 0))
end

local function frameCamera(camera: Camera, model: Model)
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	local center = boundingCFrame.Position
	local height = math.max(boundingSize.Y, 5)
	local width = math.max(boundingSize.X, boundingSize.Z, 3)
	local distance = math.max(height * 2.65, width * 3.1, 13)
	local target = center + Vector3.new(0, height * 0.04, 0)
	local cameraPosition = target + Vector3.new(0, height * 0.04, distance)

	camera.CFrame = CFrame.new(cameraPosition, target)
end

local function playIdleAnimation(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == "CatalogPreviewIdle" then
			track:Stop(0.1)
		end
	end

	local animation = Instance.new("Animation")
	animation.Name = "CatalogPreviewIdle"
	animation.AnimationId = IDLE_ANIMATION_BY_RIG_TYPE[humanoid.RigType]
		or IDLE_ANIMATION_BY_RIG_TYPE[Enum.HumanoidRigType.R15]

	local ok, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if ok then
		local track = trackOrError
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		track:Play(0.2, 1, 1)
	else
		warn("[CatalogPreview] Failed to play viewport idle animation:", trackOrError)
	end

	animation:Destroy()
end

local function cloneLocalCharacter(): Model?
	local character = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
	if not character then
		return nil
	end

	if not character:FindFirstChildOfClass("Humanoid") then
		character:WaitForChild("Humanoid", 5)
	end

	if not character:FindFirstChild("HumanoidRootPart") then
		character:WaitForChild("HumanoidRootPart", 5)
	end

	local previousArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = previousArchivable

	if clone then
		clone.Name = "CatalogPreviewRig"
		prepareRig(clone)
		pivotRig(clone)
	end

	return clone
end

local function getPreviewAssetIds(previewItems): { string }
	local assetIds = {}

	for _, item in pairs(previewItems) do
		local assetId = item.assetId
		if assetId then
			table.insert(assetIds, tostring(assetId))
		end
	end

	return assetIds
end

local function applyPreviewDescription(rig: Model, previewItems, camera: Camera)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local description = humanoid:GetAppliedDescription()
	description.HatAccessory =
		joinUniqueCsv(description.HatAccessory, getPreviewAssetIds(previewItems))

	local ok, err = pcall(function()
		humanoid:ApplyDescription(description)
	end)

	if not ok then
		warn("[CatalogPreview] Failed to apply viewport description:", err)
	end

	task.defer(function()
		if rig.Parent then
			prepareRig(rig)
			pivotRig(rig)
			frameCamera(camera, rig)
			playIdleAnimation(rig)
		end
	end)
end

local function setupViewport(viewport: ViewportFrame, previewItems)
	viewport:ClearAllChildren()

	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.FieldOfView = 31
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "PreviewWorld"
	worldModel.Parent = viewport

	local rig = cloneLocalCharacter()
	if not rig then
		return nil
	end

	rig.Parent = worldModel
	frameCamera(camera, rig)
	applyPreviewDescription(rig, previewItems, camera)
	playIdleAnimation(rig)

	return rig
end

local function isPrimaryDragInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isDragMoveInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function AvatarPreviewViewport()
	local viewportRef = React.useRef(nil)
	local rigRef = React.useRef(nil)
	local draggingRef = React.useRef(false)
	local lastDragXRef = React.useRef(0)
	local yawRef = React.useRef(INITIAL_RIG_YAW)
	local previewItems = usePreviewState()
	local previewKeyParts = {}

	for itemId in pairs(previewItems) do
		table.insert(previewKeyParts, itemId)
	end
	table.sort(previewKeyParts)

	local previewKey = table.concat(previewKeyParts, "|")

	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then
			return nil
		end

		yawRef.current = INITIAL_RIG_YAW
		rigRef.current = setupViewport(viewport, previewItems)

		return function()
			rigRef.current = nil
			if viewport then
				viewport:ClearAllChildren()
			end
		end
	end, { previewKey })

	local beginDrag = React.useCallback(function(_, input)
		if not isPrimaryDragInput(input) then
			return
		end

		draggingRef.current = true
		lastDragXRef.current = input.Position.X
	end, {})

	local updateDrag = React.useCallback(function(_, input)
		if not draggingRef.current or not isDragMoveInput(input) then
			return
		end

		local nextX = input.Position.X
		local deltaX = nextX - lastDragXRef.current
		lastDragXRef.current = nextX
		yawRef.current += deltaX * DRAG_ROTATION_SPEED

		local rig = rigRef.current
		if rig then
			pivotRig(rig, yawRef.current)
		end
	end, {})

	local endDrag = React.useCallback(function(_, input)
		if isPrimaryDragInput(input) then
			draggingRef.current = false
		end
	end, {})

	return React.createElement("Frame", {
		BackgroundColor3 = Theme.Color.Panel,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, Theme.Radius.Panel),
		}),

		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, Theme.Space.MD),
			PaddingBottom = UDim.new(0, Theme.Space.MD),
			PaddingLeft = UDim.new(0, Theme.Space.MD),
			PaddingRight = UDim.new(0, Theme.Space.MD),
		}),

		Stage = React.createElement("Frame", {
			BackgroundColor3 = Theme.Color.PanelSoft,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 11,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.LG),
			}),

			Gradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Theme.Color.Background),
				}),
				Rotation = 90,
			}),

			Viewport = React.createElement("ViewportFrame", {
				Active = true,
				Ambient = Color3.fromRGB(210, 210, 220),
				BackgroundTransparency = 1,
				LightColor = Color3.fromRGB(255, 255, 255),
				LightDirection = Vector3.new(-0.5, -0.9, -0.4),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 12,
				ref = viewportRef,

				[React.Event.InputBegan] = beginDrag,
				[React.Event.InputChanged] = updateDrag,
				[React.Event.InputEnded] = endDrag,
			}),
		}),
	})
end

return AvatarPreviewViewport
