local AvatarEditorService = game:GetService("AvatarEditorService")

local CatalogService = {}

local CATEGORY_MAPPINGS = {
	["Body"] = {
		["Character Bundles"] = { bundleTypes = { Enum.BundleType.BodyParts } },
		["Heads"] = { assetTypes = { Enum.AvatarAssetType.Head, Enum.AvatarAssetType.DynamicHead } },
		["Hair"] = { assetTypes = { Enum.AvatarAssetType.HairAccessory } },
		["Faces"] = { assetTypes = { Enum.AvatarAssetType.Face } },
	},
	["Modern Clothing"] = {
		["Jackets"] = { assetTypes = { Enum.AvatarAssetType.JacketAccessory } },
		["Sweaters"] = { assetTypes = { Enum.AvatarAssetType.SweaterAccessory } },
		["Shirts"] = { assetTypes = { Enum.AvatarAssetType.ShirtAccessory, Enum.AvatarAssetType.TShirtAccessory } },
		["Pants"] = { assetTypes = { Enum.AvatarAssetType.PantsAccessory } },
		["Shorts"] = { assetTypes = { Enum.AvatarAssetType.ShortsAccessory } },
		["Shoe Bundles"] = { bundleTypes = { Enum.BundleType.Shoes } },
		["Dresses & Skirts"] = { assetTypes = { Enum.AvatarAssetType.DressSkirtAccessory } },
	},
	["Classic Clothing"] = {
		["Classic Shirts"] = { assetTypes = { Enum.AvatarAssetType.Shirt } },
		["Classic Pants"] = { assetTypes = { Enum.AvatarAssetType.Pants } },
		["Classic T-Shirts"] = { assetTypes = { Enum.AvatarAssetType.TShirt } },
	},
	["Accessories"] = {
		["Hats"] = { assetTypes = { Enum.AvatarAssetType.Hat } },
		["Face"] = { assetTypes = { Enum.AvatarAssetType.FaceAccessory } },
		["Neck"] = { assetTypes = { Enum.AvatarAssetType.NeckAccessory } },
		["Shoulders"] = { assetTypes = { Enum.AvatarAssetType.ShoulderAccessory } },
		["Front"] = { assetTypes = { Enum.AvatarAssetType.FrontAccessory } },
		["Back"] = { assetTypes = { Enum.AvatarAssetType.BackAccessory } },
		["Waist"] = { assetTypes = { Enum.AvatarAssetType.WaistAccessory } },
	},
	["Animation"] = {
		["Animation Bundles"] = { bundleTypes = { Enum.BundleType.Animations } },
		["Emotes"] = { assetTypes = { Enum.AvatarAssetType.EmoteAnimation } },
	},
}

function CatalogService.SearchAsync(query: string, mainCategory: string, subCategory: string)
	local mapping = CATEGORY_MAPPINGS[mainCategory] and CATEGORY_MAPPINGS[mainCategory][subCategory]
	
	local params = CatalogSearchParams.new()
	if query and query ~= "" then
		params.SearchKeyword = query
	end
	params.Limit = 30
	params.IncludeOffSale = true
	
	if subCategory == "All" then
		local allAssetTypes = {}
		local allBundleTypes = {}
		local categoryMap = CATEGORY_MAPPINGS[mainCategory]
		if categoryMap then
			for _, map in pairs(categoryMap) do
				if map.assetTypes then
					for _, at in ipairs(map.assetTypes) do
						table.insert(allAssetTypes, at)
					end
				end
				if map.bundleTypes then
					for _, bt in ipairs(map.bundleTypes) do
						table.insert(allBundleTypes, bt)
					end
				end
			end
		end
		if #allAssetTypes > 0 then
			params.AssetTypes = allAssetTypes
		end
		if #allBundleTypes > 0 then
			params.BundleTypes = allBundleTypes
		end
	else
		local mapping = CATEGORY_MAPPINGS[mainCategory] and CATEGORY_MAPPINGS[mainCategory][subCategory]
		if mapping then
			if mapping.assetTypes then
				params.AssetTypes = mapping.assetTypes
			elseif mapping.bundleTypes then
				params.BundleTypes = mapping.bundleTypes
			end
		end
	end
	
	local success, pages = pcall(function()
		return AvatarEditorService:SearchCatalog(params)
	end)
	
	if not success then
		warn("CatalogService.SearchAsync error:", pages)
		return nil, tostring(pages)
	end
	
	return pages
end

return CatalogService
