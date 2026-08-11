--!nonstrict
--[[
	TitleController.luau
	Shows the worn title in the two places other players look: over the head, and in front of chat.

	BOTH SURFACES READ A PLAYER ATTRIBUTE. `PlayerStateService` publishes `TitleTag` (already bracketed)
	and `TitleId` on the Player, so this controller draws OTHER people's titles with no remote, no
	request and no cache -- attributes replicate to every client and arrive with the Player instance, so
	someone who joined before you still shows up wearing theirs.

	THE NAMEPLATE REPLACES ROBLOX'S. `Humanoid.DisplayName` is drawn by the engine and cannot have a
	second line put under it, so the engine's version is switched off (`DisplayDistanceType = None`) and
	this draws both lines itself. That is the only way to get "title under name" rather than "title
	floating near name", and it means the two lines can never drift apart when the camera moves.

	The billboard is built here rather than authored in the place file, unlike the plot signs and the
	event board: it is attached to a character that does not exist until someone spawns, and respawning
	rebuilds it. There is nothing for a designer to position -- the head decides where it goes.

	SIZED IN STUDS, NOT PIXELS, so it behaves like a world object -- small when the camera is pulled back,
	large up close. `BillboardGui.Size` reads its SCALE component as studs and its OFFSET component as
	pixels, and an offset-sized plate is screen-locked: measured at 10 and 38 studs it came back the exact
	same size on screen both times, which is what made a zoomed-out yard look like it was covered in
	full-size labels.

	Everything inside is therefore in scale units too, and the text uses `TextScaled` so it follows the
	canvas rather than staying at a fixed pixel height inside a shrinking box. The TIER sizes are
	fractions of the plate rather than TextSize values for the same reason.

	TWO FORMS OF THE SAME TITLE. Chat gets `[SCRAP BARON]`, because a tag in a line of prose has to be
	told apart from the message. Over a head it is just SCRAP BARON, dressed according to its rarity --
	there is nothing to disambiguate from up there, and brackets make a title look like a placeholder.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)

local TitleController = {}

local NAMEPLATE = "ScrapyardNameplate"
local started = false

--[[
	HOW GOOD THE TITLE IS, AS A LOOK.

	One table, five tiers, and the escalation is the whole point: a Common title should read as a label
	and a Mythic one should stop you walking past. Every tier adds to the one below rather than replacing
	it, so the ladder is legible from across the yard even if you cannot read the words yet.

		Common     flat grey. It is a label.
		Rare       the rarity colour.
		Epic       a gradient across the glyphs -- reads as metal rather than ink.
		Legendary  gradient, bigger, and a glow behind it that breathes.
		Mythic     all of that, plus the gradient SCROLLS and sparkles orbit the text.

	Built from plain Frames and `TweenService` exactly like `Components/Shine` does it -- no textures, no
	ParticleEmitter, nothing to upload. A nameplate is drawn for every player in the server, so the cost
	of the top tier has to stay in the region of a handful of tweens.
]]
local TIERS = {
	Common = { height = 0.62, gradient = false, scroll = false, glow = false, sparkles = 0 },
	Rare = { height = 0.7, gradient = false, scroll = false, glow = false, sparkles = 0 },
	Epic = { height = 0.78, gradient = true, scroll = false, glow = false, sparkles = 0 },
	Legendary = { height = 0.88, gradient = true, scroll = false, glow = true, sparkles = 0 },
	Mythic = { height = 0.95, gradient = true, scroll = true, glow = true, sparkles = 3 },
	--[[
		Staff. The one tier that cannot be earned, so it is allowed to be the loudest thing on screen: the
		full treatment, faster sheen, and every sparkle slot filled.
	]]
	Staff = { height = 1, gradient = true, scroll = true, glow = true, sparkles = 3, fast = true },
}

--[[
	The plate, in studs.

	4.6 x 1.15 is what reproduced the old pixel size at about ten studs -- close enough that the change
	reads as "it now shrinks", not "it changed size". The name takes the upper 45% and the title the lower
	40%, and each tier fills a FRACTION of its lane, which is how "bigger is better" survives the move
	away from pixel text sizes.
]]
local PLATE_STUDS = Vector2.new(4.6, 1.15)
local NAME_LANE = 0.45
local TITLE_LANE = 0.4

local function tierFor(rarity: string?)
	return TIERS[rarity or ""] or TIERS.Common
end

--- The accent a rarity is drawn in, resolved through `Theme` here rather than in the shared config.
local function rarityColor(titleId: string?): Color3
	local definition = TitleConfig.resolve(titleId)
	if definition == nil then
		return Theme.Color.Gray
	end
	return Theme.Color[TitleConfig.accent(definition)] or Theme.Color.Gray
end

--[[
	Tweens live and die with the plate they decorate.

	A tween on a destroyed instance stops on its own, but it is still holding a reference until the
	garbage collector gets there -- and characters respawn constantly. Cancelling explicitly when the
	title block is rebuilt keeps that from piling up.
]]
local activeTweens: { [Instance]: { Tween } } = {}

local function cancelTweens(host: Instance)
	local tweens = activeTweens[host]
	if tweens then
		for _, tween in tweens do
			tween:Cancel()
		end
		activeTweens[host] = nil
	end
end

local function remember(host: Instance, tween: Tween)
	local tweens = activeTweens[host]
	if tweens == nil then
		tweens = {}
		activeTweens[host] = tweens
	end
	table.insert(tweens, tween)
	tween:Play()
end

--[[
	A glow behind the text: two soft discs that breathe out of phase.

	The same trick `Shine` uses -- rounded frames rather than a blurred texture, because the engine has
	no blur for GUIs and a glow asset would be one more thing to upload and keep.
]]
local function buildGlow(host: Frame, colour: Color3)
	--[[
		THREE FAINT LAYERS, NOT TWO STRONG ONES.

		The engine has no blur for GUIs, so a glow is faked by stacking translucent discs -- and the trick
		only works if each one is nearly invisible. At two discs of 0.55 and 0.8 transparency the pair read
		as a solid pink lozenge behind the text: a plate, not a halo. Three at 0.78/0.88/0.94, each wider
		than the last, fall off instead of stacking up.
	]]
	local specs = {
		{ wide = 0.46, tall = 1.15, alpha = 0.78 },
		{ wide = 0.66, tall = 1.5, alpha = 0.88 },
		{ wide = 0.88, tall = 1.9, alpha = 0.94 },
	}
	for index, spec in ipairs(specs) do
		local disc = Instance.new("Frame")
		disc.Name = `Glow{index}`
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.5)
		disc.Size = UDim2.fromScale(spec.wide, spec.tall)
		disc.BackgroundColor3 = colour
		disc.BackgroundTransparency = spec.alpha
		disc.BorderSizePixel = 0
		disc.ZIndex = 1
		disc.Parent = host

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = disc

		remember(
			host,
			TweenService:Create(
				disc,
				TweenInfo.new(
					2.2 + index * 0.5,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut,
					-1,
					true,
					index * 0.4
				),
				{
					Size = UDim2.fromScale(spec.wide * 1.16, spec.tall * 1.16),
					BackgroundTransparency = math.min(spec.alpha + 0.05, 1),
				}
			)
		)
	end
