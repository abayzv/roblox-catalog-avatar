local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

export type SpacerProps = {
	size: number?,
	layoutOrder: number?,
}

local function Spacer(props: SpacerProps)
	return React.createElement("Frame", {
		Size = UDim2.fromOffset(props.size or 0, props.size or 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
	})
end

return Spacer
