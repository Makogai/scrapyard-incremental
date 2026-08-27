--!strict
--[[
	MagnetSkinConfig.luau
	Cosmetic magnet skins: one look for the held magnet AND the reach ring.

	PURE COSMETIC. Stats stay on the equipped magnet. Each skin has its OWN
	motion -- sharing one sweep-and-balls loop across four skins made them
	read as recolours of each other.

		YardPaint     stacked hoops, slow inward pulse, nothing racing the rim
		ChromeCoil    current flowing around the circle
		EmberCore     lava pool: bubbles, hopping fireballs, sparks, flowing rim
		Orbital       solid 3D hoops at different heights, spinning
		EventHorizon  tilted void hoops plus flat spinning swirl discs on the reach plane
]]

export type RangeRing = {
	Accent: string,
	Fill: number,
	Rim: number,
	SecondRim: number,
	Sweep: boolean,
	PulseSeconds: number,
	PulseRings: number,
	AccentSecondary: string?,
	ThirdRim: number?,
	ThirdRimScale: number?,
	CoreFill: number?,
	CoreScale: number?,
	CoreAccent: string?,
	Motes: number?,
	MoteSpeed: number?,
	--- `"spiral"` falls inward (Event Horizon). `"rise"` is fire. Nil is none.
	MoteMode: string?,
	RimLift: number?,
	InnerLift: number?,
	--- Traveling brightness around the outer hoop. Nil is a still ring.
	FlowSpeed: number?,
	FlowLobes: number?,
	--- Draw 1 of every N segments so a spin is visible. Nil is a solid hoop.
	Dash: number?,
	--- Radians per second added to dashed / tilted hoops.
	Spin: number?,
	--- Tilt on the inner hoops, so stacked rings read as planet rings not stickers.
	Tilt: number?,
	--- Vertical travel in studs. Lowest point still clears the floor.
	Bob: number?,
	--- `"Void"` is Event Horizon. `"Ember"` is the lava pool kit.
	Fx: string?,
}

export type MagnetSkin = {
	Id: string,
	DisplayName: string,
	Description: string,
	Rarity: string,
	Glyph: string,
	Accent: string,
	Form: string,
	RangeRing: RangeRing,
}

local function ring(definition: RangeRing): RangeRing
	return table.freeze(definition)
end

local function skin(definition: MagnetSkin): MagnetSkin
	return table.freeze(definition)
end

local order = table.freeze({
	"YardPaint",
	"ChromeCoil",
	"EmberCore",
	"Orbital",
	"EventHorizon",
})

local byId: { [string]: MagnetSkin } = {
	YardPaint = skin({
		Id = "YardPaint",
		DisplayName = "Yard Paint",
		Description = "A rusty orange respray. The starter skin.",
		Rarity = "Common",
		Glyph = "magnet",
		Accent = "Orange",
		Form = "Horseshoe",
		RangeRing = ring({
			Accent = "Orange",
			Fill = 0.05,
			Rim = 0.2,
			SecondRim = 0.12,
			Sweep = false,
			PulseSeconds = 2.5,
			PulseRings = 1,
			RimLift = 0.35,
			InnerLift = 0.7,
		}),
	}),
	ChromeCoil = skin({
		Id = "ChromeCoil",
		DisplayName = "Chrome Coil",
		Description = "Polished steel with a cool rim.",
		Rarity = "Uncommon",
		Glyph = "magnet",
		Accent = "Cyan",
		Form = "Horseshoe",
		RangeRing = ring({
			Accent = "Cyan",
			AccentSecondary = "Blue",
			Fill = 0.04,
			Rim = 0.2,
			SecondRim = 0.12,
			Sweep = true,
			PulseSeconds = 2,
			PulseRings = 1,
			RimLift = 0.45,
			InnerLift = 0.95,
			FlowSpeed = 0.55,
			FlowLobes = 3,
		}),
	}),
	EmberCore = skin({
		Id = "EmberCore",
		DisplayName = "Ember Core",
		Description = "A coil of molten scrap. Lava under the pull.",
		Rarity = "Rare",
		Glyph = "magnet",
		Accent = "Orange",
		Form = "Coil",
		RangeRing = ring({
			Accent = "Orange",
			AccentSecondary = "Gold",
			Fill = 0,
			Rim = 0.2,
			SecondRim = 0.14,
			ThirdRim = 0.12,
			ThirdRimScale = 0.72,
			Sweep = false,
			PulseSeconds = 1.4,
			PulseRings = 0,
			Motes = 16,
			MoteSpeed = 0.72,
			MoteMode = "rise",
			RimLift = 1.05,
			InnerLift = 1.55,
			FlowSpeed = 0.5,
			FlowLobes = 4,
			Fx = "Ember",
		}),
	}),
	Orbital = skin({
		Id = "Orbital",
		DisplayName = "Orbital",
		Description = "Planet rings around the pull.",
		Rarity = "Epic",
		Glyph = "star",
		Accent = "Gold",
		Form = "Planet",
		RangeRing = ring({
			Accent = "Gold",
			AccentSecondary = "Orange",
			Fill = 0.03,
			Rim = 0.2,
			SecondRim = 0.16,
			ThirdRim = 0.14,
			ThirdRimScale = 0.58,
			Sweep = false,
			PulseSeconds = 2.2,
			PulseRings = 1,
			RimLift = 1.4,
			InnerLift = 2.8,
			Spin = 0.7,
			Tilt = 0.32,
			Bob = 1.15,
		}),
	}),
	EventHorizon = skin({
		Id = "EventHorizon",
		DisplayName = "Event Horizon",
		Description = "A black-hole core. The lootbox rare.",
		Rarity = "Legendary",
		Glyph = "star",
		Accent = "Purple",
		Form = "Void",
		RangeRing = ring({
			Accent = "Purple",
			AccentSecondary = "Pink",
			Fill = 0.04,
			Rim = 0.22,
			SecondRim = 0.16,
			ThirdRim = 0.12,
			ThirdRimScale = 0.36,
			CoreFill = 0.38,
			CoreScale = 0.2,
			CoreAccent = "Ink",
			Sweep = true,
			PulseSeconds = 1.15,
			PulseRings = 0,
			Motes = 12,
			MoteSpeed = 0.85,
			MoteMode = "spiral",
			RimLift = 1.2,
			InnerLift = 2.8,
			Spin = 0.95,
			Tilt = 0.42,
			Fx = "Void",
		}),
	}),
}

return table.freeze({
	ById = table.freeze(byId),
	Order = order,
})
