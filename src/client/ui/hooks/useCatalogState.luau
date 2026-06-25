local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

export type CatalogState = {
	activeTab: string,
	activeMainCategory: string,
	activeSubCategory: string,
	searchQuery: string,
	selectedItemId: string?,
}

export type CatalogStateActions = {
	setActiveTab: (tab: string) -> (),
	setActiveMainCategory: (category: string) -> (),
	setActiveSubCategory: (subcat: string) -> (),
	setSearchQuery: (query: string) -> (),
	setSelectedItemId: (id: string?) -> (),
}

local MAIN_TO_SUB = {
	All = {
		"Featured", "Recommended", "Premium"
	},
	Body = {
		"Body Bundles", "Hair", "Head", "Faces"
	},
	["Modern Clothing"] = {
		"T-Shirt", "Shirt", "Pants", "Jacket", "Sweater", "Shorts", "Dress / Skirt", "Shoes Bundle"
	},
	["Classic Clothing"] = {
		"Classic T-Shirt", "Classic Shirt", "Classic Pants"
	},
	Accessory = {
		"Hats", "Face Accessories", "Neck", "Shoulder", "Front", "Back", "Waist"
	},
	Animation = {
		"Emotes", "Animation Bundles"
	}
}

local function useCatalogState()
	local activeTab, setActiveTab = React.useState("Item Catalog")
	local activeMainCategory, setActiveMainCategoryInternal = React.useState("All")
	local activeSubCategory, setActiveSubCategory = React.useState("Featured")
	local searchQuery, setSearchQuery = React.useState("")
	local selectedItemId, setSelectedItemId = React.useState(nil :: string?)

	local function setActiveMainCategory(category: string)
		setActiveMainCategoryInternal(category)
		local defaultSub = MAIN_TO_SUB[category]
		if defaultSub and defaultSub[1] then
			setActiveSubCategory(defaultSub[1])
		end
	end

	local state: CatalogState = {
		activeTab = activeTab,
		activeMainCategory = activeMainCategory,
		activeSubCategory = activeSubCategory,
		searchQuery = searchQuery,
		selectedItemId = selectedItemId,
	}

	local actions: CatalogStateActions = {
		setActiveTab = setActiveTab,
		setActiveMainCategory = setActiveMainCategory,
		setActiveSubCategory = setActiveSubCategory,
		setSearchQuery = setSearchQuery,
		setSelectedItemId = setSelectedItemId,
	}

	return state, actions
end

return useCatalogState
