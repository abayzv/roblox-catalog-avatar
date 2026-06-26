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

	for _, propertyName in ipairs(COLOR_PROPERTIES) do
		local value = safeRead(description, propertyName)
		if value ~= nil and typeof(value) == "Color3" then
			-- Serialize Color3 as a hex string or just pass it since Remotes support Color3
			-- For safety and predictability, let's keep it as Color3 for Remote transmission
			snapshot[propertyName] = value
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

	for _, propertyName in ipairs(COLOR_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil and typeof(value) == "Color3" then
			pcall(function()
				(description :: any)[propertyName] = value
			end)
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
				return false, "Property " .. propertyName .. " must be a string"
			end
			if string.len(value) > 300 then
				return false, "Property " .. propertyName .. " exceeds max length"
			end
			
			-- Count commas to ensure max 10 ids
			local count = 1
			for _ in string.gmatch(value, ",") do
				count = count + 1
			end
			if count > 10 then
				return false, "Property " .. propertyName .. " has too many asset IDs"
			end
		end
	end

	for _, propertyName in ipairs(COLOR_PROPERTIES) do
		local value = snapshot[propertyName]
		if value ~= nil then
			if typeof(value) ~= "Color3" then
				return false, "Property " .. propertyName .. " must be a Color3"
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
