local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

local HeaderTabs = require(script.Parent.HeaderTabs)
local SearchToolbar = require(script.Parent.Parent.molecules.SearchToolbar)
local MainCategoryTabs = require(script.Parent.MainCategoryTabs)
local SubCategoryChips = require(script.Parent.SubCategoryChips)
local CatalogGrid = require(script.Parent.CatalogGrid)
local useCatalogState = require(script.Parent.Parent.hooks.useCatalogState)

local AvatarPreviewController =
	require(script.Parent.Parent.Parent.controllers.AvatarPreviewController)

export type CatalogPanelProps = {
	layoutOrder: number?,
	isMobile: boolean?,
	isTablet: boolean?,
	viewportSize: Vector2?,
	contentScale: number?,
}

local HEADER_HEIGHT = 51
local SEARCH_HEIGHT = 60
local MAIN_CATEGORY_HEIGHT = 60
local SUBCATEGORY_HEIGHT = 50
local GRID_OFFSET = HEADER_HEIGHT
	+ 16
	+ SEARCH_HEIGHT
	+ 18
	+ MAIN_CATEGORY_HEIGHT
	+ 16
	+ SUBCATEGORY_HEIGHT
	+ 16

local function CatalogPanel(props: CatalogPanelProps)
	local state, actions = useCatalogState()
	local contentScale = props.contentScale or 1
	local contentSizeScale = if contentScale > 0 then 1 / contentScale else 1

	local MOCK_ITEMS = React.useMemo(function()
		local items = {}
		local queryLower = string.lower(state.searchQuery)

		for i = 1, 36 do
			local isFedoraTestItem = i == 1
			local assetId = if isFedoraTestItem then 128159229 else nil
			local name = if isFedoraTestItem
				then "Fedora Macan Tutul Salju"
				else state.activeMainCategory .. " " .. state.activeSubCategory .. " Item " .. i

			local matchSearch = true
			if queryLower ~= "" then
				matchSearch = string.find(string.lower(name), queryLower, 1, true) ~= nil
			end

			if matchSearch then
				table.insert(items, {
					id = state.activeMainCategory .. "_" .. state.activeSubCategory .. "_" .. i,
					assetId = assetId,
					name = name,
					price = math.random(50, 500),
					image = if assetId
						then "rbxthumb://type=Asset&id=128159229&w=420&h=420"
						else "rbxassetid://18517062196",
				})
			end
		end
		return items
	end, { state.activeMainCategory, state.activeSubCategory, state.searchQuery })

	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = Theme.Color.Panel,
			ClipsDescendants = true,
			LayoutOrder = props.layoutOrder,
			BorderSizePixel = 0,
		},
		React.createElement(React.Fragment, nil, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.Panel),
			}),
			Content = React.createElement("Frame", {
				BackgroundTransparency = 1,
				ClipsDescendants = false,
				Size = UDim2.fromScale(contentSizeScale, contentSizeScale),
			}, {
				UIScale = React.createElement("UIScale", {
					Scale = contentScale,
				}),

				UIPadding = React.createElement("UIPadding", {
					PaddingTop = UDim.new(0, Theme.Space.XL),
					PaddingBottom = UDim.new(0, Theme.Space.XL),
					PaddingLeft = UDim.new(0, Theme.Space.XL),
					PaddingRight = UDim.new(0, Theme.Space.XL),
				}),
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),

				HeaderArea = React.createElement(HeaderTabs, {
					activeTab = state.activeTab,
					onTabSelected = actions.setActiveTab,
					layoutOrder = 1,
				}),

				Spacer1 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				}),

				SearchArea = React.createElement(SearchToolbar, {
					searchText = state.searchQuery,
					onSearchTextChanged = actions.setSearchQuery,
					onFilterActivated = function()
						print("Filter activated")
					end,
					layoutOrder = 3,
				}),

				Spacer2 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					LayoutOrder = 4,
				}),

				MainCategoryArea = React.createElement(MainCategoryTabs, {
					activeCategory = state.activeMainCategory,
					onCategorySelected = actions.setActiveMainCategory,
					layoutOrder = 5,
				}),

				Spacer3 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = 6,
				}),

				SubCategoryArea = React.createElement(SubCategoryChips, {
					activeSubCategory = state.activeSubCategory,
					onSubCategorySelected = actions.setActiveSubCategory,
					layoutOrder = 7,
				}),

				Spacer4 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = 8,
				}),

				GridArea = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 1, -GRID_OFFSET),
					BackgroundTransparency = 1,
					LayoutOrder = 9,
				}, {
					Grid = React.createElement(CatalogGrid, {
						items = MOCK_ITEMS,
						isLoading = false,
						columns = 5,
						viewportScale = contentScale,
						onTryOn = function(item)
							actions.setSelectedItemId(item.id)
							AvatarPreviewController.ToggleItemPreview(item)
						end,
					}),
				}),
			}),
		})
	)
end

return CatalogPanel
