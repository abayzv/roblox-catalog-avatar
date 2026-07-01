local HumanoidDescriptionSerializer = {}

local NUMBER_PROPERTIES = {
	-- Body parts
	"Head",
	"Torso",
	"LeftArm",
	"RightArm",
	"LeftLeg",
	"RightLeg",

	-- Classic clothing / face
	"Face",
	"Shirt",
	"Pants",
	"GraphicTShirt",

	-- Body scale
	"BodyTypeScale",
	"DepthScale",
	"HeadScale",
	"HeightScale",
	"ProportionScale",
	"WidthScale",

	-- Animations
	"IdleAnimation",
	"WalkAnimation",
	"RunAnimation",
	"JumpAnimation",
	"FallAnimation",
	"ClimbAnimation",
	"SwimAnimation",
	"MoodAnimation",
}

local STRING_PROPERTIES = {
	-- Rigid accessories
	"HatAccessory",
	"HairAccessory",
	"FaceAccessory",
	"NeckAccessory",
	"ShouldersAccessory",
	"ShoulderAccessory",
	"FrontAccessory",
	"BackAccessory",
	"WaistAccessory",
}

local LAYERED_CLOTHING_PROPERTIES = {
	-- Layered clothing
	"TShirtAccessory",
	"ShirtAccessory",
	"PantsAccessory",
	"JacketAccessory",
	"SweaterAccessory",
	"ShortsAccessory",
	"DressSkirtAccessory",
	"LeftShoeAccessory",
	"RightShoeAccessory",
}

local COLOR_PROPERTIES = {
	"HeadColor",
	"TorsoColor",
	"LeftArmColor",
	"RightArmColor",
	"LeftLegColor",
	"RightLegColor",
}

local function safeRead(description: HumanoidDescription, propertyName: string)
	local ok, value = pcall(function()
		return (description :: any)[propertyName]
	end)

	if ok then
		return value
	end

	return nil
end

local function serializeVector3(vec: Vector3?): { number }?
	if not vec then
		return nil
	end
	return { vec.X, vec.Y, vec.Z }
end

local function deserializeVector3(arr: { number }?): Vector3?
	if not arr or type(arr) ~= "table" or #arr < 3 then
		return nil
	end
	return Vector3.new(arr[1], arr[2], arr[3])
end

function HumanoidDescriptionSerializer.serialize(description: HumanoidDescription): table
	local snapshot = {}

	for _, propertyName in ipairs(NUMBER_PROPERTIES) do
		local value = safeRead(description, propertyName)
		if value ~= nil then
			snapshot[propertyName] = value
		end
	end

	for _, propertyName in ipairs(STRING_PROPERTIES) do
		local value = safeRead(description, propertyName)
		if value ~= nil then
			snapshot[propertyName] = value
		end
	end

	local accessories = description:GetAccessories(true)
	local serializedAccessories = {}
	for _, acc in ipairs(accessories) do
		table.insert(serializedAccessories, {
			AssetId = acc.AssetId,
			AccessoryType = acc.AccessoryType.Name,
			IsLayered = acc.IsLayered,
			Order = acc.Order,
			Puffiness = acc.Puffiness,
			Position = serializeVector3(acc.Position),
			Rotation = serializeVector3(acc.Rotation),
			Scale = serializeVector3(acc.Scale),
		})
	end
	snapshot.SerializedAccessories = serializedAccessories

	-- Legacy layered clothing serialization for backward compatibility if ever needed
	for _, prop in ipairs(LAYERED_CLOTHING_PROPERTIES) do
		local accessoryName = prop:gsub("Accessory", "")
		if accessoryName == "Shoulders" then
			accessoryName = "Shoulder"
		end
		local enumSuccess, enumItem = pcall(function()
			return Enum.AccessoryType[accessoryName]
		end)
		if enumSuccess and enumItem then
			local ids = {}
			for _, acc in ipairs(accessories) do
				if acc.AccessoryType == enumItem and acc.IsLayered then
					table.insert(ids, acc.AssetId)
				end
			end
			if #ids > 0 then
				snapshot[prop] = table.concat(ids, ",")
			end
		end
	end

	for _, propertyName in ipairs(COLOR_PROPERTIES) do
		local value = safeRead(description, propertyName)
		if value ~= nil and typeof(value) == "Color3" then
			-- Serialize Color3 as a hex string for DataStore support
			snapshot[propertyName] = value:ToHex()
		end
	end

	return snapshot
