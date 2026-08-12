--!nonstrict
--[[
	InboxScreen.luau

	The mailbox, opened from the top-right INBOX icon.

	Everything an admin hands out arrives here as a message the player claims, so a gift carries the name
	of the staff member who sent it and a verified tick that only the server can set. Unclaimed messages
	sort to the top -- the list is a to-do list first and a history second.

	Rewards are rendered from the shared `{ Money?, Gears?, Items?, Spins? }` shape, the same one codes,
	products and the daily calendar use, so a message can pay anything those can without this file
	learning a new format.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Format = require(UI.Format)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)

local InboxConfig = require(ReplicatedStorage.Shared.Config.InboxConfig)
local ItemIconConfig = require(ReplicatedStorage.Shared.Config.ItemIconConfig)

local e = React.createElement

local CLAIM_WIDTH = 116

--[[
	One reward as a short human string.

	Deliberately text rather than icons: a message can carry four kinds of reward at once and four icon
	chips in a card this size becomes a puzzle. `Format.money` for cash so it matches the HUD.
]]
local function rewardSummary(rewards): string
	if rewards == nil then
		return ""
	end
	local parts = {}
	if typeof(rewards.Money) == "number" and rewards.Money > 0 then
		table.insert(parts, Format.money(rewards.Money))
	end
	if typeof(rewards.Gears) == "number" and rewards.Gears > 0 then
		table.insert(parts, `{rewards.Gears} gears`)
	end
	if typeof(rewards.Spins) == "number" and rewards.Spins > 0 then
		table.insert(parts, `{rewards.Spins} spins`)
	end
	if typeof(rewards.Items) == "table" then
		for itemId, count in rewards.Items do
			local icon = ItemIconConfig[itemId]
			local label = if icon ~= nil and icon.Label then icon.Label else itemId
			table.insert(parts, `{count}x {label}`)
		end
	end
	return table.concat(parts, "   ")
end

--- "3m ago", "2h ago", "4d ago". Relative, because the absolute time of a gift is never the question.
local function relativeTime(sentAt: number?): string
	if typeof(sentAt) ~= "number" or sentAt <= 0 then
		return ""
	end
	local seconds = math.max(0, os.time() - sentAt)
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return `{math.floor(seconds / 60)}m ago`
	elseif seconds < 86400 then
		return `{math.floor(seconds / 3600)}h ago`
	end
	return `{math.floor(seconds / 86400)}d ago`
end

local function MessageCard(props)
	local kind = InboxConfig.kind(props.message.Kind)
	local claimed = props.message.Claimed == true
	local rewards = rewardSummary(props.message.Rewards)
	local hasRewards = #rewards > 0

	return e(P.Panel, {
		key = props.key,
		size = UDim2.fromScale(1, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		color = Theme.Color.Card,
		--- Claimed mail recedes: same card, dimmer, so the unread ones read first.
		gradient = if claimed then Theme.Gradient.PanelDeep else Theme.Gradient.Card,
		strokeThickness = Theme.Stroke.Card,
		studs = false,
		children = {
			P.padding({ x = 14, y = 12 }, "Inset"),
			e(P.Group, {
				key = "Stack",
				size = UDim2.fromScale(1, 0),
				automaticSize = Enum.AutomaticSize.Y,
				layout = P.list({ direction = Enum.FillDirection.Vertical, padding = 8 }),
				children = {
					e(P.Group, {
						key = "Header",
						size = UDim2.new(1, 0, 0, 32),
						layoutOrder = 1,
						children = P.compact(
							e(Icon, {
								key = "Mark",
								glyph = kind.Glyph,
								gradient = Theme.Gradient[kind.Accent] or Theme.Gradient.Cyan,
								size = UDim2.fromOffset(32, 32),
								radius = Theme.Radius.Small,
								zIndex = 3,
							}),
							e(P.Label, {
								key = "Title",
								text = props.message.Title,
								textSize = Theme.TextSize.Body,
								align = Enum.TextXAlignment.Left,
								size = UDim2.new(1, -(42 + 110), 1, 0),
								position = UDim2.fromOffset(42, 0),
								truncate = Enum.TextTruncate.AtEnd,
								zIndex = 3,
							}),
							e(P.Label, {
								key = "When",
								text = relativeTime(props.message.SentAt),
								textSize = Theme.TextSize.Micro,
								color = Theme.Color.GrayDark,
								align = Enum.TextXAlignment.Right,
								size = UDim2.fromOffset(104, 32),
								position = UDim2.fromScale(1, 0),
								anchorPoint = Vector2.new(1, 0),
								zIndex = 3,
							})
						),
					}),
					--[[
						THE SENDER LINE, and the verified tick that makes it worth showing.

						Only the server writes `Kind`, so a message claiming to be from staff is from staff.
						That is the whole reason the badge exists rather than just the name.
					]]
					e(P.Group, {
						key = "From",
						size = UDim2.new(1, 0, 0, 20),
						layoutOrder = 2,
						children = P.compact(
							if kind.Verified
								then e(Indicators.Badge, {
									key = "Verified",
									text = kind.Label,
									gradient = Theme.Gradient.Cyan,
									textSize = Theme.TextSize.Micro,
									size = UDim2.fromOffset(62, 18),
									zIndex = 3,
								})
								else nil,
							e(P.Label, {
								key = "Name",
								text = if #props.message.FromName > 0
									then `from {props.message.FromName}`
									else "from the game",
								textSize = Theme.TextSize.Small,
								color = Theme.Color.Gray,
								align = Enum.TextXAlignment.Left,
								size = UDim2.new(1, -74, 1, 0),
								position = UDim2.fromOffset(if kind.Verified then 70 else 0, 0),
								truncate = Enum.TextTruncate.AtEnd,
								zIndex = 3,
							})
						),
					}),
					e(P.Label, {
						key = "Body",
						text = props.message.Body,
						textSize = Theme.TextSize.Small,
						color = Theme.Color.Gray,
						align = Enum.TextXAlignment.Left,
						vAlign = Enum.TextYAlignment.Top,
						wrapped = true,
						size = UDim2.fromScale(1, 0),
						automaticSize = Enum.AutomaticSize.Y,
						layoutOrder = 3,
						zIndex = 3,
					}),
					--- The reward row only exists when there is something to claim.
					if hasRewards
						then e(P.Group, {
							key = "Rewards",
							size = UDim2.new(1, 0, 0, 40),
							layoutOrder = 4,
							children = P.compact(
								e(P.Label, {
									key = "Summary",
									text = rewards,
									textSize = Theme.TextSize.Small,
									font = Theme.Font.Bold,
									color = Theme.Color.Gold,
									align = Enum.TextXAlignment.Left,
									vAlign = Enum.TextYAlignment.Center,
									size = UDim2.new(1, -(CLAIM_WIDTH + 10), 1, 0),
									truncate = Enum.TextTruncate.AtEnd,
									zIndex = 3,
								}),
								if claimed
									then e(Indicators.Badge, {
										key = "Done",
										text = "CLAIMED",
										gradient = Theme.Gradient.Gray,
										textSize = Theme.TextSize.Micro,
										size = UDim2.fromOffset(84, 24),
										position = UDim2.fromScale(1, 0.5),
										anchorPoint = Vector2.new(1, 0.5),
										zIndex = 4,
									})
									else e(Buttons.Button, {
										key = "Claim",
										text = "CLAIM",
										variant = "Purchase",
										textSize = Theme.TextSize.Small,
										size = UDim2.fromOffset(CLAIM_WIDTH, 34),
										position = UDim2.fromScale(1, 0.5),
										anchorPoint = Vector2.new(1, 0.5),
										onClick = props.onClaim,
										zIndex = 4,
									})
							),
						})
						else nil,
				},
			}),
		},
	})
end

local function InboxScreen(props)
	local actions = props.actions
	local state = props.state
	local messages = state.inbox or {}

	--[[
		Unclaimed first, then newest first inside each group.

		Sorted here rather than on the server: the server keeps the mailbox in arrival order, which is the
		order that makes sense in a save, and presentation order is a screen's business. A copy, because
		sorting the state table in place would mutate the atom behind React's back.
	]]
	local ordered = table.clone(messages)
	table.sort(ordered, function(left, right)
		local leftClaimed = left.Claimed == true
		local rightClaimed = right.Claimed == true
		if leftClaimed ~= rightClaimed then
			return rightClaimed
		end
		return (left.SentAt or 0) > (right.SentAt or 0)
	end)

	local cards = {}
	for index, message in ipairs(ordered) do
		cards[#cards + 1] = e(MessageCard, {
			key = message.Id or `Message{index}`,
			message = message,
			layoutOrder = index,
			onClaim = function()
				actions.claimInbox(message.Id)
			end,
		})
	end

	if #cards == 0 then
		cards[1] = e(P.Label, {
			key = "Empty",
			text = "No mail yet.\nGifts and staff messages arrive here.",
			textSize = Theme.TextSize.Body,
			color = Theme.Color.GrayDark,
			wrapped = true,
			size = UDim2.fromScale(1, 1),
			zIndex = 3,
		})
	end

	local unclaimed = InboxConfig.unclaimedCount(messages)

	return e(Overlays.Modal, {
		key = props.key or "InboxScreen",
		title = if unclaimed > 0 then `Inbox  ({unclaimed})` else "Inbox",
		glyph = "crate",
		headerColor = Theme.Gradient.Purple,
		width = 720,
		contentHeight = 540,
		onClose = actions.closeScreen,
		children = P.compact(
			e(P.Scroller, {
				key = "Messages",
				size = UDim2.new(1, 0, 1, if unclaimed > 1 then -52 else 0),
				padding = { right = 10, bottom = 6 },
				layout = P.list({ direction = Enum.FillDirection.Vertical, padding = 10 }),
				children = cards,
			}),
			--- Only worth the space when there is more than one thing to sweep up.
			if unclaimed > 1
				then e(Buttons.Button, {
					key = "ClaimAll",
					text = `CLAIM ALL ({unclaimed})`,
					variant = "Purchase",
					textSize = Theme.TextSize.Body,
					size = UDim2.new(1, 0, 0, 42),
					position = UDim2.fromScale(0, 1),
					anchorPoint = Vector2.new(0, 1),
					onClick = actions.claimAllInbox,
					zIndex = 4,
				})
				else nil
		),
	})
end

return InboxScreen
