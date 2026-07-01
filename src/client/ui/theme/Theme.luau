local Theme = {}

Theme.Color = {
	Background = Color3.fromRGB(18, 20, 24),
	Panel = Color3.fromRGB(28, 31, 38),
	PanelSoft = Color3.fromRGB(36, 40, 49),
	PanelRaised = Color3.fromRGB(45, 50, 62),
	Border = Color3.fromRGB(48, 54, 68),
	BorderStrong = Color3.fromRGB(70, 77, 95),
	TextPrimary = Color3.fromRGB(240, 242, 248),
	TextSecondary = Color3.fromRGB(160, 168, 182),
	TextMuted = Color3.fromRGB(120, 128, 140),
	Purple = Color3.fromRGB(68, 107, 234),
	Magenta = Color3.fromRGB(25, 77, 247),
	ActiveSoft = Color3.fromRGB(35, 39, 60),
	IconDark = Color3.fromRGB(160, 168, 182),
	Success = Color3.fromRGB(45, 190, 127),
	Danger = Color3.fromRGB(239, 68, 68),
	SkeletonBase = Color3.fromRGB(70, 77, 95),
	SkeletonHighlight = Color3.fromRGB(50, 55, 68),
	Scrollbar = Color3.fromRGB(60, 66, 82),
	OverlayLight = Color3.fromRGB(255, 255, 255),
	OverlayDark = Color3.fromRGB(0, 0, 0),
}

Theme.Font = {
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}

Theme.Text = {
	Caption = 12,
	Small = 13,
	Body = 14,
	BodyStrong = 15,
	Button = 15,
	CardTitle = 16,
	Price = 17,
	Tab = 16,
	ScreenTitle = 18,
}

Theme.Radius = {
	XS = 6,
	SM = 8,
	MD = 12,
	LG = 14,
	XL = 16,
	Panel = 18,
}

Theme.Space = {
	XXS = 4,
	XS = 8,
	SM = 12,
	MD = 16,
	LG = 20,
	XL = 24,
	XXL = 32,
}

Theme.Gradient = {
	Primary = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Color.Purple),
		ColorSequenceKeypoint.new(1, Theme.Color.Magenta),
	}),
}

return Theme
