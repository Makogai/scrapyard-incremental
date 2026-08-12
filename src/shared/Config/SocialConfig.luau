--!strict
--[[
	SocialConfig.luau
	Rewards for liking the game, joining the community, and bringing friends in.

	THREE THINGS THAT CANNOT BE VERIFIED THE SAME WAY, and the honesty of each reward is set by what the
	platform actually lets a server check:

		Like        Roblox exposes no API for "has this player liked this game". Self-reported, claimed
		            once, and priced accordingly -- it is a thank-you, not a wage.
		Community   Same: group membership CAN be checked, so this one is verified for real when a group
		            id is configured, and falls back to self-reported when it is not.
		Invite      Counted from `Players` -- a friend already in the server is a friend who joined.
		            `FriendBoostCount` is the live count and pays a per-friend reward, once per friend.

	Rewards use the shared `{ Money?, Gears?, Items?, Spins? }` shape, so `GrantRewards` pays them out.
	None of them pay GEARS: gears are rebirth currency and nothing but a rebirth grants them.
]]

local SocialConfig = {}

--[[
	The group to check for the community reward. 0 means "not configured yet", which makes the reward
	self-reported rather than blocking it -- the button works the day it ships, and tightens the moment a
	real group id is filled in.
]]
SocialConfig.GroupId = 0

--- Where the group and social links point. Shown to the player; never used to verify anything.
SocialConfig.GroupUrl = "https://www.roblox.com/groups/0"

SocialConfig.Rewards = table.freeze({
	Like = table.freeze({
		Id = "Like",
		Label = "LIKE THE GAME",
		Detail = "Give us a thumbs up",
		Glyph = "star",
		Accent = "Gold",
		--- Verified? No. See the note at the top.
		RequiresGroup = false,
		Rewards = table.freeze({ Money = 25_000, Spins = 1 }),
	}),
	Community = table.freeze({
		Id = "Community",
		Label = "JOIN THE GROUP",
		Detail = "Codes, sneak peeks and events",
		Glyph = "friends",
		Accent = "Cyan",
		--- Checked against `SocialConfig.GroupId` when one is configured.
		RequiresGroup = true,
		Rewards = table.freeze({ Money = 50_000, Items = table.freeze({ LuckPotion = 1 }) }),
	}),
})

SocialConfig.RewardOrder = table.freeze({ "Like", "Community" })

--[[
	The invite ladder: bring this many friends into the same server, claim once each.

	Rungs rather than a flat per-friend payout, because the interesting number is the SECOND friend --
	one friend happens by accident, two is a deliberate invite.
]]
SocialConfig.Invite = table.freeze({
	Label = "PLAY WITH FRIENDS",
	Detail = "Rewards for every friend in the server",
	Glyph = "friends",
	Accent = "Green",
	Milestones = table.freeze({
		table.freeze({ Friends = 1, Rewards = table.freeze({ Money = 30_000 }) }),
		table.freeze({
			Friends = 2,
			Rewards = table.freeze({ Money = 90_000, Items = table.freeze({ CashPotion = 1 }) }),
		}),
		table.freeze({ Friends = 4, Rewards = table.freeze({ Money = 250_000, Spins = 2 }) }),
		table.freeze({
			Friends = 6,
			Rewards = table.freeze({ Money = 600_000, Items = table.freeze({ GodPotion = 1 }) }),
		}),
	}),
})

--[[
	Which invite milestones a player can claim right now.

	Takes the live friend count and the set already claimed, and returns milestone INDICES. Pure, so the
	button and the server agree on what is claimable without asking each other.
]]
function SocialConfig.claimableInvites(friendCount: number, claimed: { [string]: any }?): { number }
	local ready = {}
	for index, milestone in SocialConfig.Invite.Milestones do
		local alreadyClaimed = claimed ~= nil and claimed[`Invite{index}`] == true
		if not alreadyClaimed and friendCount >= milestone.Friends then
			table.insert(ready, index)
		end
	end
	return ready
end

--- Whether a one-off social reward is still outstanding.
function SocialConfig.canClaim(rewardId: string, claimed: { [string]: any }?): boolean
	if SocialConfig.Rewards[rewardId] == nil then
		return false
	end
	return claimed == nil or claimed[rewardId] ~= true
end

return table.freeze(SocialConfig)
