local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)
local Icons = require(script.Parent.Parent.theme.Icons)
local ButtonBase = require(script.Parent.Parent.atoms.ButtonBase)
local Icon = require(script.Parent.Parent.atoms.Icon)
local AvatarPreviewController =
	require(script.Parent.Parent.Parent.controllers.AvatarPreviewController)
local CheckoutController = require(script.Parent.Parent.Parent.controllers.CheckoutController)
local PreviewPayloadCache = require(script.Parent.Parent.Parent.services.PreviewPayloadCache)

export type CheckoutItemRowProps = {
	item: any, -- CheckoutItem
	layoutOrder: number?,
}

local function CheckoutItemRow(props: CheckoutItemRowProps)
	local item = props.item

	local onRemove = React.useCallback(function()
		local payload = PreviewPayloadCache.get(item.key)
		if payload then
			AvatarPreviewController.ToggleItemPreview(item)
		else
			AvatarPreviewController.RemoveWornItem(item)
		end
	end, { item })

	local onBuy = React.useCallback(function()
		CheckoutController.promptPurchase(item)
	end, { item })

	local isBuyable = not item.isOffSale and not item.isFree

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = props.layoutOrder,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, Theme.Radius.MD),
		}),
		UIStroke = React.createElement("UIStroke", {
			Color = Theme.Color.Border,
			Thickness = 1,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner
		}),
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, Theme.Space.SM),
			PaddingBottom = UDim.new(0, Theme.Space.SM),
			PaddingLeft = UDim.new(0, Theme.Space.SM),
			PaddingRight = UDim.new(0, Theme.Space.MD),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Theme.Space.MD),
		}),

		-- Thumbnail
		ThumbnailContainer = React.createElement("Frame", {
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = Theme.Color.Panel,
			LayoutOrder = 1,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.MD),
			}),
			UIStroke = React.createElement("UIStroke", {
				Color = Theme.Color.Border,
				Thickness = 1,
			}),
			Image = React.createElement("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = item.image,
			}, {
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, Theme.Radius.MD),
				}),
			}),
		}),

		-- Info Area (Name & Type)
		InfoArea = React.createElement("Frame", {
			Size = UDim2.new(1, -260 - 56 - Theme.Space.MD * 3, 1, 0), -- Flexible width
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
			}),
			NameLabel = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = item.name,
				Font = Theme.Font.Bold,
				TextSize = Theme.Text.Body,
				TextColor3 = Theme.Color.TextPrimary,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 1,
			}),
			PropertyLabel = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = item.property,
				Font = Theme.Font.Medium,
				TextSize = Theme.Text.Small,
				TextColor3 = Theme.Color.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}),
		}),

		-- Price Area
		PriceArea = React.createElement("Frame", {
			Size = UDim2.fromOffset(60, 40),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 4),
			}),
			RobuxIcon = isBuyable and React.createElement(Icon, {
				image = Icons.Robux or "rbxassetid://0",
				size = 16,
				color = Theme.Color.TextPrimary,
				layoutOrder = 1,
			}) or nil,
			PriceText = React.createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = item.isOffSale and "Off-Sale"
					or (item.isFree and "Free" or tostring(item.price)),
				Font = Theme.Font.Bold,
				TextSize = Theme.Text.Body,
				TextColor3 = Theme.Color.TextPrimary,
				LayoutOrder = 2,
			}),
		}),

		-- Remove Button
		RemoveButton = React.createElement(ButtonBase, {
			size = UDim2.fromOffset(100, 36),
			layoutOrder = 4,
			onActivated = onRemove,
			render = function(isHovered, isPressed)
				local bgColor = isPressed and Color3.fromRGB(230, 230, 230)
					or (isHovered and Color3.fromRGB(240, 240, 240) or Color3.new(1, 1, 1))
				return React.createElement("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = bgColor,
				}, {
					UICorner = React.createElement(
						"UICorner",
						{ CornerRadius = UDim.new(0, Theme.Radius.MD) }
					),
					UIStroke = React.createElement(
						"UIStroke",
						{ Color = Theme.Color.Border, Thickness = 1 }
					),
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 6),
					}),
					Icon = React.createElement(Icon, {
						image = Icons.Trash or "rbxassetid://0",
						size = 16,
						color = Theme.Color.TextPrimary,
						layoutOrder = 1,
					}),
					Text = React.createElement("TextLabel", {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Text = "Remove",
						Font = Theme.Font.Bold,
						TextSize = Theme.Text.Small,
						TextColor3 = Theme.Color.TextPrimary,
						LayoutOrder = 2,
					}),
				})
			end,
		}),

		-- Buy Button
		BuyButton = React.createElement(ButtonBase, {
			size = UDim2.fromOffset(80, 36),
			layoutOrder = 5,
			onActivated = isBuyable and onBuy or nil,
			render = function(isHovered, isPressed)
				local alpha = isBuyable and 0 or 0.5
				if isPressed then
					alpha = 0.2
				elseif isHovered and isBuyable then
					alpha = 0.1
				end

				return React.createElement("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
				}, {
					UICorner = React.createElement(
						"UICorner",
						{ CornerRadius = UDim.new(0, Theme.Radius.MD) }
					),
					UIGradient = React.createElement(
						"UIGradient",
						{ Color = Theme.Gradient.Primary }
					),
					Overlay = React.createElement("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Color3.new(0, 0, 0),
						BackgroundTransparency = 1 - alpha,
						ZIndex = 2,
					}, {
						UICorner = React.createElement(
							"UICorner",
							{ CornerRadius = UDim.new(0, Theme.Radius.MD) }
						),
					}),
					Text = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "Buy",
						Font = Theme.Font.Bold,
						TextSize = Theme.Text.Small,
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 3,
					}),
				})
			end,
		}),
	})
end

return CheckoutItemRow
