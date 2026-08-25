--!strict
--[[
	Bridge.luau
	The only place the UI talks to the server.

	Inbound  : RequestInitialState / StateChanged / Notify / CodeResult /
	           MonetizationResult / PetResult / OpenXShop -> atoms
	Outbound : one function per intent, each firing the existing remote

	Every action sends an INTENT and nothing else -- an upgrade id, an area id, a
	pet id. No price, level, reward, effect or unlock result ever leaves the
	client, which is the rule the whole server architecture is built on. If you
	add an action here and find yourself passing a number the server could have
	computed, stop: that is the exploit.

	The remote names come from Shared/Remotes/Definitions, so a rename there is a
	compile-time miss here rather than a silent no-op.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Atoms = require(script.Parent.Atoms)

local Bridge = {}

local remotes: Folder? = nil
local started = false
--- Guards the announcement timer so an older banner cannot clear a newer one.
local announceToken = 0
local nextToastId = 0

--[[
	Never asserts. RemoteService creates this folder on the server, so a client
	that renders before the server has finished booting would otherwise throw from
	inside a React effect and take the tree with it. Returning nil lets the UI draw
	its loading state and pick the remotes up on the next call.
]]
local function remoteFolder(): Folder?
	if not remotes then
		local found = ReplicatedStorage:FindFirstChild("Remotes")
		if found and found:IsA("Folder") then
			remotes = found
		end
	end
	return remotes
end

local function event(name: string): RemoteEvent?
	local folder = remoteFolder()
	if not folder then
		return nil
	end
	local instance = folder:FindFirstChild(name)
	if instance and instance:IsA("RemoteEvent") then
		return instance
	end
	warn(string.format("[ScrapyardUI] missing RemoteEvent %q", name))
	return nil
end

local function fire(name: string, ...: any)
	local remote = event(name)
	if remote then
		remote:FireServer(...)
	end
end

--------------------------------------------------------------------------------
-- Toasts
--------------------------------------------------------------------------------

--[[
	Pushes a notification. Newest first, capped, and each carries its own life so
	the client tick can expire them independently.

	IDENTICAL TOASTS COLLAPSE, THEY DO NOT STACK.

	The queue only holds four cards, so one message repeating on a tick fills the whole stack and
	pushes everything else off screen. That happened for real: a map-sized piece of scrap sat
	permanently inside the collection radius, got rejected every query, and the magnet warning
	buried the entire notification area.

	A repeat refreshes the card already on screen and counts it, in place -- same `Id` and same
	position, so React keeps the existing card and it does not re-animate or jump to the front.
	The player still sees it is happening, without losing the screen to it.

	This is the single choke point every toast goes through, so it protects against every
	producer rather than the one that happened to misbehave.
]]
local function isSameToast(a: { [string]: any }, b: { [string]: any }): boolean
	return a.Title == b.Title and a.Body == b.Body and a.Reward == b.Reward
end

function Bridge.notify(toast: { [string]: any })
	local incoming = {
		Title = toast.Title or "",
		Body = toast.Body,
		Reward = toast.Reward,
		Glyph = toast.Glyph,
		Accent = toast.Accent,
		Life = toast.Life or 4,
	}

	local queue = table.clone(Atoms.toasts())
	for index, existing in queue do
		if isSameToast(existing, incoming) then
			local refreshed = table.clone(existing)
			refreshed.Count = (existing.Count or 1) + 1
			refreshed.Life = incoming.Life
			queue[index] = refreshed
			Atoms.toasts(queue)
			return
		end
	end

	nextToastId += 1
	incoming.Id = nextToastId
	table.insert(queue, 1, incoming)
	while #queue > 4 do
		table.remove(queue)
	end
	Atoms.toasts(queue)
end

function Bridge.expireToasts(seconds: number)
	local queue = Atoms.toasts()
	if #queue == 0 then
		return
	end

	local kept = {}
	for _, toast in ipairs(queue) do
		local life = toast.Life - seconds
		if life > 0 then
			local copy = table.clone(toast)
			copy.Life = life
			table.insert(kept, copy)
		end
	end
	Atoms.toasts(kept)
end

--------------------------------------------------------------------------------
-- Outbound intents
--------------------------------------------------------------------------------

--[[
	Buy one upgrade, or several.

	`count` is a REQUEST, not a promise: the server prices every level itself and stops when the money or
	the level cap runs out. It exists because the client used to fire one event PER LEVEL, and the remote
	limiter allows 12 per 5 seconds -- so MAX silently bought twelve levels at best, and fewer if the player
	had clicked anything recently. One intent per press instead.
]]
function Bridge.requestUpgrade(upgradeId: string, count: number?)
	fire("RequestUpgrade", upgradeId, count)
end

function Bridge.requestAreaUnlock(areaId: string)
	fire("RequestAreaUnlock", areaId)
end

function Bridge.requestPrestige()
	fire("RequestPrestige")
end

function Bridge.updateSetting(settingId: string, value: any)
	fire("UpdateSettings", settingId, value)
end

function Bridge.equipMagnet(magnetId: string)
	fire("InventoryAction", "EquipMagnet", magnetId)
end

function Bridge.useConsumable(itemId: string)
	fire("InventoryAction", "UseConsumable", itemId)
end

--[[
	WEAR A PLOT SKIN, or "" to take it off.

	Goes through `InventoryAction` because that is where the player changes it -- and because a skin swap
	is exactly the shape that remote already handles: one string, server decides, `Notify` reports back.
]]
function Bridge.setPlotSkin(skinId: string)
	fire("InventoryAction", "SetPlotSkin", skinId)
end

function Bridge.buyMagnet(magnetId: string)
	fire("ShopAction", "BuyMagnet", magnetId)
end

function Bridge.buyPitItem(offerId: string)
	fire("ShopAction", "BuyPitItem", offerId)
end

--[[
	BUYING SOMETHING. Three outcomes, in order.

	THE PROMPT MUST HAPPEN ON THE CLIENT. `MarketplaceService:PromptGamePassPurchase` only opens the
	Roblox purchase dialog when called locally, so this cannot be a remote -- and it used to be one. Both
	of these fired `MonetizationPrompt`, whose server handler is gated on `RunService:IsStudio()` AND
	`AdminConfig.IsAdmin`: in a live server it returned immediately, so every buy button in the React UI
	silently did nothing. The shop, the magnet shop, the egg batch passes, Skip Rebirth and the details
	modal all route through here, so that was the whole monetization surface.

	`MonetizationPrompt` stays, but only as what it always was: the Studio-only, admin-only path that
	GRANTS without charging so a reward can be tested before it is live.

	A missing `MarketplaceId` says so out loud rather than doing nothing. Twenty-eight of them are still
	0 -- see `docs/MONETIZATION.md` -- and a dead button is indistinguishable from a broken game.
]]
--[[
	WHICH TABLE THE ID LIVES IN, rather than which string the caller happened to pass.

	Ids are unique across passes and products, so the id alone is enough -- and resolving it this way is
	immune to the bug that shipped: `UpgradesScreen` passed the kind as "product" while the dispatch
	compared against "Product", so every Robux upgrade fell through to the pass branch, found no pass by
	that id, and returned silently. A button that does nothing and says nothing is the worst failure mode
	available, and one capital letter caused it.

	`kind` survives only as a tiebreaker for an id that somehow exists in both, which cannot currently
	happen but is cheaper to handle than to prove impossible.
]]
local function resolvePurchase(id: string, kind: string?): ({ [string]: any }?, string)
	local pass = MonetizationConfig.Passes[id]
	local product = MonetizationConfig.Products[id]

	if pass ~= nil and product ~= nil then
		if kind ~= nil and string.lower(kind) == "product" then
			return product, "Product"
		end
		return pass, "Pass"
	end
	if product ~= nil then
		return product, "Product"
	end
	if pass ~= nil then
		return pass, "Pass"
	end
	return nil, "Pass"
end

local function promptPurchase(requestedKind: string?, id: string)
	local definition, kind = resolvePurchase(id, requestedKind)
	if definition == nil then
		--- An unknown id is a wiring mistake, not a player action. Say so rather than doing nothing.
		Bridge.notify({
			Title = "COULD NOT OPEN THAT",
			Body = `"{id}" is not a pass or a product.`,
		})
		return
	end

	local player = Players.LocalPlayer
	if definition.MarketplaceId > 0 then
		local ok = pcall(function()
			if kind == "Product" then
				MarketplaceService:PromptProductPurchase(player, definition.MarketplaceId)
			else
				MarketplaceService:PromptGamePassPurchase(player, definition.MarketplaceId)
			end
		end)
		--- A bad id is a configuration error, not a player error, so it says which item.
		if not ok then
			Bridge.notify({
				Title = "COULD NOT OPEN THAT",
				Body = `{definition.DisplayName} has a bad marketplace id.`,
			})
		end
		return
	end

	if RunService:IsStudio() then
		--- Admin-gated on the server; a non-admin in Studio simply gets nothing, same as before.
		fire("MonetizationPrompt", kind, id)
		return
	end

	Bridge.notify({
		Title = "NOT AVAILABLE YET",
		Body = `{definition.DisplayName} is not on sale yet.`,
	})
end

function Bridge.promptPass(passId: string)
	promptPurchase("Pass", passId)
end

function Bridge.promptProduct(productId: string)
	promptPurchase("Product", productId)
end

--- Kind-agnostic entry point: the id decides. What `actions.purchase` uses.
function Bridge.promptPurchase(id: string, kind: string?)
	promptPurchase(kind, id)
end

--[[
	PetService accepts exactly: OpenEgg, EquipPet, UnequipPet, DeletePet,
	BuyPetSlot. There is no bulk equip on the server, so "equip best" is a client
	loop of EquipPet intents -- each one still validated server-side.
]]
--- `count` is only meaningful for `DeletePet`, where it is how many copies to drop.
function Bridge.petAction(action: string, petId: string?, count: number?)
	fire("PetAction", action, petId, count)
end

--- `count` is the hatch batch size; the server checks the entitlement behind it and clamps.
function Bridge.openEgg(eggId: string, count: number?)
	fire("PetAction", "OpenEgg", eggId, count or 1)
end

function Bridge.redeemCode(code: string)
	fire("RedeemCode", code)
end

function Bridge.requestTeleport(destinationId: string)
	fire("RequestTeleport", destinationId)
end

--------------------------------------------------------------------------------
-- Return-to-play systems
--------------------------------------------------------------------------------

--[[
	INTENTS ONLY. `claimDaily` deliberately takes no arguments -- it used to be called with the day
	the client thought it was on, which is a value the server must never accept. The server reads
	the claimable day out of saved data.
]]
function Bridge.claimDaily()
	fire("ClaimDailyReward")
end

--[[
	Mailbox intents. A message ID, never a reward: what a message pays is read from the save, so a client
	that could name its own reward could mail itself anything.
]]
function Bridge.claimInbox(messageId: string)
	fire("InboxAction", "Claim", messageId)
end

function Bridge.claimAllInbox()
	fire("InboxAction", "ClaimAll")
end

--- The reward id is a lookup key. Group membership is re-checked server-side before anything is paid.
function Bridge.claimSocialReward(rewardId: string)
	fire("SocialAction", "ClaimReward", rewardId)
end

--[[
	No milestone index: the server picks the next claimable rung from the live friend count. A client that
	could name its own rung could claim the top one on its first join.
]]
function Bridge.claimInvite()
	fire("SocialAction", "ClaimInvite")
end

--- The milestone index is a lookup key, not a value: the server re-checks the banked seconds.
function Bridge.claimPlaytime(milestoneIndex: number)
	fire("ClaimPlaytimeReward", milestoneIndex)
end

function Bridge.requestSpin()
	fire("RequestSpin")
end

--[[
	Wear a title, or "" to take it off.

	Sends an ID and nothing else. The server owns whether the player holds it -- see
	`PlayerStateService.TryEquipTitle`, which refuses one they have not earned.
]]
function Bridge.equipTitle(titleId: string)
	fire("EquipTitle", titleId)
end

function Bridge.skipTutorial()
	fire("TutorialAction", "Skip")
end

--[[
	The one action that is NOT purely an intent, and the exception is deliberate: an admin grant is
	defined by its amount, so the number has to travel. `AdminService` checks `IsAdmin`, validates the
	command against a fixed list and clamps the amount before applying any of it, which is why this is
	safe where the same shape would be an exploit anywhere else in this file.
]]
function Bridge.adminCommand(
	command: string,
	amount: number?,
	targetMode: string,
	targetUserId: number?,
	itemId: string?
)
	fire("AdminCommand", command, amount, targetMode, targetUserId, itemId)
end

--------------------------------------------------------------------------------
-- Inbound
--------------------------------------------------------------------------------

--[[
	Connects every inbound remote and pulls the first snapshot.

	Safe to call more than once; only the first call connects. Returns true once
	an authoritative snapshot has been applied.
]]
function Bridge.start(): boolean
	if started then
		return Atoms.loaded()
	end

	--[[
		Deliberately not latched before the folder resolves. `RemoteService`
		creates `Remotes` during server boot, so a client that reaches here first
		just has to wait -- and a failed attempt that latched `started` would leave
		the UI permanently dead with no way back. Safe to yield: `Store` calls this
		from a `task.spawn`, never during render.
	]]
	local folder = ReplicatedStorage:WaitForChild("Remotes", 30) :: Folder?
	if not folder then
		warn("[ScrapyardUI] Remotes folder not replicated after 30s - retrying")
		return false
	end

	started = true
	remotes = folder

	local stateChanged = folder:FindFirstChild("StateChanged")
	if stateChanged and stateChanged:IsA("RemoteEvent") then
		stateChanged.OnClientEvent:Connect(function(snapshot)
			Atoms.applySnapshot(snapshot)
		end)
	end

	local notify = folder:FindFirstChild("Notify")
	if notify and notify:IsA("RemoteEvent") then
		notify.OnClientEvent:Connect(function(message: string)
			Bridge.notify({ Title = message, Glyph = "star", Accent = "Cyan" })
		end)
	end

	local codeResult = folder:FindFirstChild("CodeResult")
	if codeResult and codeResult:IsA("RemoteEvent") then
		codeResult.OnClientEvent:Connect(function(success: boolean, message: string)
			Bridge.notify({
				Title = if success then "Code Redeemed!" else "Code Rejected",
				Body = message,
				Glyph = if success then "star" else "cross",
				Accent = if success then "Green" else "Red",
			})
		end)
	end

	local monetizationResult = folder:FindFirstChild("MonetizationResult")
	if monetizationResult and monetizationResult:IsA("RemoteEvent") then
		monetizationResult.OnClientEvent:Connect(function(success: boolean, message: string)
			Bridge.notify({
				Title = if success then "Purchase Complete!" else "Purchase Failed",
				Body = message,
				Glyph = "robux",
				Accent = if success then "Green" else "Red",
			})
		end)
	end

	--[[
		The hatch result, and the thing that ends the egg shake. The server picks the
		pet; this only reports which one, so a client cannot roll its own reveal.

		A rejected roll clears the overlay rather than revealing nothing, so the
		player is not left staring at an egg that will never open.
	]]
	local petResult = folder:FindFirstChild("PetResult")
	if petResult and petResult:IsA("RemoteEvent") then
		petResult.OnClientEvent:Connect(function(success: boolean, message: string, petIds: any)
			--[[
				A LIST now, because a hatch can open three or five at once. A single id is still accepted so
				an older server -- or any other caller of `PetResult` -- keeps working.
			]]
			local ids = if typeof(petIds) == "table"
				then petIds
				elseif typeof(petIds) == "string" then { petIds }
				else nil
			local petId = if ids then ids[1] else nil
			local roll = Atoms.eggRoll()
			if roll ~= nil then
				if success and petId then
					--[[
						Held briefly so the shake has a beat before the burst. Without
						it a fast server makes the whole animation a single frame.
					]]
					task.delay(1.1, function()
						local current = Atoms.eggRoll()
						if current ~= nil and current.Phase == "shaking" then
							Atoms.eggRoll({
								EggId = current.EggId,
								Phase = "revealed",
								PetId = petId,
								PetIds = ids,
							})
						end
					end)
				else
					Atoms.eggRoll(nil)
				end
			end

			--[[
				One toast, titled "Pets". A successful hatch is skipped because the
				reveal overlay already says what happened; everything else -- equips,
				failures, slot purchases -- gets exactly one line here. The server no
				longer sends a second copy on `Notify`.
			]]
			local hatched = success and petId ~= nil
			if not hatched then
				Bridge.notify({
					Title = "Pets",
					Body = message,
					Glyph = "paw",
					Accent = if success then "Purple" else "Red",
				})
			end
		end)
	end

	-- Server-driven window opens, fired by the world proximity prompts.
	--[[
		The egg podium. The prompt is server-side, so the window it opens has to
		arrive as a message rather than a click: the client never decides that a
		player is standing at a podium.
	]]
	--[[
		The wheel result. The server has already picked and already granted; this only drives the
		animation, which is why it carries an index rather than a reward.
	]]
	local spinResult = folder:FindFirstChild("SpinResult")
	if spinResult and spinResult:IsA("RemoteEvent") then
		spinResult.OnClientEvent:Connect(function(segmentId: string, index: number, label: string)
			Atoms.spinRoll({
				Phase = "spinning",
				SegmentId = segmentId,
				Index = index,
				Label = label,
			})
			--[[
				Revealed on a timer rather than on an animation callback, so a dropped frame or a
				closed window cannot leave the wheel spinning forever with the prize unshown.
			]]
			task.delay(RewardsConfig.Spin.AnimationSeconds, function()
				local current = Atoms.spinRoll()
				if current ~= nil and current.Index == index and current.Phase == "spinning" then
					Atoms.spinRoll({
						Phase = "revealed",
						SegmentId = segmentId,
						Index = index,
						Label = label,
					})
					--[[
						And clear it again once the banner has had its moment. Nothing else clears it now
						that the COLLECT button is gone, and a roll left in place blocks the next spin --
						`spinWheel` refuses while one is live.
					]]
					task.delay(RewardsConfig.Spin.RevealSeconds, function()
						local shown = Atoms.spinRoll()
						if shown ~= nil and shown.Index == index and shown.Phase == "revealed" then
							Atoms.spinRoll(nil)
						end
					end)
				end
			end)
		end)
	end

	local openEggSummon = folder:FindFirstChild("OpenEggSummon")
	if openEggSummon and openEggSummon:IsA("RemoteEvent") then
		openEggSummon.OnClientEvent:Connect(function(eggId: string)
			Atoms.eggSummon(eggId)
		end)
	end

	--[[
		Server-wide news. Held for a fixed spell then cleared: a banner that waits
		for a click would stack up behind a player who is not looking at the screen.
	]]
	local announce = folder:FindFirstChild("Announce")
	if announce and announce:IsA("RemoteEvent") then
		announce.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			announceToken += 1
			local token = announceToken
			Atoms.announce(payload)
			task.delay(6, function()
				-- Only clear if nothing newer arrived meanwhile.
				if announceToken == token then
					Atoms.announce(nil)
				end
			end)
		end)
	end

	for remoteName, screenId in pairs({
		OpenMagnetShop = "magnetshop",
		OpenAreaShop = "areas",
		OpenExclusiveShop = "shop",
		OpenPetShop = "pets",
		OpenPitShop = "pitshop",
	}) do
		local remote = folder:FindFirstChild(remoteName)
		if remote and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(function()
				Atoms.screen(screenId)
			end)
		end
	end

	-- Initial snapshot, retried: a rejected data load kicks the player, so a
	-- failure here is a genuine "no session" and must not render defaults.
	local request = folder:FindFirstChild("RequestInitialState")
	if request and request:IsA("RemoteFunction") then
		for attempt = 1, 5 do
			local ok, snapshot = pcall(function()
				return request:InvokeServer()
			end)
			if ok and type(snapshot) == "table" then
				Atoms.applySnapshot(snapshot)
				break
			end
			if attempt < 5 then
				task.wait(attempt * 0.5)
			else
				warn("[ScrapyardUI] initial state unavailable after 5 attempts")
			end
		end
	end

	return Atoms.loaded()
end

function Bridge.localPlayer(): Player
	return Players.LocalPlayer
end

return Bridge
