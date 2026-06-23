local Theme = {}

Theme.Color = {
	Background = Color3.fromRGB(238, 242, 247),
	Panel = Color3.fromRGB(255, 255, 255),
	PanelSoft = Color3.fromRGB(250, 250, 252),
	Border = Color3.fromRGB(230, 232, 239),
	BorderStrong = Color3.fromRGB(216, 220, 230),
	TextPrimary = Color3.fromRGB(31, 36, 48),
	TextSecondary = Color3.fromRGB(98, 106, 120),
	TextMuted = Color3.fromRGB(154, 161, 173),
	Purple = Color3.fromRGB(167, 68, 234),
	Magenta = Color3.fromRGB(247, 25, 154),
	ActiveSoft = Color3.fromRGB(247, 234, 254),
	IconDark = Color3.fromRGB(78, 85, 98),
	Success = Color3.fromRGB(45, 190, 127),
	Danger = Color3.fromRGB(239, 68, 68),
}

Theme.Font = {
	Regular = Enum.Font.GothamSSm,
	Medium = Enum.Font.GothamSSmMedium,
	Bold = Enum.Font.GothamSSmBold,
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
