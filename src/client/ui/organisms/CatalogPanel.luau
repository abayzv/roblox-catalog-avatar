local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

local HeaderTabs = require(script.Parent.HeaderTabs)
local SearchToolbar = require(script.Parent.Parent.molecules.SearchToolbar)
local MainCategoryTabs = require(script.Parent.MainCategoryTabs)
local SubCategoryChips = require(script.Parent.SubCategoryChips)
local CatalogGrid = require(script.Parent.CatalogGrid)
local useCatalogState = require(script.Parent.Parent.hooks.useCatalogState)

export type CatalogPanelProps = {
	layoutOrder: number?,
	isMobile: boolean?,
}

local function CatalogPanel(props: CatalogPanelProps)
	local state, actions = useCatalogState()

	local MOCK_ITEMS = React.useMemo(function()
		local items = {}
		local queryLower = string.lower(state.searchQuery)

		for i = 1, 12 do
			local name = state.activeMainCategory .. " " .. state.activeSubCategory .. " Item " .. i

			local matchSearch = true
			if queryLower ~= "" then
				matchSearch = string.find(string.lower(name), queryLower, 1, true) ~= nil
			end

			if matchSearch then
				table.insert(items, {
					id = state.activeMainCategory .. "_" .. state.activeSubCategory .. "_" .. i,
					name = name,
					price = math.random(50, 500),
					image = "rbxassetid://18517062196",
				})
			end
		end
		return items
	end, { state.activeMainCategory, state.activeSubCategory, state.searchQuery })

	return React.createElement(
		"Frame",
		{
			Size = props.isMobile and UDim2.fromScale(1, 1) or UDim2.new(1, -144, 1, -16),
			Position = props.isMobile and UDim2.fromScale(0, 0) or UDim2.new(0, 72, 0.5, 0),
			AnchorPoint = props.isMobile and Vector2.new(0, 0) or Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.Color.Panel,
			ClipsDescendants = true,
			LayoutOrder = props.layoutOrder,
			BorderSizePixel = 0,
		},
		React.createElement(React.Fragment, nil, {
			SizeConstraint = not props.isMobile and React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(858, math.huge),
				MinSize = Vector2.new(300, 0),
			}),
			UICorner = not props.isMobile and React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.Panel),
			}),
			UIStroke = not props.isMobile and React.createElement("UIStroke", {
				Color = Theme.Color.Border,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, props.isMobile and Theme.Space.LG or Theme.Space.XL),
				PaddingBottom = UDim.new(0, props.isMobile and Theme.Space.LG or Theme.Space.XL),
				PaddingLeft = UDim.new(0, props.isMobile and Theme.Space.LG or Theme.Space.XL),
				PaddingRight = UDim.new(0, props.isMobile and Theme.Space.LG or Theme.Space.XL),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			-- 1. HeaderTabs
			HeaderArea = React.createElement(HeaderTabs, {
				activeTab = state.activeTab,
				onTabSelected = actions.setActiveTab,
				layoutOrder = 1,
			}),

			Spacer1 = React.createElement(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 2 }
			),

			-- 2. SearchToolbar
			SearchArea = React.createElement(SearchToolbar, {
				searchText = state.searchQuery,
				onSearchTextChanged = actions.setSearchQuery,
				onFilterActivated = function()
					print("Filter activated")
				end,
				layoutOrder = 3,
			}),

			Spacer2 = React.createElement(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 4 }
			),

			-- 3. MainCategoryTabs
			MainCategoryArea = React.createElement(MainCategoryTabs, {
				activeCategory = state.activeMainCategory,
				onCategorySelected = actions.setActiveMainCategory,
				layoutOrder = 5,
			}),

			Spacer3 = React.createElement(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 6 }
			),

			-- 4. SubCategoryChips
			SubCategoryArea = React.createElement(SubCategoryChips, {
				activeSubCategory = state.activeSubCategory,
				onSubCategorySelected = actions.setActiveSubCategory,
				layoutOrder = 7,
			}),

			Spacer4 = React.createElement(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 8 }
			),

			-- 5. CatalogGrid
			GridArea = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 1, -(51 + 16 + 52 + 18 + 52 + 16 + 42 + 16)),
				BackgroundTransparency = 1,
				LayoutOrder = 9,
			}, {
				Grid = React.createElement(CatalogGrid, {
					items = MOCK_ITEMS,
					isLoading = false,
					onTryOn = function(item)
						actions.setSelectedItemId(item.id)
						print("Try On", item.name, item.id)
					end,
				}),
			}),
		})
	)
end

return CatalogPanel
