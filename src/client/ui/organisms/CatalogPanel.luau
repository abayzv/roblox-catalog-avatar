local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

local HeaderTabs = require(script.Parent.HeaderTabs)
local SearchToolbar = require(script.Parent.Parent.molecules.SearchToolbar)
local MainCategoryTabs = require(script.Parent.MainCategoryTabs)
local SubCategoryChips = require(script.Parent.SubCategoryChips)
local CatalogGrid = require(script.Parent.CatalogGrid)
local useCatalogState = require(script.Parent.Parent.hooks.useCatalogState)
local useCatalogItems = require(script.Parent.Parent.Parent.hooks.useCatalogItems)

local AvatarPreviewController =
	require(script.Parent.Parent.Parent.controllers.AvatarPreviewController)

export type CatalogPanelProps = {
	layoutOrder: number?,
	isMobile: boolean?,
	isTablet: boolean?,
	viewportSize: Vector2?,
	contentScale: number?,
	activeTab: string,
	setActiveTab: (tab: string) -> (),
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

	local catalogData = useCatalogItems(state.activeMainCategory, state.activeSubCategory, state.searchQuery)

	local lastSearchSubmitAt = React.useRef(0)
	
	local submitSearch = React.useCallback(function(query: string)
		local now = os.clock()
		-- Debounce for 0.7 seconds
		if now - lastSearchSubmitAt.current < 0.7 then
			return
		end
		lastSearchSubmitAt.current = now
		
		-- Normalize query
		query = tostring(query or "")
		query = string.gsub(query, "^%s+", "")
		query = string.gsub(query, "%s+$", "")
		query = string.gsub(query, "%s+", " ")
		
		if query ~= "" and #query < 2 then
			warn("[Search] Query minimal 2 karakter")
			return
		end
		
		actions.setSearchQuery(query)
	end, {actions.setSearchQuery})

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
					activeTab = props.activeTab,
					onTabSelected = props.setActiveTab,
					layoutOrder = 1,
				}),

				Spacer1 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				}),

				SearchArea = React.createElement(SearchToolbar, {
					searchText = state.searchInput,
					onSearchInputChanged = actions.setSearchInput,
					onSearchSubmitted = submitSearch,
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
					activeMainCategory = state.activeMainCategory,
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
						items = catalogData.items,
						readyKeys = catalogData.readyKeys,
						isLoading = catalogData.status == "Loading",
						isFetchingNextPage = catalogData.status == "FetchingNextPage",
						hasNextPage = catalogData.hasNextPage,
						isLimitReached = catalogData.isLimitReached,
						onLoadNextPage = catalogData.loadNextPage,
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
