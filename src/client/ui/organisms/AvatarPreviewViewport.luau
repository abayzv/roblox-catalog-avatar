local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local GlassButton = require(script.Parent.Parent.atoms.GlassButton)
local usePreviewState = require(script.Parent.Parent.Parent.hooks.usePreviewState)
local PreviewState = require(script.Parent.Parent.Parent.logic.PreviewState)
local ApplyAvatarRemote = require(ReplicatedStorage.Shared.remotes.ApplyAvatarRemote)
local AvatarDescriptionDraft = require(script.Parent.Parent.Parent.logic.AvatarDescriptionDraft)
local HumanoidDescriptionSerializer = require(ReplicatedStorage.Shared.avatar.HumanoidDescriptionSerializer)

local LOCAL_PLAYER = Players.LocalPlayer
local INITIAL_RIG_YAW = math.rad(180)
local DRAG_ROTATION_SPEED = 0.011
local ACCESSORY_TYPE_TO_PROPERTY = {
	[Enum.AccessoryType.Back] = "BackAccessory",
	[Enum.AccessoryType.Face] = "FaceAccessory",
	[Enum.AccessoryType.Front] = "FrontAccessory",
	[Enum.AccessoryType.Hair] = "HairAccessory",
	[Enum.AccessoryType.Hat] = "HatAccessory",
	[Enum.AccessoryType.Neck] = "NeckAccessory",
	[Enum.AccessoryType.Shoulder] = "ShouldersAccessory",
	[Enum.AccessoryType.Waist] = "WaistAccessory",
}

local PROPERTY_TO_ACCESSORY_TYPE = {}
for accType, prop in pairs(ACCESSORY_TYPE_TO_PROPERTY) do
	PROPERTY_TO_ACCESSORY_TYPE[prop] = accType
end

local PROPERTY_TO_ATTACHMENT_NAME = {
	BackAccessory = "BodyBackAttachment",
	FaceAccessory = "FaceFrontAttachment",
	FrontAccessory = "BodyFrontAttachment",
	HairAccessory = "HairAttachment",
	HatAccessory = "HatAttachment",
	NeckAccessory = "NeckAttachment",
	WaistAccessory = "WaistCenterAttachment",
}

local IDLE_ANIMATION_BY_RIG_TYPE = {
	[Enum.HumanoidRigType.R6] = "rbxassetid://180435571",
	[Enum.HumanoidRigType.R15] = "rbxassetid://507766666",
}

local function playEmoteAnimation(model: Model, emoteId: number)
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
	animation.Name = "CatalogPreviewEmote"
	animation.AnimationId = "rbxassetid://" .. tostring(emoteId)

	local ok, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if ok then
		local track = trackOrError
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.2, 1, 1)
	else
		warn("[CatalogPreview] Failed to play emote animation:", trackOrError)
	end

	animation:Destroy()
end

