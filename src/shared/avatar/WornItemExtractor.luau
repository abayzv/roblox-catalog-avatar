local MyAvatarCategoryConfig = require(script.Parent.MyAvatarCategoryConfig)

export type WornItem = {
	key: string,
	id: number,
	itemType: string,
	property: string,

	mainCategory: string,
	subCategory: string,
	groupId: string,

	source: string,
}

local PROPERTY_CLASSIFICATION = {
	-- Body
	HairAccessory = { mainCategory = "body", subCategory = "hair", groupId = "body" },
	Head = { mainCategory = "body", subCategory = "head", groupId = "body" },
	Face = { mainCategory = "body", subCategory = "face", groupId = "body" },
	Torso = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },
	LeftArm = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },
	RightArm = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },
	LeftLeg = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },
	RightLeg = { mainCategory = "body", subCategory = "body_parts", groupId = "body" },

	-- 3D Clothing
	TShirtAccessory = { mainCategory = "3d_clothing", subCategory = "tshirt", groupId = "3d_clothing" },
	ShirtAccessory = { mainCategory = "3d_clothing", subCategory = "shirt", groupId = "3d_clothing" },
	PantsAccessory = { mainCategory = "3d_clothing", subCategory = "pants", groupId = "3d_clothing" },
	JacketAccessory = { mainCategory = "3d_clothing", subCategory = "jacket", groupId = "3d_clothing" },
	SweaterAccessory = { mainCategory = "3d_clothing", subCategory = "sweater", groupId = "3d_clothing" },
	ShortsAccessory = { mainCategory = "3d_clothing", subCategory = "shorts", groupId = "3d_clothing" },
	DressSkirtAccessory = { mainCategory = "3d_clothing", subCategory = "dress_skirt", groupId = "3d_clothing" },
	LeftShoeAccessory = { mainCategory = "3d_clothing", subCategory = "left_shoe", groupId = "3d_clothing" },
	RightShoeAccessory = { mainCategory = "3d_clothing", subCategory = "right_shoe", groupId = "3d_clothing" },

	-- Classic Clothing
	GraphicTShirt = { mainCategory = "classic_clothing", subCategory = "classic_tshirt", groupId = "classic_clothing" },
	Shirt = { mainCategory = "classic_clothing", subCategory = "classic_shirt", groupId = "classic_clothing" },
	Pants = { mainCategory = "classic_clothing", subCategory = "classic_pants", groupId = "classic_clothing" },

	-- Accessories
	HatAccessory = { mainCategory = "accessories", subCategory = "hats", groupId = "accessories" },
	FaceAccessory = { mainCategory = "accessories", subCategory = "face", groupId = "accessories" },
	NeckAccessory = { mainCategory = "accessories", subCategory = "neck", groupId = "accessories" },
	ShoulderAccessory = { mainCategory = "accessories", subCategory = "shoulder", groupId = "accessories" },
	ShouldersAccessory = { mainCategory = "accessories", subCategory = "shoulder", groupId = "accessories" },
	FrontAccessory = { mainCategory = "accessories", subCategory = "front", groupId = "accessories" },
	BackAccessory = { mainCategory = "accessories", subCategory = "back", groupId = "accessories" },
	WaistAccessory = { mainCategory = "accessories", subCategory = "waist", groupId = "accessories" },
}

local WornItemExtractor = {}

local function extractCsvIds(value: string): { number }
	local ids = {}

	if typeof(value) ~= "string" or value == "" then
		return ids
	end

	for token in string.gmatch(value, "[^,]+") do
		local id = tonumber(token)
		if id and id > 0 then
			table.insert(ids, id)
		end
	end

	return ids
end

function WornItemExtractor.extract(snapshot: any): { WornItem }
	local wornItems: { WornItem } = {}
	
	if not snapshot or type(snapshot) ~= "table" then
		return wornItems
	end

	for propertyName, classification in pairs(PROPERTY_CLASSIFICATION) do
		local value = snapshot[propertyName]
		
		if value then
			local isCsvProperty = string.match(propertyName, "Accessory") ~= nil
			-- Special case for classic accessories vs layered clothing vs single id properties
			-- However, in HumanoidDescription, accessories are always comma separated strings
			if type(value) == "string" and (string.find(value, ",") or isCsvProperty) then
				local ids = extractCsvIds(value)
				for _, id in ipairs(ids) do
					table.insert(wornItems, {
						key = `Asset:{id}`,
						id = id,
						itemType = "Asset",
						property = propertyName,
						mainCategory = classification.mainCategory,
						subCategory = classification.subCategory,
						groupId = classification.groupId,
						source = "HumanoidDescription",
					})
				end
			else
				-- It's a single number/string id like Shirt, Pants, Head, WalkAnimation
				local id = tonumber(value)
				if id and id > 0 then
					table.insert(wornItems, {
						key = `Asset:{id}`,
						id = id,
						itemType = "Asset",
						property = propertyName,
						mainCategory = classification.mainCategory,
						subCategory = classification.subCategory,
						groupId = classification.groupId,
						source = "HumanoidDescription",
					})
				end
			end
		end
	end

	return wornItems
end

function WornItemExtractor.filterItems(wornItems: { WornItem }, mainCategoryId: string, subCategoryId: string): { WornItem }
	local filteredItems = {}
	
	for _, item in ipairs(wornItems) do
		local matches = false
		
		if mainCategoryId == "all" then
			if subCategoryId == "all" then
				matches = true
			else
				-- When main is all, subCategoryId represents a group
				matches = (item.groupId == subCategoryId)
			end
		else
			if item.mainCategory == mainCategoryId then
				if subCategoryId == "all" then
					matches = true
				else
					matches = (item.subCategory == subCategoryId)
				end
			end
		end
		
		if matches then
			table.insert(filteredItems, item)
		end
	end
	
	return filteredItems
end

return WornItemExtractor