end

--- Sparkles that fade in and out around the text. Reserved for the top tier; see `TIERS`.
local function buildSparkles(host: Frame, colour: Color3, count: number)
	local spots = {
		{ x = 0.08, y = 0.24 },
		{ x = 0.93, y = 0.7 },
		{ x = 0.72, y = 0.14 },
	}
	for index = 1, math.min(count, #spots) do
		local spot = spots[index]
		local star = Instance.new("Frame")
		star.Name = `Sparkle{index}`
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(spot.x, spot.y)
		--- Scale units, so a sparkle shrinks with the plate instead of becoming a dot the size of the text.
		star.Size = UDim2.fromScale(0.02, 0.09)
		star.BackgroundColor3 = colour
		star.BackgroundTransparency = 1
		star.BorderSizePixel = 0
		star.ZIndex = 4
		star.Parent = host

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = star

		remember(
			host,
			TweenService:Create(
				star,
				TweenInfo.new(
					0.9,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.InOut,
					-1,
					true,
					index * 0.45
				),
				{ Size = UDim2.fromScale(0.045, 0.2), BackgroundTransparency = 0.05 }
			)
		)
	end
end

--[[
	Draw the title line at its tier.

	Rebuilt from scratch whenever the worn title changes rather than being edited in place: the tiers
	differ in which CHILDREN exist, not just in colour, and reconciling that by hand is how a Mythic
	plate ends up keeping its sparkles after switching to a Common one.
]]
local function paintTitle(block: Frame, titleId: string?)
	cancelTweens(block)
	for _, child in ipairs(block:GetChildren()) do
		child:Destroy()
	end

	local definition = TitleConfig.resolve(titleId)
	block.Visible = definition ~= nil
	if definition == nil then
		return
	end

	local colour = rarityColor(titleId)
	local tier = tierFor(definition.Rarity)

	if tier.glow then
		buildGlow(block, colour)
	end

	--[[
		NO BRACKETS OVER THE HEAD. `[SCRAP BARON]` is the chat form, where the tag has to be told apart
		from the message around it. Over a head there is nothing to disambiguate from, and the brackets
		just make the title look like a placeholder.
	]]
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	--- The tier decides how much of the lane the text fills; `TextScaled` does the rest.
	label.Size = UDim2.fromScale(1, tier.height)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = colour
	label.Text = definition.Text
	label.ZIndex = 3
	label.Parent = block

	--[[
		The outline is a FRACTION of the rendered text, not a fixed pixel count.

		`UIStroke.Thickness` is in pixels and does not follow `TextScaled`, so a fixed 3px outline turns a
		distant title into a solid blob. `UITextSizeConstraint` is what makes the rendered size knowable
		here: the cap is also the number the stroke is derived from.
	]]
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 22
	constraint.MinTextSize = 1
	constraint.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Theme.Color.Outline
	stroke.Parent = label

	if tier.gradient then
		--[[
			A light-to-accent ramp across the glyphs. `UIGradient` tints the text itself, so the outline
			above stays ink -- which is what keeps a pale gradient readable against a bright sky.
		]]
		local gradient = Instance.new("UIGradient")
		gradient.Name = "Sheen"
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, colour:Lerp(Color3.new(1, 1, 1), 0.75)),
			ColorSequenceKeypoint.new(0.5, colour),
			ColorSequenceKeypoint.new(1, colour:Lerp(Color3.new(1, 1, 1), 0.75)),
		})
		gradient.Parent = label

		if tier.scroll then
			--- The sheen travels. Offset, not rotation: rotating a gradient would not move the highlight.
			gradient.Offset = Vector2.new(-1, 0)
			remember(
				block,
				TweenService:Create(
					gradient,
					TweenInfo.new(
						if tier.fast then 1.5 else 2.4,
						Enum.EasingStyle.Linear,
						Enum.EasingDirection.InOut,
						-1
					),
					{ Offset = Vector2.new(1, 0) }
				)
			)
		end
	end

	if tier.sparkles > 0 then
		buildSparkles(block, colour, tier.sparkles)
	end
