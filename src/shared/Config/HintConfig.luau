--!strict
--[[
	HintConfig.luau
	One-shot affordance toasts.

	The first time a player can pay for the next magnet or the next yard, tell them
	once and never again. Not a tutorial: no modal, no arrow, nothing to dismiss.
	`Notify` is a plain string -- see AGENTS.md.

	`AffordHintService` evaluates these from saved state. The client never says
	"I can afford this". Adding a hint is a row here plus an id the schema will
	store when it fires.
]]

export type AffordHintKind = "Area" | "Magnet"

export type AffordHint = {
	Id: string,
	Kind: AffordHintKind,
	TargetId: string,
	Message: string,
}

local hints: { AffordHint } = {
	table.freeze({
		Id = "WorkshopYard",
		Kind = "Area" :: AffordHintKind,
		TargetId = "WorkshopYard",
		Message = "You can unlock the Workshop Yard -- walk into the Area Shop.",
	}),
	table.freeze({
		Id = "AdvancedMagnet",
		Kind = "Magnet" :: AffordHintKind,
		TargetId = "AdvancedMagnet",
		Message = "You can buy a stronger magnet -- walk into the Magnet Shop.",
	}),
}

return table.freeze({
	Hints = table.freeze(hints),
	CheckIntervalSeconds = 2,
})
