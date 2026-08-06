# Content Configuration

## Audio

Edit `src/shared/Config/AudioConfig.luau`. Each entry contains an `AssetId`, volume, and playback speed. Paste only the numeric portion of a Roblox audio asset ID. `AudioController` applies the configuration to the authored sounds under `SoundService/ScrapyardAudio`.

The configured volume is the maximum/base level. Each player's saved SFX and Music sliders multiply these values from 0% to 100%.

## Item Icons

Edit `src/shared/Config/ItemIconConfig.luau`. Every magnet, consumable, and currency reward has one centralized `AssetId`, fallback `Glyph`, and accent `Color`. Paste only the numeric portion of a Roblox image asset ID. Leaving `AssetId` empty keeps the built-in glyph, so unfinished icon art never produces a blank card.

The same entry drives inventory cards, the inventory detail preview, and code-reward reveals. Add a matching entry whenever a new item ID is introduced.

## Magnet Shop

Edit `AdvancedMagnet.ShopPrice` in `src/shared/Config/InventoryConfig.luau` to rebalance its Scrap Cash price. The authored NPC booth is `Workspace/SharedHub/MagnetShop`; its `ShopPrompt` opens the authored `StarterGui` shop modal. Clients submit only `BuyMagnet` plus the magnet ID. The server resolves price, funds, ownership, deduction, and duplicate rejection.

Current Creator Store choices:

- Music: `9045803411`, **High Five Happy (c)** by APMOfficial.
- Collection: `93529351909119`, **retro coin pickup sound effect powerup**.
- Sell: `17806435952`, **Audio/Metal_Heavy_2 (1)**.
- Confirmation/code/UI feedback: `120813384760164`, **CGC - Recover Hitpoint**, described by its creator as royalty-free.

Always playtest volume and verify each asset remains usable by the destination experience before publishing. Replacing an ID in `AudioConfig` is sufficient; do not scatter IDs through controllers or Studio scripts.

## Premium Shop

Marketplace IDs, preview prices, product rewards, pass descriptions, card order, and colors are centralized in `src/shared/Config/MonetizationConfig.luau`. Follow `docs/MONETIZATION_SETUP.md` when creating the corresponding passes and developer products.

## Redemption Codes

Edit `src/server/Config/CodeConfig.luau`. This file is server-only and is not replicated to players.

Each normalized uppercase code supports:

- `Id`: permanent internal redemption identity. Never reuse an old ID for different rewards.
- `Enabled`: immediate manual kill switch.
- `StudioOnly`: prevents redemption in published servers.
- `StartsAt`: Unix timestamp; `0` means immediately available.
- `ExpiresAt`: Unix timestamp; `0` means no automatic expiry.
- `Rewards`: server-owned magnets, item quantities, Money, and Gears.

Players can redeem each `Id` once. Changing the visible code text while retaining the same `Id` does not allow a second redemption. To retire a code, set `Enabled = false`; expired definitions may remain for audit history. Rewards are bounded again at the player mutation boundary.

`STUDIOKIT` is the source-controlled Studio-only QA code. It unlocks Advanced Magnet and grants two of each potion. It cannot be redeemed in a published server. The currently authored Studio place may retain a local `BETA` QA alias; published definitions should be reconciled with the source file before release.
