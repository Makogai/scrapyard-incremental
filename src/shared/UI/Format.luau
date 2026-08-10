--!strict
--[[
	Format.luau
	Number, currency and time formatting for HUD-sized labels.

	Incremental games throw absurd numbers at the UI, so everything gets
	abbreviated to at most four visible characters plus a suffix.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

--- 1234567 -> "1.2M"
function Format.short(value: number): string
	if value ~= value or value == math.huge then
		return "∞"
	end

	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)

	if n < 1000 then
		-- keep whole numbers whole; only show a decimal when it matters
		if n % 1 == 0 then
			return sign .. string.format("%d", n)
		end
		return sign .. string.format("%.1f", n)
	end

	local tier = math.min(math.floor(math.log(n, 1000)), #SUFFIXES - 1)
	local scaled = n / (1000 ^ tier)

	local text: string
	if scaled >= 100 then
		text = string.format("%.0f", scaled)
	elseif scaled >= 10 then
		text = string.format("%.1f", scaled)
	else
		text = string.format("%.2f", scaled)
	end

	-- trim a trailing ".0" / ".00" so "5.00M" reads as "5M"
	text = string.gsub(string.gsub(text, "%.?0+$", ""), "%.$", "")

	return sign .. text .. SUFFIXES[tier + 1]
end

--- 1234567 -> "1,234,567"
function Format.comma(value: number): string
	local sign = if value < 0 then "-" else ""
	local whole = string.format("%d", math.floor(math.abs(value) + 0.5))

	local grouped = whole
	while true do
		local replaced: number
		grouped, replaced = string.gsub(grouped, "^(%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end

	return sign .. grouped
end

--- 337800000 -> "$337.8M"
function Format.money(value: number): string
	return "$" .. Format.short(value)
end

--- Exact cash, used in confirmation modals where the player is spending.
function Format.moneyExact(value: number): string
	return "$" .. Format.comma(value)
end

--- 199 -> "199" (paired with the Robux glyph, never a raw "R$" string)
function Format.robux(value: number): string
	return Format.comma(value)
end

--- 522 -> "08:42", 4231 -> "1:10:31"
function Format.timer(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = total % 60

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

--- 900 -> "15 Minutes"
function Format.duration(seconds: number): string
	if seconds >= 3600 then
		local hours = seconds / 3600
		local text = if hours % 1 == 0
			then string.format("%d", hours)
			else string.format("%.1f", hours)
		return text .. (if hours == 1 then " Hour" else " Hours")
	end

	local minutes = math.floor(seconds / 60)
	if minutes >= 1 then
		return minutes .. (if minutes == 1 then " Minute" else " Minutes")
	end

	return math.floor(seconds) .. " Seconds"
end

--- 1.5 -> "1.5x"
function Format.multiplier(value: number): string
	if value % 1 == 0 then
		return string.format("%dx", value)
	end
	return string.format("%.1fx", value)
end

--- 0.12 -> "+12%"
--[[
	A drop chance, as a plain percentage. Separate from `percent` because that one
	is for deltas and prefixes a "+", and because a 0.20% drop needs two decimals
	where a 55% one would look absurd with them.
]]
function Format.chance(value: number): string
	local pct = value * 100
	if pct >= 10 then
		return string.format("%d%%", pct + 0.5 - (pct + 0.5) % 1)
	elseif pct >= 1 then
		return string.format("%.1f%%", pct)
	end
	return string.format("%.2f%%", pct)
end

function Format.percent(value: number, signed: boolean?): string
	local pct = value * 100
	local text = if pct % 1 == 0 then string.format("%d", pct) else string.format("%.1f", pct)
	if signed ~= false and pct > 0 then
		return "+" .. text .. "%"
	end
	return text .. "%"
end

--- 24, 154 -> "24 / 154"
function Format.fraction(current: number, total: number): string
	return Format.comma(current) .. " / " .. Format.comma(total)
end

--- 20 -> "20 studs"
function Format.studs(value: number): string
	local text = if value % 1 == 0 then string.format("%d", value) else string.format("%.1f", value)
	return text .. " studs"
end

return Format
