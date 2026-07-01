local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local AvatarAppearanceClient = require(script.Parent.Parent.Parent.services.AvatarAppearanceClient)
local AvatarTemplateCache = require(script.Parent.Parent.Parent.services.AvatarTemplateCache)
local GlassButton = require(script.Parent.Parent.atoms.GlassButton)
local useAppearanceState = require(script.Parent.Parent.Parent.hooks.useAppearanceState)
local useCheckoutItems = require(script.Parent.Parent.Parent.hooks.useCheckoutItems)
local CheckoutSummaryCard = require(script.Parent.Parent.molecules.CheckoutSummaryCard)
local HumanoidDescriptionSerializer =
	require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)
local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)
local SaveAvatarTemplateRemote = require(ReplicatedStorage.Shared.remotes.SaveAvatarTemplateRemote)

local LOCAL_PLAYER = Players.LocalPlayer
local INITIAL_RIG_YAW = math.rad(180)
local DRAG_ROTATION_SPEED = 0.011

local IDLE_ANIMATION_BY_RIG_TYPE = {
	[Enum.HumanoidRigType.R6] = "rbxassetid://180435571",
	[Enum.HumanoidRigType.R15] = "rbxassetid://507766666",
}

local function playIdleAnimation(model: Model, desc: HumanoidDescription?)
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
		if track.Name == "CatalogPreviewIdle" or track.Name == "CatalogPreviewEmote" then
			track:Stop(0.1)
		end
	end

	local animation = Instance.new("Animation")
	animation.Name = "CatalogPreviewIdle"

	local animationId = IDLE_ANIMATION_BY_RIG_TYPE[humanoid.RigType]
		or IDLE_ANIMATION_BY_RIG_TYPE[Enum.HumanoidRigType.R15]

	if desc and desc.IdleAnimation and desc.IdleAnimation > 0 then
		local animate = model:FindFirstChild("Animate")
		if animate then
			local idle = animate:FindFirstChild("idle")
			if idle then
				local anim1 = idle:FindFirstChild("Animation1")
					or idle:FindFirstChildWhichIsA("Animation")
				if anim1 and anim1:IsA("Animation") and anim1.AnimationId ~= "" then
					animationId = anim1.AnimationId
				end
			end
		end
	end

	animation.AnimationId = animationId

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
			if descendant.Name ~= "Animate" then
				descendant:Destroy()
			end
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function cloneCurrentCharacterRig(): Model?
	local character = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
	if not character:FindFirstChildOfClass("Humanoid") then
		character:WaitForChild("Humanoid", 5)
	end

	local previousArchivable = character.Archivable
	character.Archivable = true
	local rig = character:Clone()
	character.Archivable = previousArchivable

	return rig
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

local function renderRigToViewport(
	worldModel: WorldModel,
	camera: Camera,
	rig: Model,
	desc: HumanoidDescription?,
	yaw: number
)
	worldModel:ClearAllChildren()
	rig.Parent = worldModel
	rig:PivotTo(CFrame.new())
	pivotRig(rig, yaw)
	frameCamera(camera, rig)
	playIdleAnimation(rig, desc)
end

local function setupViewport(
	viewport: ViewportFrame,
	liveSnapshot: any,
	onRigReady: ((Model, number) -> ())?
)
	local token = (viewport:GetAttribute("PreviewToken") or 0) + 1
	viewport:SetAttribute("PreviewToken", token)

	local camera = viewport:FindFirstChild("PreviewCamera")
	if not camera then
		camera = Instance.new("Camera")
		camera.Name = "PreviewCamera"
		camera.FieldOfView = 31
		camera.Parent = viewport
	end
	viewport.CurrentCamera = camera

	local worldModel = viewport:FindFirstChild("PreviewWorld")
	if not worldModel then
		worldModel = Instance.new("WorldModel")
		worldModel.Name = "PreviewWorld"
		worldModel.Parent = viewport
	end

	local ViewportAnimationController =
		require(script.Parent.Parent.Parent.controllers.ViewportAnimationController)

	if liveSnapshot then
		task.spawn(function()
			local descOk, descOrError = pcall(function()
				return HumanoidDescriptionSerializer.deserialize(liveSnapshot)
			end)
			if not descOk then
				warn("[CatalogPreview] Failed to deserialize preview snapshot:", descOrError)
				return
			end

			local desc = descOrError
			local ok, rigOrError = pcall(function()
				return Players:CreateHumanoidModelFromDescriptionAsync(
					desc,
					Enum.HumanoidRigType.R15,
					Enum.AssetTypeVerification.Default
				)
			end)

			if viewport:GetAttribute("PreviewToken") ~= token then
				if ok and rigOrError and typeof(rigOrError) == "Instance" then
					rigOrError:Destroy()
				end
				return
			end

			if
				not ok
				or not rigOrError
				or typeof(rigOrError) ~= "Instance"
				or not rigOrError:IsA("Model")
			then
				warn("[CatalogPreview] Failed to create preview model:", rigOrError)
				return
			end

			local rig = rigOrError
			rig.Name = "CatalogPreviewRig"
			prepareRig(rig)

			ViewportAnimationController.stopViewportAnimation()
			renderRigToViewport(worldModel, camera, rig, desc, INITIAL_RIG_YAW)

			if onRigReady then
				onRigReady(rig, token)
			end
		end)
	else
		local rig = cloneCurrentCharacterRig()
		if rig then
			rig.Name = "CatalogPreviewRig"
			prepareRig(rig)
			renderRigToViewport(worldModel, camera, rig, nil, INITIAL_RIG_YAW)
			if onRigReady then
				onRigReady(rig, token)
			end
		else
			warn("[CatalogPreview] Failed to clone current character for blank preview.")
		end
	end

	return token
