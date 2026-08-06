--!strict

export type RateLimiter = {
	Allow: (self: RateLimiter, key: string, now: number?) -> boolean,
	Remove: (self: RateLimiter, key: string) -> (),
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(limit: number, windowSeconds: number): RateLimiter
	assert(limit > 0 and windowSeconds > 0, "Rate limiter values must be positive")
	local self =
		setmetatable({ _limit = limit, _window = windowSeconds, _buckets = {} }, RateLimiter)
	return (self :: any) :: RateLimiter
end

function RateLimiter:Allow(key: string, now: number?): boolean
	local timestamp = now or os.clock()
	local bucket = self._buckets[key]
	if bucket == nil or timestamp - bucket.startedAt >= self._window then
		self._buckets[key] = { startedAt = timestamp, count = 1 }
		return true
	end
	if bucket.count >= self._limit then
		return false
	end
	bucket.count += 1
	return true
end

function RateLimiter:Remove(key: string)
	self._buckets[key] = nil
end

return RateLimiter
