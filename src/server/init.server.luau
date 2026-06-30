local AvatarApplyService = require(script.services.AvatarApplyService)
local ResolveEmotesService = require(script.services.ResolveEmotesService)
local AvatarTemplateService = require(script.services.AvatarTemplateService)
local ProxyService = require(script.services.ProxyService)

AvatarApplyService.init()
ResolveEmotesService.init()
AvatarTemplateService.init()
ProxyService.initialize()
