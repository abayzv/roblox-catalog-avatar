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

local function useCatalogState()
	local activeTab, setActiveTab = React.useState("Item Catalog")
	local activeMainCategory, setActiveMainCategory = React.useState("Clothing")
	local activeSubCategory, setActiveSubCategory = React.useState("Jackets")
	local searchQuery, setSearchQuery = React.useState("")
	local selectedItemId, setSelectedItemId = React.useState(nil :: string?)

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
