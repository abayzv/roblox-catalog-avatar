local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

export type CatalogState = {
	activeMainCategory: string,
	activeSubCategory: string,
	searchInput: string,
	searchQuery: string,
	selectedItemId: string?,
}

export type CatalogStateActions = {
	setActiveMainCategory: (category: string) -> (),
	setActiveSubCategory: (subcat: string) -> (),
	setSearchInput: (input: string) -> (),
	setSearchQuery: (query: string) -> (),
	setSelectedItemId: (id: string?) -> (),
}

local MAIN_TO_SUB = {
	All = {
		"Featured",
		"Recommended",
		"Premium",
	},
	Body = {
		"Body Bundles",
		"Hair",
		"Head",
		"Faces",
	},
	["Modern Clothing"] = {
		"T-Shirt",
		"Shirt",
		"Pants",
		"Jacket",
		"Sweater",
		"Shorts",
		"Dress / Skirt",
		"Shoes Bundle",
	},
	["Classic Clothing"] = {
		"Classic T-Shirt",
		"Classic Shirt",
		"Classic Pants",
	},
	Accessory = {
		"Hats",
		"Face Accessories",
		"Neck",
		"Shoulder",
		"Front",
		"Back",
		"Waist",
	},
	Animation = {
		"Emotes",
		"Animation Bundles",
	},
}

local MyAvatarCategoryConfig = require(ReplicatedStorage.Shared.avatar.MyAvatarCategoryConfig)

local function useCatalogState(configType: string?)
	local activeMainCategory, setActiveMainCategoryInternal =
		React.useState(if configType == "my_avatar" then "all" else "All")
	local activeSubCategory, setActiveSubCategory =
		React.useState(if configType == "my_avatar" then "all" else "Featured")
	local searchInput, setSearchInput = React.useState("")
	local searchQuery, setSearchQuery = React.useState("")
	local selectedItemId, setSelectedItemId = React.useState(nil :: string?)

	local function setActiveMainCategory(category: string)
		setActiveMainCategoryInternal(category)

		-- Clear search when switching main category
		setSearchInput("")
		setSearchQuery("")

		if configType == "my_avatar" then
			local defaultSub = "all"
			for _, mainCat in ipairs(MyAvatarCategoryConfig.MainCategories) do
				if mainCat.id == category then
					if mainCat.subcategories and mainCat.subcategories[1] then
						defaultSub = mainCat.subcategories[1].id
					end
					break
				end
			end
			setActiveSubCategory(defaultSub)
		else
			local subcategories = MAIN_TO_SUB[category]
			if subcategories and #subcategories > 0 then
				setActiveSubCategory(subcategories[1])
			else
				setActiveSubCategory("")
			end
		end
	end

	local state: CatalogState = {
		activeMainCategory = activeMainCategory,
		activeSubCategory = activeSubCategory,
		searchInput = searchInput,
		searchQuery = searchQuery,
		selectedItemId = selectedItemId,
	}

	local actions: CatalogStateActions = {
		setActiveMainCategory = setActiveMainCategory,
		setActiveSubCategory = setActiveSubCategory,
		setSearchInput = setSearchInput,
		setSearchQuery = setSearchQuery,
		setSelectedItemId = setSelectedItemId,
	}

	return state, actions
end

return useCatalogState
