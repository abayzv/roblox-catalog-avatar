local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local GlassButton = require(script.Parent.Parent.atoms.GlassButton)
local useAppearanceState = require(script.Parent.Parent.Parent.hooks.useAppearanceState)
local usePreviewState = require(script.Parent.Parent.Parent.hooks.usePreviewState)
local HumanoidDescriptionSerializer = require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)

local LOCAL_PLAYER = Players.LocalPlayer
local INITIAL_RIG_YAW = math.rad(180)
local DRAG_ROTATION_SPEED = 0.011

local IDLE_ANIMATION_BY_RIG_TYPE = {
	[Enum.HumanoidRigType.R6] = "rbxassetid://180435571",
	[Enum.HumanoidRigType.R15] = "rbxassetid://507766666",
}

local function playEmoteAnimation(model: Model, emoteId: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == "CatalogPreviewIdle" or track.Name == "CatalogPreviewEmote" then
			track:Stop(0.1)
		end
	end

	local animation = Instance.new("Animation")
	animation.Name = "CatalogPreviewEmote"
	animation.AnimationId = "rbxassetid://" .. tostring(emoteId)

	local ok, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if ok then
		local track = trackOrError
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.1, 1, 1)
	else
		warn("[CatalogPreview] Failed to play emote animation:", trackOrError)
	end

	animation:Destroy()
end

local function playIdleAnimation(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == "CatalogPreviewIdle" or track.Name == "CatalogPreviewEmote" then
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

local function prepareRig(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Enabled = false
			descendant:Destroy()
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
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

local function setupViewport(
	viewport: ViewportFrame,
	liveSnapshot: any,
	activeEmote: any
)
	viewport:ClearAllChildren()

	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.FieldOfView = 31
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "PreviewWorld"
	worldModel.Parent = viewport
	
	-- Wait for live character to exist
	local character = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
	if not character:FindFirstChildOfClass("Humanoid") then
		character:WaitForChild("Humanoid", 5)
	end

	local previousArchivable = character.Archivable
	character.Archivable = true
	local rig = character:Clone()
	character.Archivable = previousArchivable
	
	if not rig then return nil end

	rig.Name = "CatalogPreviewRig"
	rig.Parent = worldModel
	prepareRig(rig)
	pivotRig(rig)
	frameCamera(camera, rig)
	
	if liveSnapshot then
		task.spawn(function()
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local desc = HumanoidDescriptionSerializer.deserialize(liveSnapshot)
				local originalParent = rig.Parent
				rig.Parent = game.Workspace
				rig:PivotTo(CFrame.new(0, -1000, 0))
				
				pcall(function()
					humanoid:ApplyDescription(desc)
				end)
				
				rig.Parent = originalParent
				rig:PivotTo(CFrame.new())
				pivotRig(rig)
				frameCamera(camera, rig)
				
				if activeEmote and activeEmote.emoteAnimationId then
					playEmoteAnimation(rig, activeEmote.emoteAnimationId)
				else
					playIdleAnimation(rig)
				end
			end
		end)
	else
		playIdleAnimation(rig)
	end

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
	
	local state = useAppearanceState()
	local _, activeEmote = usePreviewState()
	
	local liveRevision = state.liveRevision
	local activeEmoteKey = activeEmote and activeEmote.key or ""

	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then return nil end

		yawRef.current = INITIAL_RIG_YAW
		rigRef.current = setupViewport(viewport, state.liveSnapshot, activeEmote)

		return function()
			rigRef.current = nil
			if viewport then
				viewport:ClearAllChildren()
			end
		end
	end, { liveRevision, activeEmoteKey })

	local beginDrag = React.useCallback(function(_, input)
		if not isPrimaryDragInput(input) then return end
		draggingRef.current = true
		lastDragXRef.current = input.Position.X
	end, {})

	local updateDrag = React.useCallback(function(_, input)
		if not draggingRef.current or not isDragMoveInput(input) then return end
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

			ResetArea = false and React.createElement("Frame", {
				-- Reset to original is not implemented yet in Phase 7 since we don't have OriginalSnapshot in client state.
			})
		}),
	})
end

return AvatarPreviewViewport
