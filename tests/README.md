# Scrapyard Incremental Tests

Run pure foundation tests with `lune run tests/run.luau`. These fast tests cover formula boundaries and the shared rate limiter without mocking Roblox engine behavior. Lint them separately with `selene --config tests/selene.toml tests`; the test profile permits Lune's string-path `require`, while production source uses the Roblox profile. Engine-integrated TestEZ specifications will be added when player data and gameplay services arrive.