end

local function isPrimaryDragInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isDragMoveInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

export type AvatarPreviewViewportProps = {
	showSaveTemplate: boolean?,
	onTemplateSaved: (() -> ())?,
}

local function AvatarPreviewViewport(props: AvatarPreviewViewportProps)
	local viewportRef = React.useRef(nil)
	local rigRef = React.useRef(nil)
	local draggingRef = React.useRef(false)
	local lastDragXRef = React.useRef(0)
	local yawRef = React.useRef(INITIAL_RIG_YAW)

	local isSaving, setIsSaving = React.useState(false)
	local saveSuccessText, setSaveSuccessText = React.useState(nil :: string?)
	local stageWidth, setStageWidth = React.useState(0)

	local state = useAppearanceState()

	local activeSnapshot = if state.optimisticState and state.optimisticState.isOptimistic
		then state.optimisticState.predictedSnapshot
		else state.liveSnapshot
	local activeRevision = state.previewRevision

	local checkoutData = useCheckoutItems()
	local totalRobux = checkoutData.totalRobux
	
	local scale = 1
	local summaryAreaSize = UDim2.new(1, -(Theme.Space.XL * 2), 0, 160)
	
	if stageWidth > 0 then
		local padding = Theme.Space.XL * 2
		local targetWidth = stageWidth - padding
		local baseWidth = 352
		
		if targetWidth < baseWidth then
			scale = targetWidth / baseWidth
			summaryAreaSize = UDim2.new(0, baseWidth, 0, 160)
		end
	end

	local ViewportAnimationController =
		require(script.Parent.Parent.Parent.controllers.ViewportAnimationController)

	React.useEffect(function()
		return function()
			ViewportAnimationController.stopAll()
		end
	end, {})

	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then
			return nil
		end

		yawRef.current = INITIAL_RIG_YAW
		rigRef.current = nil
		local token = setupViewport(viewport, activeSnapshot, function(rig, renderToken)
			if viewport:GetAttribute("PreviewToken") == renderToken then
				rigRef.current = rig
			end
		end)

		return function()
			if viewport:GetAttribute("PreviewToken") == token then
				viewport:SetAttribute("PreviewToken", token + 1)
			end
			rigRef.current = nil
		end
	end, { activeRevision })

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
			[React.Change.AbsoluteSize] = function(rbx)
				setStageWidth(rbx.AbsoluteSize.X)
			end,
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

			ResetArea = React.createElement("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -Theme.Space.MD, 0, Theme.Space.MD),
				Size = UDim2.fromOffset(48, 48),
				BackgroundTransparency = 1,
				ZIndex = 13,
			}, {
				ResetButton = React.createElement(GlassButton, {
					icon = Icons.Reset,
					color = Theme.Color.TextSecondary,
					size = UDim2.fromScale(1, 1),
					onActivated = function()
						task.spawn(function()
							local ok, response = pcall(function()
								return ApplyAvatarRemote:InvokeServer({
									action = "ResetToOriginal",
								})
							end)

							if ok and response and response.success then
								AvatarAppearanceClient.updateState(
									response.liveSnapshot,
									response.liveRevision,
									response.source
								)
							else
								warn(
									"[CatalogPreview] Failed to reset to original:",
									response and response.message or response
								)
							end
						end)
					end,
				}),
			}),

			ActionArea = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -(Theme.Space.XL + (totalRobux > 0 and (160 * scale + Theme.Space.MD) or 0))),
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -(Theme.Space.XL * 2), 0, 48),
				ZIndex = 13,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, Theme.Space.MD),
				}),

				SaveTemplateButton = props.showSaveTemplate
					and React.createElement(GlassButton, {
						text = if isSaving
							then "Saving..."
							else (saveSuccessText or "Save Template"),
						icon = if saveSuccessText then Icons.Apply else Icons.Save,
						color = if saveSuccessText
							then Theme.Color.Success
							else Theme.Color.TextPrimary,
						size = UDim2.fromScale(1, 1),
						onActivated = function()
							if isSaving or saveSuccessText then
								return
							end

							setIsSaving(true)
							task.spawn(function()
								if SaveAvatarTemplateRemote then
									local res = SaveAvatarTemplateRemote:InvokeServer()
									if res.success then
										setSaveSuccessText("Saved!")

										if res.template then
											AvatarTemplateCache.add("mine", res.template)
											AvatarTemplateCache.add("all", res.template)
										end

										if props.onTemplateSaved then
											props.onTemplateSaved()
										end
										-- Reset success text after 2 seconds
										task.delay(2, function()
											setSaveSuccessText(nil)
										end)
									else
										warn("Failed to save template:", res.error)
										setSaveSuccessText("Failed")
										task.delay(2, function()
											setSaveSuccessText(nil)
										end)
									end
								end
								setIsSaving(false)
							end)
						end,
					}),
			}),

			CheckoutSummaryArea = totalRobux > 0 and React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -Theme.Space.XL),
				BackgroundTransparency = 1,
				Size = summaryAreaSize,
				ZIndex = 14,
			}, {
				UIScale = React.createElement("UIScale", {
					Scale = scale,
				}),
				SummaryCard = React.createElement(CheckoutSummaryCard, {
					totalPrice = totalRobux,
					onBuy = function()
						print("Buy clicked")
					end,
				}),
			}),
		}),
	})
end

return AvatarPreviewViewport
