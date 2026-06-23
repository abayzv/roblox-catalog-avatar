local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

local HeaderTabs = require(script.Parent.HeaderTabs)
local SearchToolbar = require(script.Parent.Parent.molecules.SearchToolbar)
local MainCategoryTabs = require(script.Parent.MainCategoryTabs)
local SubCategoryChips = require(script.Parent.SubCategoryChips)
local CatalogGrid = require(script.Parent.CatalogGrid)

export type CatalogPanelProps = {
	layoutOrder: number?,
}

local function CatalogPanel(props: CatalogPanelProps)
	local activeTab, setActiveTab = React.useState("Item Catalog")
	local activeMainCategory, setActiveMainCategory = React.useState("Clothing")
	local activeSubCategory, setActiveSubCategory = React.useState("Jackets")
	local searchQuery, setSearchQuery = React.useState("")

	local MOCK_ITEMS = React.useMemo(function()
		local items = {}
		for i = 1, 12 do
			table.insert(items, {
				id = tostring(i),
				name = activeMainCategory .. " Item " .. i,
				price = math.random(50, 500),
				image = "rbxassetid://18517062196",
			})
		end
		return items
	end, { activeMainCategory, activeSubCategory })

	return React.createElement(
		"Frame",
		{
			Size = UDim2.new(0, 858, 1, -16),
			Position = UDim2.new(0, 72, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.Color.Panel,
			ClipsDescendants = true,
			LayoutOrder = props.layoutOrder,
		},
		React.createElement(React.Fragment, nil, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.Panel),
			}),
			UIStroke = React.createElement("UIStroke", {
				Color = Theme.Color.Border,
				Thickness = 1,
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

			-- 1. HeaderTabs
			HeaderArea = React.createElement(HeaderTabs, {
				activeTab = activeTab,
				onTabSelected = setActiveTab,
				layoutOrder = 1,
			}),

			Spacer1 = React.createElement(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 2 }
			),

			-- 2. SearchToolbar
			SearchArea = React.createElement(SearchToolbar, {
				query = searchQuery,
				onQueryChanged = setSearchQuery,
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
				activeCategory = activeMainCategory,
				onCategorySelected = setActiveMainCategory,
				layoutOrder = 5,
			}),

			Spacer3 = React.createElement(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 6 }
			),

			-- 4. SubCategoryChips
			SubCategoryArea = React.createElement(SubCategoryChips, {
				activeSubCategory = activeSubCategory,
				onSubCategorySelected = setActiveSubCategory,
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
						print("Try On", item.name)
					end,
				}),
			}),
		})
	)
end

return CatalogPanel