end

function HumanoidDescriptionSerializer.deserialize(snapshot: table): HumanoidDescription
	local description = Instance.new("HumanoidDescription")

	for _, propertyName in ipairs(NUMBER_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			pcall(function()
				(description :: any)[propertyName] = value
			end)
		end
	end

	for _, propertyName in ipairs(STRING_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			pcall(function()
				(description :: any)[propertyName] = value
			end)
		end
	end

	local accessories = description:GetAccessories(true)

	if snapshot.SerializedAccessories then
		for _, acc in ipairs(snapshot.SerializedAccessories) do
			local enumSuccess, enumItem = pcall(function()
				return Enum.AccessoryType[acc.AccessoryType]
			end)
			if enumSuccess and enumItem then
				table.insert(accessories, {
					AccessoryType = enumItem,
					AssetId = acc.AssetId,
					IsLayered = acc.IsLayered,
					Order = acc.Order,
					Puffiness = acc.Puffiness,
					Position = deserializeVector3(acc.Position),
					Rotation = deserializeVector3(acc.Rotation),
					Scale = deserializeVector3(acc.Scale),
				})
			end
		end
	else
		-- Legacy fallback for layered clothing
		for _, prop in ipairs(LAYERED_CLOTHING_PROPERTIES) do
			local value = snapshot[prop]
			if value and type(value) == "string" and value ~= "" then
				local accessoryName = prop:gsub("Accessory", "")
				if accessoryName == "Shoulders" then
					accessoryName = "Shoulder"
				end
				local enumSuccess, enumItem = pcall(function()
					return Enum.AccessoryType[accessoryName]
				end)
				if enumSuccess and enumItem then
					for idStr in string.gmatch(value, "[^%,]+") do
						local id = tonumber(idStr)
						if id then
							table.insert(accessories, {
								AccessoryType = enumItem,
								AssetId = id,
								IsLayered = true,
								Order = #accessories + 1,
							})
						end
					end
				end
			end
		end
	end

	pcall(function()
		description:SetAccessories(accessories, true)
	end)

	for _, propertyName in ipairs(COLOR_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			-- Backwards compatibility: might be Color3 object (from old mock state) or hex string (from DataStore)
			if typeof(value) == "Color3" then
				pcall(function()
					(description :: any)[propertyName] = value
				end)
			elseif type(value) == "string" then
				pcall(function()
					(description :: any)[propertyName] = Color3.fromHex(value)
				end)
			end
		end
	end

	return description
end

function HumanoidDescriptionSerializer.validateSnapshot(snapshot: table): (boolean, string?)
	if type(snapshot) ~= "table" then
		return false, "snapshot must be a table"
	end

	for _, propertyName in ipairs(NUMBER_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			if type(value) ~= "number" then
				return false, "Property " .. propertyName .. " must be a number"
			end
			if value < 0 then
				return false, "Property " .. propertyName .. " must be >= 0"
			end
			-- Scale properties could be validated more strictly, but this is sufficient for light validation
		end
	end

	for _, propertyName in ipairs(STRING_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			if type(value) ~= "string" then
				return false, "Property " .. propertyName .. " must be a CSV string"
			end
			local count = 0
			for _ in string.gmatch(value, "[^%,]+") do
				count += 1
			end
			if count > 10 then
				return false, "Property " .. propertyName .. " has too many asset IDs"
			end
		end
	end

	for _, propertyName in ipairs(LAYERED_CLOTHING_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			if type(value) ~= "string" then
				return false, "Property " .. propertyName .. " must be a CSV string"
			end
			local count = 0
			for _ in string.gmatch(value, "[^%,]+") do
				count += 1
			end
			if count > 10 then
				return false, "Property " .. propertyName .. " has too many asset IDs"
			end
		end
	end

	for _, propertyName in ipairs(COLOR_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			if typeof(value) ~= "Color3" and type(value) ~= "string" then
				return false, "Property " .. propertyName .. " must be a Color3 or Hex String"
			end
		end
	end

	return true, nil
end

function HumanoidDescriptionSerializer.debugPrint(snapshot: table)
	local result = {}
	for k, v in pairs(snapshot) do
		if type(v) == "string" and v == "" then
			continue
		end
		if type(v) == "number" and v == 0 then
			continue
		end
		table.insert(result, tostring(k) .. "=" .. tostring(v))
	end
	table.sort(result)
	return table.concat(result, "\n")
end

return HumanoidDescriptionSerializer
