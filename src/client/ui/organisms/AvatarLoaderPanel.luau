local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

local HeaderTabs = require(script.Parent.HeaderTabs)
local MainCategoryTabs = require(script.Parent.MainCategoryTabs)
local SearchToolbar = require(script.Parent.Parent.molecules.SearchToolbar)
local AvatarTemplateCard = require(script.Parent.Parent.molecules.AvatarTemplateCard)
local AvatarTemplateCardSkeleton =
	require(script.Parent.Parent.molecules.AvatarTemplateCardSkeleton)
local PaginationControls = require(script.Parent.Parent.molecules.PaginationControls)
local Text = require(script.Parent.Parent.atoms.Text)
local Spacer = require(script.Parent.Parent.atoms.Spacer)
local Icons = require(script.Parent.Parent.theme.Icons)
local AvatarTemplateTypes = require(ReplicatedStorage.Shared.types.AvatarTemplateTypes)
local AvatarAppearanceClient = require(script.Parent.Parent.Parent.services.AvatarAppearanceClient)
local TemplateThumbnailGenerator =
	require(script.Parent.Parent.Parent.services.TemplateThumbnailGenerator)
local AvatarTemplateCache = require(script.Parent.Parent.Parent.services.AvatarTemplateCache)
local ListAvatarTemplatesRemote =
	require(ReplicatedStorage.Shared.remotes.ListAvatarTemplatesRemote)
local LoadAvatarTemplateRemote = require(ReplicatedStorage.Shared.remotes.LoadAvatarTemplateRemote)
local SearchAvatarLoaderRemote = require(ReplicatedStorage.Shared.remotes.SearchAvatarLoaderRemote)
local LoadRobloxOutfitRemote = require(ReplicatedStorage.Shared.remotes.LoadRobloxOutfitRemote)

export type AvatarLoaderPanelProps = {
	layoutOrder: number?,
	isMobile: boolean?,
	isTablet: boolean?,
	viewportSize: Vector2?,
	contentScale: number?,
	activeTab: string,
	setActiveTab: (tab: string) -> (),
	templateCategory: string?,
	setTemplateCategory: ((category: string) -> ())?,
	refreshTrigger: number?,
}

