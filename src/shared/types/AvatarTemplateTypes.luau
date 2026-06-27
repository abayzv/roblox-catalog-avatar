export type AvatarTemplateRecord = {
	templateId: string,
	code: string,

	name: string, -- "Template 1", "Template 2", etc.

	creatorUserId: number,
	creatorUsername: string,
	creatorDisplayName: string?,

	descriptionSnapshot: { [string]: any },

	thumbnail: {
		imageUrl: string?,
		state: "Placeholder" | "Ready" | "Failed",
	},

	loadCount: number,

	createdAt: number,
	updatedAt: number,
	version: number,
}

export type AvatarTemplateCardData = {
	templateId: string,
	code: string,

	name: string,
	creatorUsername: string,

	thumbnailUrl: string?,
	thumbnailState: string,

	loadCount: number?,
}

export type ListTemplatesResponse = {
	success: boolean,
	templates: { AvatarTemplateCardData }?,
	nextCursor: string?,
	error: string?,
}

export type SaveTemplateResponse = {
	success: boolean,
	template: AvatarTemplateCardData?,
	error: string?,
}

export type LoadTemplateResponse = {
	success: boolean,
	liveSnapshot: any?,
	liveRevision: number?,
	templateId: string?,
	error: string?,
}

export type RobloxOutfitCardData = {
	sourceType: "roblox_outfit",
	userOutfitId: number,
	name: string,

	ownerUserId: number,
	ownerUsername: string?,

	thumbnailUrl: string?,
	thumbnailState: string,

	canLoad: boolean,
}

export type SearchAvatarLoaderResponse = {
	success: boolean,
	resultType: "template" | "roblox_outfits" | "empty" | "error",
	template: AvatarTemplateCardData?,
	owner: {
		userId: number,
		username: string,
	}?,
	outfits: { RobloxOutfitCardData }?,
	message: string?,
}

return {}
