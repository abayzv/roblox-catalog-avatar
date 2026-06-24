local CatalogConfig = {
	-- A whitelist of allowed AssetTypeIds that represent wearable catalog items
	-- This prevents exploiters from applying unsupported assets like Audio, Scripts, or Models.
	AllowedAssetTypes = {
		[2] = true, -- T-Shirt
		[8] = true, -- Hat
		[11] = true, -- Shirt
		[12] = true, -- Pants
		[41] = true, -- HairAccessory
		[42] = true, -- FaceAccessory
		[43] = true, -- NeckAccessory
		[44] = true, -- ShoulderAccessory
		[45] = true, -- FrontAccessory
		[46] = true, -- BackAccessory
		[47] = true, -- WaistAccessory
		[64] = true, -- TShirtAccessory
		[65] = true, -- ShirtAccessory
		[66] = true, -- PantsAccessory
		[67] = true, -- JacketAccessory
		[68] = true, -- SweaterAccessory
		[69] = true, -- ShortsAccessory
		[70] = true, -- LeftShoeAccessory
		[71] = true, -- RightShoeAccessory
		[72] = true, -- DressSkirtAccessory
	},

	-- Toggle this to true if the game requires players to actually own the items to apply them to their live character
	RequireOwnership = false,
}

return CatalogConfig