local function AvatarLoaderPanel(props: AvatarLoaderPanelProps)
	local contentScale = props.contentScale or 1
	local contentSizeScale = if contentScale > 0 then 1 / contentScale else 1

	local searchInput, setSearchInput = React.useState("")
	local searchQuery, setSearchQuery = React.useState("")

	local templates, setTemplates = React.useState({})
	local isLoading, setIsLoading = React.useState(true)
	local searchState, setSearchState = React.useState("idle")
	local currentPage, setCurrentPage = React.useState(1)
	local hasNextPage, setHasNextPage = React.useState(false)
	local containerWidth, setContainerWidth = React.useState(804)

	local templateCategory = props.templateCategory or "all"
	local pageToken = "avatar_loader:"
		.. templateCategory
		.. ":"
		.. searchQuery
		.. ":page:"
		.. tostring(currentPage)

	React.useEffect(function()
		return function()
			TemplateThumbnailGenerator.cancelPage(pageToken)
		end
	end, { pageToken })

	local activeRequestToken = React.useRef(0)

	React.useEffect(function()
		local active = true

		task.spawn(function()
			if searchQuery == "" then
				-- Check cache
				if not AvatarTemplateCache.isStale(templateCategory, 300, currentPage) then
					local cached = AvatarTemplateCache.get(templateCategory, currentPage)
					if cached then
						setTemplates(cached)
						setHasNextPage(
							AvatarTemplateCache.getHasNextPage(templateCategory, currentPage)
						)
						setSearchState("idle")
						setIsLoading(false)
						return
					end
				end

				setIsLoading(true)
				setSearchState("searching")
				setTemplates({})
				setHasNextPage(false)

				activeRequestToken.current += 1
				local token = activeRequestToken.current

				local response = ListAvatarTemplatesRemote:InvokeServer({
					limit = 10,
					page = currentPage,
					mode = templateCategory,
				})

				if active and token == activeRequestToken.current then
					setIsLoading(false)
					if response and response.success and response.templates then
						AvatarTemplateCache.set(
							templateCategory,
							response.templates,
							currentPage,
							response.hasNextPage == true
						)
						setTemplates(response.templates)
						setHasNextPage(response.hasNextPage == true)
						setSearchState("idle")
					end
				end
			else
				setIsLoading(true)
				setSearchState("searching")
				setTemplates({})
				setHasNextPage(false)

				activeRequestToken.current += 1
				local token = activeRequestToken.current

				print(
					"[AvatarLoaderPanel] Invoking SearchAvatarLoaderRemote with query:",
					searchQuery
				)
				local response = SearchAvatarLoaderRemote:InvokeServer(searchQuery)
				print("[AvatarLoaderPanel] Search response:", response)

				if active and token == activeRequestToken.current then
					setIsLoading(false)
					if response and response.success then
						if response.resultType == "template_results" and response.templates then
							setTemplates(response.templates)
							setHasNextPage(false)
							setSearchState("results")
						elseif
							response.resultType == "loaded_template_code"
							or response.resultType == "loaded_username_avatar"
						then
							AvatarAppearanceClient.updateState(
								response.liveSnapshot,
								response.liveRevision,
								"avatar_loader_direct"
							)
							print("[AvatarLoader] Berhasil memuat avatar via code/username")
							setSearchInput("")
							setSearchQuery("")
						elseif response.resultType == "empty" then
							setTemplates({})
							setHasNextPage(false)
							setSearchState("empty")
						else
							setTemplates({})
							setHasNextPage(false)
							setSearchState("error")
						end
					else
						setTemplates({})
						setHasNextPage(false)
						setSearchState("error")
					end
				end
			end
		end)

		return function()
			active = false
		end
	end, { searchQuery, templateCategory, currentPage, props.refreshTrigger })

	local HEADER_HEIGHT = 51
	local SEARCH_HEIGHT = 60
	local CATEGORY_HEIGHT = 60
	local PAGINATION_SPACER_HEIGHT = Theme.Space.XS
	local PAGINATION_HEIGHT = 40
	local CONTENT_VERTICAL_PADDING = Theme.Space.XL * 2
	local LIST_OFFSET = HEADER_HEIGHT
		+ 16
		+ SEARCH_HEIGHT
		+ 18
		+ CATEGORY_HEIGHT
		+ 16
		+ PAGINATION_SPACER_HEIGHT
		+ CONTENT_VERTICAL_PADDING

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
					searchText = searchInput,
					onSearchInputChanged = setSearchInput,
					onSearchSubmitted = function(query)
						setCurrentPage(1)
						setSearchQuery(query)
					end,
					layoutOrder = 3,
				}),

				Spacer2 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					LayoutOrder = 4,
				}),

				CategoryArea = React.createElement(MainCategoryTabs, {
					activeCategory = templateCategory,
					onCategorySelected = function(category)
						setCurrentPage(1)
						if searchQuery ~= "" or searchInput ~= "" then
							setSearchInput("")
							setSearchQuery("")
						end
						props.setTemplateCategory(category)
					end,
					layoutOrder = 5,
					categories = {
						{ id = "all", label = "All Template", icon = Icons.Catalog },
						{ id = "mine", label = "My Template", icon = Icons.Avatar },
					},
				}),

				Spacer3 = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = 6,
				}),

				GridArea = (function()
					if isLoading and #templates == 0 then
						local columns = 5
						local sidePadding = 16
						local usableWidth = math.max(containerWidth - sidePadding, 1)
						local gapX = 18
						local gapY = 14
						local originalWidth = 248
						local originalHeight = 342
						local skeletonCount = 10

						local targetCellWidth =
							math.max((usableWidth - (gapX * (columns - 1))) / columns, 1)
						local scale = targetCellWidth / originalWidth
						local targetCellHeight = math.floor(originalHeight * scale)
						local rowCount = math.max(math.ceil(skeletonCount / columns), 1)
						local gridPaddingTop = 12
						local gridPaddingBottom = 28
						local estimatedContentHeight = gridPaddingTop
							+ (rowCount * targetCellHeight)
							+ (math.max(rowCount - 1, 0) * gapY)
							+ gridPaddingBottom

						local skeletons = {
							Layout = React.createElement("UIGridLayout", {
								CellSize = UDim2.fromOffset(
									math.floor(targetCellWidth),
									targetCellHeight
								),
								CellPadding = UDim2.fromOffset(gapX, gapY),
								FillDirection = Enum.FillDirection.Horizontal,
								FillDirectionMaxCells = columns,
								SortOrder = Enum.SortOrder.LayoutOrder,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
							}),
							Padding = React.createElement("UIPadding", {
								PaddingTop = UDim.new(0, gridPaddingTop),
								PaddingBottom = UDim.new(0, gridPaddingBottom),
								PaddingLeft = UDim.new(0, 8),
								PaddingRight = UDim.new(0, 8),
							}),
						}

						for i = 1, skeletonCount do
							skeletons["SkeletonWrapper_" .. tostring(i)] = React.createElement(
								"Frame",
								{
									BackgroundTransparency = 1,
									Size = UDim2.fromScale(1, 1),
									LayoutOrder = i,
								},
								{
									ScalerContainer = React.createElement("Frame", {
										BackgroundTransparency = 1,
										Size = UDim2.fromOffset(originalWidth, originalHeight),
									}, {
										UIScale = React.createElement("UIScale", { Scale = scale }),
										Card = React.createElement(AvatarTemplateCardSkeleton, {
											layoutOrder = i,
										}),
									}),
								}
							)
						end

						return React.createElement("ScrollingFrame", {
							Size = UDim2.new(1, 0, 1, -LIST_OFFSET - PAGINATION_HEIGHT),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							ClipsDescendants = true,
							ScrollBarThickness = 0,
							CanvasSize = UDim2.new(0, 0, 0, estimatedContentHeight),
							LayoutOrder = 7,
							[React.Change.AbsoluteSize] = function(rbx)
								local nextWidth = rbx.AbsoluteSize.X / contentScale
								if nextWidth > 0 and nextWidth ~= containerWidth then
									setContainerWidth(nextWidth)
								end
							end,
						}, skeletons)
					end

					if #templates == 0 then
						local emptyText = "Template atau username tidak ditemukan."
						if searchState == "error" then
							emptyText = "Gagal memuat pencarian."
						end

						return React.createElement("Frame", {
							Size = UDim2.new(1, 0, 1, -LIST_OFFSET - PAGINATION_HEIGHT),
							BackgroundTransparency = 1,
							LayoutOrder = 7,
						}, {
							EmptyText = React.createElement(Text, {
								text = emptyText,
								font = Theme.Font.Regular,
								textSize = 18,
								color = Theme.Color.TextPrimary,
								size = UDim2.fromScale(1, 1),
								textXAlignment = Enum.TextXAlignment.Center,
								textYAlignment = Enum.TextYAlignment.Center,
							}),
						})
					end

					local columns = 5
					local sidePadding = 16
					local usableWidth = math.max(containerWidth - sidePadding, 1)
					local gapX = 18
					local gapY = 14
					local originalWidth = 248
					local originalHeight = 342

					local targetCellWidth =
						math.max((usableWidth - (gapX * (columns - 1))) / columns, 1)
					local scale = targetCellWidth / originalWidth
					local targetCellHeight = math.floor(originalHeight * scale)
					local pageItemCount = #templates
					local rowCount = math.max(math.ceil(pageItemCount / columns), 1)
					local gridPaddingTop = 12
					local gridPaddingBottom = 28
					local estimatedContentHeight = gridPaddingTop
						+ (rowCount * targetCellHeight)
						+ (math.max(rowCount - 1, 0) * gapY)
						+ gridPaddingBottom

					return React.createElement("ScrollingFrame", {
						Size = UDim2.new(1, 0, 1, -LIST_OFFSET - PAGINATION_HEIGHT),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ClipsDescendants = true,
						ScrollBarThickness = 0,
						CanvasSize = UDim2.new(0, 0, 0, estimatedContentHeight),
						LayoutOrder = 7,
						[React.Change.AbsoluteSize] = function(rbx)
							local nextWidth = rbx.AbsoluteSize.X / contentScale
							if nextWidth > 0 and nextWidth ~= containerWidth then
								setContainerWidth(nextWidth)
							end
						end,
					}, {
						Layout = React.createElement("UIGridLayout", {
							CellSize = UDim2.fromOffset(
								math.floor(targetCellWidth),
								targetCellHeight
							),
							CellPadding = UDim2.fromOffset(gapX, gapY),
							FillDirection = Enum.FillDirection.Horizontal,
							FillDirectionMaxCells = columns,
							SortOrder = Enum.SortOrder.LayoutOrder,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
						}),
						Padding = React.createElement("UIPadding", {
							PaddingTop = UDim.new(0, gridPaddingTop),
							PaddingBottom = UDim.new(0, gridPaddingBottom),
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
						}),

						Cards = React.createElement(
							React.Fragment,
							nil,
							(function()
								local cards = {}
								for i, template in ipairs(templates) do
									if not template then
										continue
									end

									local key = template.templateId
										or template.userOutfitId
										or tostring(i)
									cards["Card_" .. tostring(key)] = React.createElement("Frame", {
										BackgroundTransparency = 1,
										Size = UDim2.fromScale(1, 1),
										LayoutOrder = i,
									}, {
										ScalerContainer = React.createElement("Frame", {
											BackgroundTransparency = 1,
											Size = UDim2.fromOffset(originalWidth, originalHeight),
										}, {
											UIScale = React.createElement(
												"UIScale",
												{ Scale = scale }
											),
											Card = React.createElement(AvatarTemplateCard, {
												templateData = template,
												isLoading = isLoading,
												pageToken = pageToken,
												onLoad = function(id)
													task.spawn(function()
														local requestId = -1
														if template.descriptionSnapshot then
															requestId =
																AvatarAppearanceClient.setOptimisticState(
																	template.descriptionSnapshot,
																	"avatar_loader"
																)
														end

														if
															template.sourceType == "roblox_outfit"
														then
															if LoadRobloxOutfitRemote then
																local res =
																	LoadRobloxOutfitRemote:InvokeServer(
																		id
																	)
																if not res.success then
																	warn(
																		"Failed to load outfit:",
																		res.error
																	)
																	if requestId ~= -1 then
																		AvatarAppearanceClient.rollbackOptimisticState(
																			requestId
																		)
																	end
																else
																	if requestId ~= -1 then
																		AvatarAppearanceClient.resolveOptimisticState(
																			requestId,
																			res.liveSnapshot,
																			res.liveRevision,
																			"avatar_loader"
																		)
																	else
																		AvatarAppearanceClient.updateState(
																			res.liveSnapshot,
																			res.liveRevision,
																			"avatar_loader"
																		)
																	end
																end
															end
														else
															if LoadAvatarTemplateRemote then
																local res =
																	LoadAvatarTemplateRemote:InvokeServer(
																		id
																	)
																if not res.success then
																	warn(
																		"Failed to load template:",
																		res.error
																	)
																	if requestId ~= -1 then
																		AvatarAppearanceClient.rollbackOptimisticState(
																			requestId
																		)
																	end
																else
																	if requestId ~= -1 then
																		AvatarAppearanceClient.resolveOptimisticState(
																			requestId,
																			res.liveSnapshot,
																			res.liveRevision,
																			"avatar_loader"
																		)
																	else
																		AvatarAppearanceClient.updateState(
																			res.liveSnapshot,
																			res.liveRevision,
																			"avatar_loader"
																		)
																	end
																end
															end
														end
													end)
												end,
											}),
										}),
									})
								end
								return cards
							end)()
						),
					})
				end)(),

				PaginationSpacer = React.createElement(Spacer, {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					layoutOrder = 8,
				}),

				PaginationArea = (function()
					return React.createElement(PaginationControls, {
						currentPage = currentPage,
						totalPages = currentPage,
						hasNextPage = hasNextPage,
						layoutOrder = 9,
						onPrevious = function()
							if currentPage > 1 then
								setCurrentPage(currentPage - 1)
							end
						end,
						onNext = function()
							if hasNextPage then
								setCurrentPage(currentPage + 1)
							end
						end,
					})
				end)(),
			}),
		})
	)
end

return AvatarLoaderPanel