end

--[[
	Build the two-line plate. NAME on top, title UNDER it.

	`AlwaysOnTop` is deliberately FALSE: a name that draws through walls turns a yard full of players
	into a wall of text, and the engine's own nameplates do not do it either.
]]
local function buildNameplate(character: Model, player: Player): BillboardGui?
	local head = character:FindFirstChild("Head")
	if head == nil then
		return nil
	end
	local existing = head:FindFirstChild(NAMEPLATE)
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = NAMEPLATE
	--- Studs, so perspective applies. See the note in the header.
	billboard.Size = UDim2.fromScale(PLATE_STUDS.X, PLATE_STUDS.Y)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 0)
	layout.Parent = billboard

	--- The name first, so the title sits beneath it -- which is where a title belongs.
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, NAME_LANE)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Theme.Color.White
	nameLabel.Text = player.DisplayName
	nameLabel.LayoutOrder = 1
	nameLabel.Parent = billboard

	--- Caps how large the name gets up close; without it a nose-to-nose camera fills the screen with it.
	local nameConstraint = Instance.new("UITextSizeConstraint")
	nameConstraint.MaxTextSize = 24
	nameConstraint.MinTextSize = 1
	nameConstraint.Parent = nameLabel

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2
	nameStroke.Color = Theme.Color.Outline
	nameStroke.Parent = nameLabel

	--[[
		The title gets its own FRAME rather than being a second label, because the richer tiers need
		somewhere to put a glow behind the text and sparkles around it.
	]]
	local block = Instance.new("Frame")
	block.Name = "Title"
	block.BackgroundTransparency = 1
	block.Size = UDim2.fromScale(1, TITLE_LANE)
	block.LayoutOrder = 2
	block.Parent = billboard

	paintTitle(block, player:GetAttribute("TitleId"))

	billboard.Parent = head
	return billboard
end

local function refresh(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	local billboard = if head then head:FindFirstChild(NAMEPLATE) else nil
	if billboard == nil then
		return
	end
	local block = billboard:FindFirstChild("Title")
	if block and block:IsA("Frame") then
		paintTitle(block, player:GetAttribute("TitleId"))
	end
end

local function bind(player: Player)
	local function onCharacter(character: Model)
		--[[
			The Head arrives with the character, but a humanoid's parts can still be assembling; polling
			briefly is the same fix the plot signs use for replicated models.
		]]
		task.spawn(function()
			local deadline = os.clock() + 10
			while os.clock() < deadline do
				if buildNameplate(character, player) then
					break
				end
				task.wait(0.25)
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				--- Ours replaces the engine's, or the name would be drawn twice at two sizes.
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	--- `TitleId` is what the plate reads: the tier and the text both come from the definition.
	player:GetAttributeChangedSignal("TitleId"):Connect(function()
		refresh(player)
	end)
end

function TitleController.Start()
	if started then
		return
	end
	started = true

	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerAdded:Connect(bind)

	--[[
		CHAT PREFIX.

		`OnIncomingMessage` runs on every client for every message, and returning `FluffChatProperties`
		with a `PrefixText` puts the tag in front of the speaker's name -- which is the one place Roblox
		lets a game decorate chat without replacing the whole window.

		The speaker is resolved through `TextSource.UserId` rather than the message text, because a
		display name is not unique and the tag has to belong to the person who actually spoke.
	]]
	local function decorate(message: TextChatMessage)
		local source = message.TextSource
		if source == nil then
			return nil
		end
		local player = Players:GetPlayerByUserId(source.UserId)
		if player == nil then
			return nil
		end
		local tag = tostring(player:GetAttribute("TitleTag") or "")
		if tag == "" then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		--[[
			The colour is baked in as rich text: `PrefixText` is one string, so the only way to tint the
			tag differently from the name is markup inside it.
		]]
		local colour = rarityColor(player:GetAttribute("TitleId"))
		properties.PrefixText =
			string.format('<font color="#%s">%s</font> %s', colour:ToHex(), tag, message.PrefixText)
		return properties
	end

	TextChatService.OnIncomingMessage = decorate
end

return TitleController
