local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Parent.theme.Theme)

export type AvatarTemplateCardSkeletonProps = {
	layoutOrder: number?,
}

local function AvatarTemplateCardSkeleton(props: AvatarTemplateCardSkeletonProps)
	local offsetBinding, setOffsetBinding = React.useBinding(0)

	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function()
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

	return React.createElement(
		"Frame",
		{
			Size = UDim2.fromOffset(248, 342),
			BackgroundColor3 = Theme.Color.Panel,
			LayoutOrder = props.layoutOrder,
		},
		React.createElement(React.Fragment, nil, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.Radius.LG),
			}),
			UIStroke = React.createElement("UIStroke", {
				Color = Theme.Color.Border,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),

			ImageContainer = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 218),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}, SkeletonBlock(UDim.new(1, 0), 218, 1)),

			NameSkeleton = SkeletonBlock(UDim.new(0.82, 0), 22, 2),
			MetaSkeleton = SkeletonBlock(UDim.new(0.58, 0), 16, 3),
			ButtonSkeleton = SkeletonBlock(UDim.new(1, 0), 36, 4),
		})
	)
end

return AvatarTemplateCardSkeleton
