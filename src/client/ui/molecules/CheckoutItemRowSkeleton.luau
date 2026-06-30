local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

export type CheckoutItemRowSkeletonProps = {
	layoutOrder: number?,
}

local function CheckoutItemRowSkeleton(props: CheckoutItemRowSkeletonProps)
	local offsetBinding, setOffsetBinding = React.useBinding(0)

	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			local newOffset = (tick() * 1.5) % 2 - 1
			setOffsetBinding(newOffset)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local function SkeletonBlock(width: UDim, height: number, layoutOrder: number)
		return React.createElement(
			"Frame",
			{
				Size = UDim2.new(width.Scale, width.Offset, 0, height),
				BackgroundColor3 = Color3.fromRGB(235, 238, 245),
				BorderSizePixel = 0,
				LayoutOrder = layoutOrder,
				ClipsDescendants = true,
			},
			React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.SM),
			}),
			React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 238, 245)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(245, 247, 250)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 238, 245)),
				}),
				Rotation = 45,
				Offset = offsetBinding:map(function(offset)
					return Vector2.new(offset, 0)
				end),
			})
		)
	end

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
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, SkeletonBlock(UDim.new(1, 0), 56, 1)),

		-- Info Area (Name & Type)
		InfoArea = React.createElement("Frame", {
			Size = UDim2.new(1, -260 - 56 - Theme.Space.MD * 3, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
			}),
			NameSkeleton = SkeletonBlock(UDim.new(0.6, 0), 20, 1),
			PropertySkeleton = SkeletonBlock(UDim.new(0.4, 0), 16, 2),
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
			PriceSkeleton = SkeletonBlock(UDim.new(1, 0), 20, 1),
		}),

		-- Remove Button
		RemoveButtonSkeleton = React.createElement("Frame", {
			Size = UDim2.fromOffset(100, 36),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
		}, SkeletonBlock(UDim.new(1, 0), 36, 1)),

		-- Buy Button
		BuyButtonSkeleton = React.createElement("Frame", {
			Size = UDim2.fromOffset(80, 36),
			BackgroundTransparency = 1,
			LayoutOrder = 5,
		}, SkeletonBlock(UDim.new(1, 0), 36, 1)),
	})
end

return CheckoutItemRowSkeleton