local function setDescriptionProperty(
	description: HumanoidDescription,
	propertyName: string,
	assetIds: { number }?
)
	assetIds = assetIds or {}

	local success, currentValue = pcall(function()
		return description[propertyName]
	end)
	
	if not success then
		local accessoryName = propertyName:gsub("Accessory", "")
		if accessoryName == "Shoulders" then accessoryName = "Shoulder" end
		
		local successEnum, enumItem = pcall(function()
			return Enum.AccessoryType[accessoryName]
		end)
		
		if successEnum and enumItem then
			local accs = description:GetAccessories(true)
			for i = #accs, 1, -1 do
				if accs[i].AccessoryType == enumItem then
					table.remove(accs, i)
				end
			end
			for i, assetId in ipairs(assetIds) do
				table.insert(accs, {
					AccessoryType = enumItem,
					AssetId = assetId,
					IsLayered = true,
					Order = i
				})
			end
			description:SetAccessories(accs, true)
		end
		return
	end

	if type(currentValue) == "string" then
		local values = {}
		for _, assetId in ipairs(assetIds) do
			table.insert(values, tostring(assetId))
		end
		description[propertyName] = table.concat(values, ",")
	elseif type(currentValue) == "number" then
		description[propertyName] = assetIds[#assetIds] or 0
	end
end

-- Removed removeTouchedPhysicalItems

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
	
	if AvatarDescriptionDraft.getDraftDescription() == nil then
		AvatarDescriptionDraft.initializeFromCharacter(character)
	end

	if clone then
		clone.Name = "CatalogPreviewRig"
		prepareRig(clone)
		pivotRig(clone)
	end

	return clone
end

local function applyPreviewDescription(rig: Model, previewPayloads, appliedEntries, camera: Camera, onComplete: () -> ())
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local liveCharacter = LOCAL_PLAYER.Character
	local liveHumanoid = liveCharacter and liveCharacter:FindFirstChildOfClass("Humanoid")
	if not liveHumanoid then return end

	local draftDescription = AvatarDescriptionDraft.getDraftDescription()
	if not draftDescription then
		-- Fallback if not initialized yet
		draftDescription = liveHumanoid:GetAppliedDescription() or Instance.new("HumanoidDescription")
	end
	local description = draftDescription:Clone()
	
	print("[Preview] applying draft description:\n" .. HumanoidDescriptionSerializer.debugPrint(HumanoidDescriptionSerializer.serialize(description)))

	task.spawn(function()
		local originalParent = rig.Parent
		local originalCFrame = rig:GetPivot()

		rig.Parent = game.Workspace
		rig:PivotTo(CFrame.new(0, -1000, 0))

		local previewedProperties = {}
		for _, payload in pairs(previewPayloads) do
			if payload.propertyName then
				previewedProperties[payload.propertyName] = true
			end
		end

		for _, descendant in ipairs(rig:GetChildren()) do
			if descendant:IsA("Accessory") then
				for prop in pairs(previewedProperties) do
					local match = false
					local accType = PROPERTY_TO_ACCESSORY_TYPE[prop]
					if accType and descendant.AccessoryType == accType then
						match = true
					end
					if not match and descendant.AccessoryType == Enum.AccessoryType.Unknown then
						local handle = descendant:FindFirstChild("Handle")
						if handle then
							local attName = PROPERTY_TO_ATTACHMENT_NAME[prop]
							if attName and handle:FindFirstChild(attName) then
								match = true
							end
						end
					end
					if match then
						descendant:Destroy()
						break
					end
				end
			elseif descendant:IsA("Shirt") and previewedProperties["Shirt"] then
				-- Destroying 2D clothing forces ApplyDescription to recreate them,
				-- which is required for ViewportFrame to render texture updates.
				descendant:Destroy()
			elseif descendant:IsA("Pants") and previewedProperties["Pants"] then
				descendant:Destroy()
			elseif descendant:IsA("ShirtGraphic") and previewedProperties["GraphicTShirt"] then
				descendant:Destroy()
			end
		end

		print("[CatalogPreview] Calling ApplyDescription...")
		local ok, err = pcall(function()
			humanoid:ApplyDescription(description)
		end)
		print("[CatalogPreview] ApplyDescription finished! ok:", ok)

		if not ok then
			warn("[CatalogPreview] Failed to apply viewport description:", err)
		end

		rig.Parent = originalParent
		rig:PivotTo(originalCFrame)

		if rig.Parent then
			prepareRig(rig)
			pivotRig(rig)
			frameCamera(camera, rig)
			
			if onComplete then
				onComplete()
			end
		end
	end)
end

local function setupViewport(
	viewport: ViewportFrame,
	previewPayloads,
	appliedEntries,
	shouldApplyPreview: boolean,
	activeEmote: PreviewTypes.PreviewPayload?
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

	local rig = cloneLocalCharacter()
	if not rig then
		return nil
	end

	rig.Parent = worldModel
	frameCamera(camera, rig)
	
	if shouldApplyPreview then
		applyPreviewDescription(rig, previewPayloads, appliedEntries, camera, function()
			if activeEmote and activeEmote.emoteAnimationId then
				playEmoteAnimation(rig, activeEmote.emoteAnimationId)
			else
				playIdleAnimation(rig)
			end
		end)
	else
		if activeEmote and activeEmote.emoteAnimationId then
			playEmoteAnimation(rig, activeEmote.emoteAnimationId)
		else
			playIdleAnimation(rig)
		end
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
	local previewPayloads, activeEmote = usePreviewState()
	local appliedEntries = PreviewState.getAppliedEntries()
	local isHydrated = PreviewState.hasHydrated()
	local isDirty = PreviewState.isDirty()
	local previewKeyParts = {}

	for key in pairs(previewPayloads) do
		table.insert(previewKeyParts, key)
	end
	table.sort(previewKeyParts)

	local previewKey = table.concat(previewKeyParts, "|")
	local activeEmoteKey = activeEmote and activeEmote.key or ""

	React.useEffect(function()
		if PreviewState.hasHydrated() then
			return nil
		end

		task.spawn(function()
			local callSuccess, response = pcall(function()
				return ApplyAvatarRemote:InvokeServer({
					action = "GetEquipped",
				})
			end)
			
			print("GetEquipped callSuccess:", callSuccess, "response:", response)

			if callSuccess and type(response) == "table" and response.success then
				if response.equippedItems then
					local mappedEquipped = {}
					for _, item in ipairs(response.equippedItems) do
						table.insert(mappedEquipped, {
							key = tostring(item.assetId),
							id = item.assetId,
							itemType = "Asset"
						})
					end
					print("Mapped Equipped length:", #mappedEquipped)
					PreviewState.hydrateAppliedEntries(mappedEquipped)
					print("Hydrated applied entries successfully")
					
					if response.originalItems then
						local mappedOriginal = {}
						for _, item in ipairs(response.originalItems) do
							table.insert(mappedOriginal, {
								key = tostring(item.assetId),
								id = item.assetId,
								itemType = "Asset"
							})
						end
						PreviewState.hydrateOriginalEntries(mappedOriginal)
					end
				else
					-- Mock hydration if it's returning old format
					PreviewState.hydrateAppliedEntries({})
				end
			elseif callSuccess and type(response) == "table" then
				warn("[CatalogPreview] Failed to load equipped snapshot:", response.message)
			else
				warn("[CatalogPreview] Failed to request equipped snapshot:", response)
			end
		end)

		return nil
	end, {})

	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then
			return nil
		end

		yawRef.current = INITIAL_RIG_YAW
		rigRef.current = setupViewport(viewport, previewPayloads, appliedEntries, isHydrated, activeEmote)

		return function()
			rigRef.current = nil
			if viewport then
				viewport:ClearAllChildren()
			end
		end
	end, { previewKey, isHydrated, activeEmoteKey })

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

			ResetArea = next(previewPayloads) ~= nil and React.createElement("Frame", {
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
						PreviewState.resetPreviewToOriginal()
					end,
				}),
			}),

			ActionArea = isDirty and React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -Theme.Space.XL),
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

				ApplyButton = React.createElement(GlassButton, {
					text = "Apply",
					icon = Icons.Apply,
					color = Theme.Color.TextPrimary,
					size = UDim2.fromScale(1, 1),
					onActivated = function()
						if not PreviewState.hasHydrated() then
							warn("[CatalogPreview] Ignore apply until equipped snapshot is loaded.")
							return
						end

						local entries = PreviewState.getDesiredEntries()
						print(
							"[CatalogPreview] Sending apply request to server for desired items..."
						)

						task.spawn(function()
							local snapshot = AvatarDescriptionDraft.serializeDraft()
							if not snapshot then return end
							
							print("[Apply:Client] snapshot:\n" .. HumanoidDescriptionSerializer.debugPrint(snapshot))

							local callSuccess, response = pcall(function()
								return ApplyAvatarRemote:InvokeServer({
									action = "ApplyDescription",
									revision = 1,
									description = snapshot,
								})
							end)

							if callSuccess and type(response) == "table" then
								if response.success then
									print("[CatalogPreview] Server accepted apply:", response.message)
									if response.description then
										local appliedDesc = HumanoidDescriptionSerializer.deserialize(response.description)
										AvatarDescriptionDraft.markApplied(appliedDesc)
										PreviewState.clearPreview() -- clear UI selection states after successful apply
									end
								else
									warn("[CatalogPreview] Server rejected apply:", response.message)
								end
							else
								warn("[CatalogPreview] Failed to communicate with server:", response)
							end
						end)
					end,
				}),
			}),
		}),
	})
end

return AvatarPreviewViewport
