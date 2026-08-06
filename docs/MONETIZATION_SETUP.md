# Premium Shop Setup

## Creator Dashboard

Create four passes and six developer products for the experience, then paste their numeric IDs into `src/shared/Config/MonetizationConfig.luau`.

Permanent passes:

| Config ID | Benefit | Suggested starting price |
| --- | --- | ---: |
| `DoubleCash` | 2x all scrap sale value | 299 Robux |
| `StoragePlus` | 50% more storage | 199 Robux |
| `FastCollector` | 2x collection speed | 249 Robux |
| `QuantumMagnet` | Exclusive 25-strength, 32-range magnet | 399 Robux |

Repeatable developer products:

| Config ID | Delivery | Suggested starting price |
| --- | --- | ---: |
| `CashSmall` | $25,000 | 49 Robux |
| `CashMedium` | $150,000 | 149 Robux |
| `CashLarge` | $750,000 | 399 Robux |
| `BoosterPair` | 2 of each potion | 79 Robux |
| `BoosterBundle` | 6 of each potion | 199 Robux |
| `MegaBundle` | $100,000 and 10 of each potion | 299 Robux |

All IDs intentionally default to `0`; published servers refuse to open an unconfigured prompt. Studio converts zero-ID buttons into admin-only test grants. `DisplayPrice` provides that Studio preview only. Once IDs are configured, the client requests Roblox's current price for display and Roblox's purchase prompt remains authoritative.

## Security Contract

- Clients only request a Roblox purchase prompt and never submit grant quantities.
- Pass benefits are reconciled with `UserOwnsGamePassAsync` when a player joins and after a completed prompt.
- Developer products are delivered only through `MarketplaceService.ProcessReceipt`.
- Receipt purchase IDs are persisted before `PurchaseGranted` is returned. Failed saves return `NotProcessedYet` so Roblox can retry safely.
- Receipt IDs and entitlements are schema-validated. Premium ownership survives prestige.
- Keep exactly one `ProcessReceipt` callback in the experience; add future products to this catalog instead of creating another callback.

Suggested prices are initial hypotheses, not guarantees. Review conversion, retention, and progression pacing before changing them. Avoid countdowns or false scarcity unless an offer has a real, enforced expiry.
