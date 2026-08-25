--[[
	SpinScreen.luau

	THE DAILY SPIN WHEEL, as a full-screen takeover rather than a window.

	Not a modal. A modal is a thing you read; this is a thing you watch. So the world blurs, the wheel
	takes the middle of the screen, and there is no header, no panel and no chrome competing with it --
	the same reasoning `EggRollOverlay` uses for the hatch.

	THE WHEEL IS DECORATION OVER A DECIDED RESULT. The server picked the segment, granted the reward,
	and sent back an index; this turns the wheel so that segment stops under the pointer. It never picks
	anything. That ordering is the entire security model of a prize wheel -- a client that spins and then
	reports where it landed lands on the jackpot every time.

	THREE STATES, and the transitions are what sell it:

		idle       drifting slowly on its own, so it reads as alive before you touch it
		spinning   six full turns into its landing angle, over three seconds
		revealed   stopped, with a `RewardToast` banner naming the prize

	There is no COLLECT button. The reward was granted the moment the server resolved the spin, so a
	button claiming to collect it would be a lie -- the banner announces, and the wheel is immediately
	ready to go again.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Hooks = require(UI.Hooks)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Overlays = require(UI.Components.Overlays)
local Wheel = require(UI.Components.Wheel)
local RewardToast = require(UI.Components.RewardToast)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local RobuxPrice = require(UI.Components.RobuxPrice)
local Icon = require(UI.Icon)

local e = React.createElement

--[[
	Whole turns before it settles, and how long that takes.

	Six turns over three seconds: the old version did one short spring and was over before the eye
	caught it. A whole number of turns on purpose -- the landing angle is then exactly the segment's own
	centre, where a fractional turn leaves the pointer sitting off the wedge it claims to have picked.
]]
local FULL_TURNS = 6
local SPIN_SPRING = { tension = 24, friction = 26 }

--- How fast it drifts while nobody has pressed anything.
local IDLE_DEGREES_PER_SECOND = 7

--- cos(45 degrees): the factor that turns a radius into an on-the-circle diagonal offset.
local DIAGONAL = math.sqrt(2) / 2

--- The spin-pack column.
local PACK_WIDTH = 210

--[[
	A buyable pack of spins.

	The card carries the label; the price hangs off its lower-right as a `RobuxPrice` corner tag, so the
	gold-on-ink treatment and the wiggle come from that component rather than being restated here. Only
	`best` gets the brighter gradient -- if both packs shouted, neither would.
]]
local function SpinPack(props)
	--- Locked when the grant could not be delivered: see the note on the price below.
	local locked = props.locked == true

	--[[
		A `TextButton` root through `usePressable`, the same path `StatusIcon` and `BoostTile` use.
		Roblox only routes hover to a Frame when nothing interactive covers it, so a card that wants
		hover has to be the button itself.
	]]
	local press = Motion.usePressable({
		disabled = locked,
		hoverScale = 1.04,
		pressScale = 0.98,
		onClick = function()
			props.onBuy(props.productId, "Product")
		end,
	})

	local rootProps = {
		key = props.key or "SpinPack",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 76),
		LayoutOrder = props.layoutOrder,
	}
	for event, handler in pairs(press.events) do
		rootProps[event] = handler
	end

	return e("TextButton", rootProps, {
		e("UIScale", { key = "Scale", Scale = press.scale }),
		e(P.Panel, {
			key = "Slab",
			size = UDim2.fromScale(1, 1),
			--[[
				The same green as the SPIN button below. These two and that button are the only things on
				this screen a player is meant to press, so they should read as the same class of object -- a
				navy card and a purple card beside a green button read as three unrelated systems.
			]]
			gradient = if locked then Theme.Gradient.Slot else Theme.Gradient.Green,
			radius = Theme.Radius.Card,
			strokeThickness = Theme.Stroke.Card,
			studs = false,
			children = {
				e(Icon, {
					key = "Glyph",
					glyph = "wheel",
					plain = true,
					size = UDim2.fromOffset(26, 26),
					position = UDim2.fromOffset(10, 7),
				}),
				e(P.Label, {
					key = "Label",
					text = props.label,
					textSize = Theme.TextSize.Body,
					color = Theme.Color.White,
					align = Enum.TextXAlignment.Left,
					position = UDim2.fromOffset(44, 8),
					size = UDim2.new(1, -52, 0, 26),
				}),
				--[[
					The price treatment lives in `RobuxPrice`, not here, so it matches every other price -- and
					AT THE CAP THE PRICE IS REPLACED BY THE REASON.

					`SpinsAvailable` is clamped to `MaximumStored`, so buying spins while already at the cap
					takes Robux and grants nothing: the schema trims the excess on the next save. A disabled
					card that says why is the difference between a hard limit and a refund request.
				]]
				if locked
					then e(P.Label, {
						key = "Capped",
						text = "SPIN STASH FULL",
						textSize = Theme.TextSize.Tiny,
						color = Theme.Color.GrayDark,
						align = Enum.TextXAlignment.Left,
						position = UDim2.new(0, 10, 1, -7),
						anchorPoint = Vector2.new(0, 1),
						size = UDim2.new(1, -20, 0, 18),
					})
					else e(RobuxPrice.Tag, {
						key = "Price",
						amount = props.robux,
						variant = "corner",
						position = UDim2.new(1, -8, 1, -4),
						anchorPoint = Vector2.new(1, 1),
						zIndex = 6,
					}),
			},
		}),
	})
end

local function SpinScreen(props)
	local state = props.state
	local actions = props.actions

	local segments = state.spinSegments or {}
	local spins = state.spinsAvailable or 0
	local roll = state.spinRoll
	local phase = if roll then roll.Phase else nil

	local spinning = phase == "spinning"
	local revealed = phase == "revealed"
	local active = spinning or revealed

	--[[
		The wheel is sized to the screen, not to a constant. A 520px wheel is right on desktop and taller
		than the whole canvas on a 750x361 landscape phone, so it takes whatever the shorter axis can
		spare after the button row and the banner.
	]]
	local viewport = Hooks.useViewport()
	local scale = Hooks.useScale()
	local available = math.min(viewport.X, viewport.Y) / math.max(scale, 0.01)
	local extent = math.clamp(math.floor(available - 190), 240, 560)

	--[[
		How much room the wheel takes BEYOND `extent`: the rim ring, its ink outline and the bolts.
		Mirrors `Components/Wheel`'s own `rimWidth`, which is the number those are drawn from.
	]]
	local rimAllowance = math.max(18, math.floor(extent * 0.055)) + 10

	local count = math.max(#segments, 1)
	local step = 360 / count

	--[[
		Where it has to stop.

		`Components/Wheel` lays segment i centred at `(i - 0.5) * step` clockwise from up, so bringing it
		under the pointer means turning back by exactly that, plus whole turns. Negative because a
		positive `Rotation` turns clockwise and the segment has to come round to the top.

		This is the one piece of maths the screen and the wheel component must agree on.
	]]
	--[[
		Each roll adds another six turns on top of wherever the wheel already sits.

		The first spin works because the spring starts at 0 and travels to
		`landing` (~−2160°). After that it is still sitting on that angle, so a
		second spin whose target is another ~−2160° only nudges a few degrees --
		which is the "it does not spin the second time" bug. Clearing the roll
		used to retarget 0 as well, so the wheel unwound backwards when the
		banner dropped, then the next click fought that rewind.

		`spinsRun` is how many times we have entered `spinning` this mount, and
		the spring is never sent back to 0. Idle drift only plays before the
		first roll; afterwards the wheel holds the last wedge until the next
		click, then takes six more turns from there.
	]]
	local settledIndex, setSettledIndex = React.useState(1)
	local spinsRun, setSpinsRun = React.useState(0)

	React.useEffect(function()
		if roll and type(roll.Index) == "number" then
			setSettledIndex(roll.Index)
		end
	end, { if roll then roll.Index else nil })

	React.useEffect(function()
		if spinning then
			setSpinsRun(function(n)
				return n + 1
			end)
		end
	end, { spinning })

	local targetIndex = if roll then roll.Index else settledIndex
	local landing = -((targetIndex - 0.5) * step) - spinsRun * FULL_TURNS * 360

	--[[
		Two rotation sources, and only one is live at a time: a slow idle drift, and the spring that
		throws it to its landing angle. Swapping between them rather than adding them means the landing
		angle is exact -- an idle offset still ticking underneath would leave the pointer a degree or two
		off whichever wedge won.
	]]
	local idle = Motion.useSpin(IDLE_DEGREES_PER_SECOND, not active and spinsRun == 0)
	local landed = Motion.useSpring(landing, SPIN_SPRING)
	local rotation = if active or spinsRun > 0 then landed else idle

	--[[
		The winner flash used to key off `revealed`, and `revealed` is a timer
		(`AnimationSeconds`) rather than the spring. The wedge lit up while the
		wheel was still turning toward it. Wait until the pointer is actually on
		that wedge -- a few degrees of the landing angle -- before flashing or
		showing the banner. The timer can still flip the phase; the light waits.
	]]
	local onWedge, setOnWedge = React.useState(false)

	React.useEffect(function()
		if spinning then
			setOnWedge(false)
		end
	end, { spinning })

	React.useEffect(function()
		if not revealed then
			return
		end
		local finished = false
		local function mark()
			if not finished then
				finished = true
				setOnWedge(true)
			end
		end
		local current = landed:getValue()
		if type(current) == "number" and math.abs(current - landing) <= 4 then
			mark()
			return
		end
		local disconnect = Motion.heartbeat:Connect(function()
			local value = landed:getValue()
			if type(value) == "number" and math.abs(value - landing) <= 4 then
				mark()
			end
		end)
		-- Overdamped springs creep the last degree forever; do not wait them out.
		local timeout = task.delay(2, mark)
		return function()
			disconnect:Disconnect()
			task.cancel(timeout)
		end
	end, { revealed, landing })

	--- The prize banner, built from the segment the server actually landed on.
	local won = nil
	if revealed and onWedge then
		for _, segment in ipairs(segments) do
			if segment.Id == roll.SegmentId then
				won = segment
				break
			end
		end
	end

	return e(P.Group, {
		key = props.key or "SpinScreen",
		size = UDim2.fromScale(1, 1),
		zIndex = Theme.Layer.Screen,
		children = P.compact(
			--[[
				Blurred, and clicking it closes -- but only while nothing is turning. Letting a stray click
				dismiss a spin in progress would throw away the animation for a reward already granted.
			]]
			e(Overlays.Backdrop, {
				key = "Backdrop",
				transparency = 0.35,
				blur = true,
				blurSize = 20,
				modal = true,
				zIndex = 1,
				onClick = if spinning then nil else actions.closeScreen,
			}),
			--[[
				ON THE RIM'S TOP-RIGHT, at 45 degrees.

				In a takeover there is no window frame for a corner button to belong to, so a close in the
				screen corner reads as unrelated to the thing it closes. Squaring the offsets -- centre plus
				half the extent in each axis -- put it diagonally off the rim, floating in empty space; the
				corner of a circle's bounding box is not on the circle.

				So it is placed along the 45-degree diagonal, at the rim's outer radius plus a clearance --
				close enough to belong to the wheel, far enough not to sit on top of a prize.
			]]
			e(Buttons.CloseButton, {
				key = "Close",
				extent = 46,
				position = UDim2.new(
					0.5,
					(extent / 2 + rimAllowance + 30) * DIAGONAL,
					0.5,
					-30 - (extent / 2 + rimAllowance + 30) * DIAGONAL
				),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 12,
				onClick = actions.closeScreen,
			}),
			e(Wheel.Wheel, {
				key = "Wheel",
				segments = segments,
				rotation = rotation,
				extent = extent,
				--- The pointer only kicks while it turns, and the winner only pulses once it has stopped.
				spinning = spinning,
				winner = if revealed and onWedge then targetIndex else nil,
				position = UDim2.new(0.5, 0, 0.5, -30),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 3,
			}),
			--[[
				The banner sits over the wheel's lower half rather than under the button row, so the prize
				lands where the eye already is once the wheel stops.
			]]
			if won
				then e(RewardToast.Banner, {
					key = "Won",
					title = won.Label,
					detail = "ADDED TO YOUR ACCOUNT",
					glyph = RewardToast.glyphFor(won),
					image = RewardToast.imageFor(won),
					accent = won.Accent,
					best = won.Best == true,
					width = math.min(460, extent + 60),
					position = UDim2.new(0.5, 0, 0.5, extent / 2 - 40),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 9,
				})
				else nil,
			--[[
				SUPPORTING PANEL, right of the wheel. The screen had a lot of empty space either side of a
				wheel floating alone; this puts the two things a player wants next to it -- more spins, and
				what the odds actually are.
			]]
			--[[
				RIGHT OF THE RIM, not right of `extent`.

				`extent` is the wedge disc; the rim, its ink outline and the bolts all live OUTSIDE that, so
				an offset measured from `extent / 2` put this column on top of the wheel. `PACK_WIDTH / 2`
				plus the rim's own thickness plus a gutter is the first position that clears it.
			]]
			e(P.Group, {
				key = "Packs",
				size = UDim2.fromOffset(PACK_WIDTH, 260),
				position = UDim2.new(
					0.5,
					extent / 2 + rimAllowance + PACK_WIDTH / 2 + 26,
					0.5,
					-30
				),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 7,
				layout = P.list({ padding = 12 }),
				children = {
					e(P.Label, {
						key = "Heading",
						text = "MORE SPINS",
						textSize = Theme.TextSize.Small,
						color = Theme.Color.Gray,
						size = UDim2.new(1, 0, 0, 22),
						layoutOrder = 1,
					}),
					e(SpinPack, {
						key = "PackOne",
						label = "+1 SPIN",
						productId = "SpinOne",
						robux = 59,
						locked = spins + 1 > RewardsConfig.Spin.MaximumStored,
						layoutOrder = 2,
						onBuy = actions.purchase,
					}),
					e(SpinPack, {
						key = "PackThree",
						label = "+3 SPINS",
						productId = "SpinThree",
						robux = 120,
						locked = spins + 3 > RewardsConfig.Spin.MaximumStored,
						best = true,
						layoutOrder = 3,
						onBuy = actions.purchase,
					}),
				},
			}),
			e(P.Group, {
				key = "Controls",
				size = UDim2.fromOffset(360, 86),
				position = UDim2.new(0.5, 0, 1, -96),
				anchorPoint = Vector2.new(0.5, 1),
				zIndex = 6,
				children = {
					e(Buttons.Button, {
						key = "SpinButton",
						text = if spinning then "SPINNING" else "SPIN",
						--- Just the count. "LEFT TODAY" was wrong: packs and rewards add spins beyond the daily one.
						subtext = if spinning
							then nil
							elseif spins == 1 then "1 SPIN"
							elseif spins > 1 then `{spins} SPINS`
							else "OUT OF SPINS",
						glyph = if spinning then nil else "wheel",
						variant = if spinning or spins <= 0 then "Neutral" else "Primary",
						disabled = spinning or spins <= 0,
						textSize = Theme.TextSize.Title,
						size = UDim2.fromOffset(340, 86),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
						onClick = actions.spinWheel,
					}),
				},
			})
		),
	})
end

return SpinScreen
