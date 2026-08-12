# Economy rebalance — proposal mapped onto the code

**Status: IMPLEMENTED, except the four items in "Not done" at the bottom.** Gates pass, 377 tests. Not
yet playtested — the numbers below are modelled, and a model is a hypothesis.

## Where it landed

Modelled against the game's real density and the on-disk config after the change:

| Milestone | Price | Time in that area | Cumulative | Target |
| --- | --- | --- | --- | --- |
| Workshop | $75,000 | 16.1 min | **16.1 min** | 12–18 ✅ |
| Vehicle Graveyard | $450,000 | 18.7 min | **34.7 min** | 30–40 ✅ |
| Rebirth 1 | $2,000,000 | 33.6 min | **68.3 min** | 55–70 ✅ |

Average scrap value per area: **$90 → $464 → $1,146**, against the design's intended $87 → $387 → $1,245.

**The single most useful thing I learned: income is travel-bound, not respawn-bound.** At Front Yard
density, pieces sit ~24 studs apart and a 9-stud magnet means the player walks between them — about
**52 pieces a minute**, and respawn at ~3.3s average is nowhere near the constraint. That is why the
proposal's price table works against our density unchanged, and why rolling density back would have made
the yard look emptier without slowing progression at all. That planned step was dropped on the evidence.

**Why:** the game is too fast, unbalanced and not fun. A rebirth currently lands in a couple of minutes,
so the whole arc — Front Yard, Workshop, Vehicle Graveyard, prestige — is over before any of it has time
to mean anything.

This maps a design that was written **without access to the code** onto what the code actually does. That
matters more than it sounds: three of the proposal's headline recommendations are already implemented, and
one of them argues from a number that is 50× off. Those are called out as they come up.

Every "current" figure below was read out of the config files, not remembered.

---

## 0. The five things to decide before any of it

Everything else is arithmetic. These are judgement calls, and they change what the rest costs.

| # | Decision | Why it blocks the rest |
| --- | --- | --- |
| 1 | **Rebase all scrap values ~15×?** | Front Yard scrap is currently $2–$18. The proposal wants $45–$120. Every price in the game — areas, upgrades, rebirth, eggs, magnets — is denominated against scrap value, so this either happens first or not at all |
| 2 | **Storage: weight or slots?** | Today storage is **weight**-based (`StoredWeight += scrap.Weight`, capacity in weight units). The proposal wants 1 slot per scrap regardless of rarity. This is a schema and HUD change, not a number |
| 3 | **Keep the exponential luck curve or move to linear?** | Ours is `weight × luck^exponent`; the proposal is `weight × (1 + luck × factor)`. Ours is far steeper at the top end. Section 4 shows both |
| 4 | **Do area unlocks reset on rebirth?** | They **already do**. The proposal wants that plus rising prices. Only the price scaling is new |
| 5 | **Is Quantum Magnet cash or Robux?** | It is a **premium (Robux)** item today. The proposal makes it a $3M cash purchase as the "delay your rebirth?" decision. Cannot be both |

---

## 1. Pacing target

| Milestone | Proposal | `plan/ECONOMY.md` says today | Reality |
| --- | --- | --- | --- |
| Workshop | 12–18 min | 4–8 min | far faster than either |
| Vehicle Graveyard | 30–40 min | 20–35 min | far faster |
| Rebirth 1 | 55–70 min | 30–50 min | ~2–3 min |
| Rebirth 2 | +70–90 min | — | — |
| Rebirth 3 | +90–120 min | — | — |
| Rebirth 4+ | +2h each | — | — |

The proposal's most important structural note, and I agree with it: **do not fix this by raising the
rebirth price alone.** That turns one three-minute loop into the same three-minute loop repeated twenty
times. The hour has to contain Workshop → better scrap → pets → Graveyard → much better scrap → a magnet
decision → rebirth. The pacing comes from the *stages*, and the rebirth price only sets where the arc
ends.

---

## 2. Scrap values — the big rebase

Rarity is rolled independently of scrap type **today** — that part of the proposal is already how
`weightedVariant` works, and no rework is needed. What changes is the numbers.

### Current (read from `ScrapConfig`)

| Scrap | Value | Weight | Str | Respawn | SpawnWeight |
| --- | --- | --- | --- | --- | --- |
| MetalCan | $3 | 1 | 1 | 2.5s | 30 |
| LooseBolt | $2 | 0.5 | 1 | 2s | 26 |
| SmallMetalPlate | $9 | 3 | 3 | 3s | 20 |
| RustyPipe | $7 | 2 | 2 | 3s | 22 |
| CrushedBucket | $13 | 4 | 4 | 3.5s | 16 |
| CopperWire | $18 | 3.5 | 5 | 4s | 12 |
| Tire | $20 | 6 | 6 | 5s | 10 |
| ToolBox | $42 | 10 | 9 | 4.5s | 24 |
| BrokenAppliance | $55 | 14 | 10 | 5s | 26 |
| BrakeDisc | $64 | 12 | 12 | 5.5s | 20 |
| Radiator | $105 | 20 | 15 | 6.5s | 16 |
| MotorCoil | $118 | 18 | 16 | 7s | 13 |
| EnginePart | $135 | 28 | 16 | 7s | 18 |
| ExhaustPipe | $205 | 35 | 21 | 7.5s | 22 |
| CarDoor | $240 | 42 | 24 | 8s | 9 |
| Axle | $360 | 58 | 29 | 9s | 16 |
| FuelTank | $520 | 74 | 35 | 10s | 11 |
| ScrapCar | $1,250 | 160 | 45 | 12s | 5 |

### Proposed

| Area | Scrap | New value | Current | Change |
| --- | --- | --- | --- | --- |
| Front Yard | MetalCan | $45 | $3 | ×15 |
| | LooseBolt | $55 | $2 | ×27.5 |
| | SmallMetalPlate | $70 | $9 | ×7.8 |
| | RustyPipe | $85 | $7 | ×12 |
| | CrushedBucket | $100 | $13 | ×7.7 |
| | CopperWire | $120 | $18 | ×6.7 |
| Workshop | Tire | $200 | $20 | ×10 |
| | BrokenAppliance | $240 | $55 | ×4.4 |
| | ToolBox | $290 | $42 | ×6.9 |
| | BrakeDisc | $350 | $64 | ×5.5 |
| | Radiator | $430 | $105 | ×4.1 |
| | MotorCoil | $610 | $118 | ×5.2 |
| Vehicle Graveyard | EnginePart | $700 | $135 | ×5.2 |
| | CarDoor | $850 | $240 | ×3.5 |
| | ExhaustPipe | $1,000 | $205 | ×4.9 |
| | Axle | $1,150 | $360 | ×3.2 |
| | FuelTank | $1,350 | $520 | ×2.6 |
| | ScrapCar | $1,750 | $1,250 | ×1.4 |

Target averages: **~$87 → ~$387 → ~$1,245** per scrap, so Workshop is ~4.5× Front Yard and Graveyard
~3.2× Workshop.

**Two things I would push back on.**

The multipliers are wildly uneven — ×27.5 on LooseBolt against ×1.4 on ScrapCar. That is not a rebase,
it is a **flattening**: the spread between the cheapest and dearest scrap goes from 625× to 39×. It makes
early scrap feel much better and late scrap feel much worse, and it means a Graveyard player picking up a
CarDoor is earning only 19× what a beginner earns from a MetalCan. Deliberate? It follows from wanting
equal spawn chances within an area, but it is a real design change hiding inside a price table.

Second: the proposal assigns each scrap to **one** area, but four scraps currently appear in **two**
(`Tire` in Front Yard + Workshop, `EnginePart` and `CarDoor` in Workshop + Graveyard). Either those
overlaps go — which removes the deliberate softening between areas — or those four need a value that
works in both.

---

## 3. Rarity multipliers

| Rarity | Current | Proposed |
| --- | --- | --- |
| Normal | ×1 | ×1 |
| Rare | ×2 | ×2 |
| Epic | **×5** | ×4 |
| Legendary | **×15** | ×8 |
| Nebula | **×75** | ×25 |

Ours is already steeper at the top. Combined with the rebase, a Nebula ScrapCar goes from
$1,250 × 75 = **$93,750** today to $1,750 × 25 = **$43,750** — less than half. Worth being deliberate
about: the jackpot gets smaller in absolute terms even as the base economy gets bigger.

---

## 4. Nebula rate and the luck curve

**This is where the proposal argues from a wrong number.** It says Nebula is 1% and should drop to
0.025%. It is **0.02% today** — weight 2 out of a 10,000 roll total — already *rarer* than the
recommendation. Everything in that section of the conversation about auto-sell farming producing 36
Nebulas an hour describes a game we do not have.

### Current spawn weights

| Rarity | Weight | Base rate | LuckExponent |
| --- | --- | --- | --- |
| Normal | 9,600 | 96% | 0 |
| Rare | 300 | 3% | 1 |
| Epic | 80 | 0.8% | 1.5 |
| Legendary | 18 | 0.18% | 2 |
| Nebula | 2 | **0.02%** | 2.6 |

### The two curves compared

Ours: `weight × max(1, luck) ^ exponent`. Proposal: `weight × (1 + luckBonus × factor)`, normalised.

| Luck | Ours (Nebula) | Odds | Proposal at +80% |
| --- | --- | --- | --- |
| 1.0 | 0.020% | 1 in 5,000 | — |
| 1.3 | 0.039% | 1 in 2,564 | — |
| 2.0 | 0.115% | 1 in 867 | — |
| 3.9 (Luck Potion ×3) | 0.587% | **1 in 170** | — |
| 10 | 4.49% | 1 in 22 | — |
| +80% bonus | — | — | ~0.063%, 1 in ~1,585 |

The real difference is **shape**, not the base rate. An exponential curve rewards stacking luck sources
super-linearly: our Luck Potion alone is worth ~15× on Nebula, and a potion plus Lucky Hour plus a God
Potion compounds into percentages. The proposal's linear curve cannot run away like that.

**My recommendation:** keep the base at 0.02% and keep exponents, but consider capping the effective luck
multiplier that feeds the exponent. Section 9 covers it. The uncapped exponential is the actual risk here,
not the base rate.

Also worth knowing before tuning either: **I increased roll volume ~5× this session.** Front Yard density
went 8 → 40 pieces and respawn timers dropped ~40% on the slow tiers. Rolls per minute is the axis all of
this turns on, so the current "too fast" feeling is partly that.

---

## 5. Upgrades

The proposal wants a uniform cap of 10 (+2 per rebirth) and `cost = base × growth^level`. **Neither
matches what is there**, and the formula difference is not cosmetic.

Ours is `base × (level+1)^costPower × growth^√level` — a polynomial times a *square-rooted* exponential,
which grows much more slowly at high levels than a plain exponential. Swapping to `base × growth^level`
makes late levels far more expensive than the current curve at the same numbers.

| Upgrade | Base $ | Growth | CostPower | Max lvl | +/rebirth | Proposed base $ | Proposed growth |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MagnetStrength | 75 | 1.10 | 1.55 | 12 | 6 | 250 | ×1.30 |
| MagnetRange | 100 | 1.11 | 1.70 | 8 | 4 | 350 | ×1.32 |
| StorageCapacity | 60 | 1.095 | 1.55 | 14 | 7 | 300 | ×1.30 |
| MovementSpeed | 250 | 1.12 | 1.90 | 6 | 3 | 500 | ×1.34 |
| ScrapValue | 200 | 1.115 | 1.72 | 12 | 6 | 750 | ×1.38 |
| CollectionSpeed | 120 | 1.105 | 1.65 | 10 | 5 | 450 | ×1.34 |
| ScrapFlow (= Spawn Rate) | 180 | 1.11 | 1.80 | 8 | 4 | 900 | ×1.40 |
| Rarity (= Luck) | 350 | 1.13 | 1.85 | 8 | 4 | 1,250 | ×1.42 |

The eight upgrades line up one-for-one, which is convenient. The caps do not: ours range 6–14 with 3–7 per
rebirth, deliberately uneven so MovementSpeed cannot run away while StorageCapacity can. Flattening to
10 + 2 removes that shaping — **check MovementSpeed especially**, since ours caps at 6 levels for a reason
and the proposal separately wants a soft cap at 26 walk speed.

Proposed total to max everything at level 10: **~$295,770**, deliberately more than the Graveyard unlock
so you cannot max out before the last area.

### Effects at level 10 (proposed)

| Upgrade | Start | Per level | At 10 | Ours today (base → per level) |
| --- | --- | --- | --- | --- |
| MagnetStrength | 1.00× | +12% | 2.20× | 4 → +1.35 |
| MagnetRange | 12 studs | +1.5 | 27 | 9 → +0.75, cap 42 |
| StorageCapacity | 25 | +5 | 75 | 20 → +6 |
| MovementSpeed | 16 | +0.5 | 21 | 16 → +0.07, cap 28 |
| ScrapValue | 1.00× | +6% | 1.60× | 1 → +0.085 |
| CollectionSpeed | 14/s | +1.4 | 28/s | 24 → +1.8 |
| Spawn Rate | 1.00× | +7% | 1.70× | 1 → +0.055, cap 0.18 |
| Rarity Luck | +0% | +8% | +80% | 1 → +0.12, cap 8 |

Note ours uses `EffectCurve`/`CurvePower` with diminishing returns and caps; the proposal is linear. Same
end points, different feel in the middle.

---

## 6. Areas and rebirth

| | Current | Proposed |
| --- | --- | --- |
| Workshop unlock | **$12,500** | $75,000 |
| Graveyard unlock | **$125,000** | $450,000 |
| Area price scaling | none | `base × 1.45^rebirths` |
| Areas reset on rebirth | **yes, already** | yes |
| Rebirth 1 cost | **$350,000** | $2,000,000 |
| Rebirth growth | **×2.25** | ×1.75 |
| Per rebirth | gears → value multiplier | +25% value, +5% luck, +2 upgrade cap |

Ours is `base × growth^prestigeCount`, same shape as the proposal, so only the two constants change.

**A note on the growth rate.** Ours is ×2.25, the proposal ×1.75 — *slower*. That is only correct
alongside the proposal's +25%-per-rebirth value bonus, because the two have to be compared: rebirth cost
must outrun the permanent income bonus or each rebirth gets faster instead of harder. ×1.75 against
+25% works. ×1.75 against our current gear-based multiplier may not — **this pair has to move together.**

> **RESOLVED (2026-08-12).** The gears→value multiplier described below is **deleted**. It made a rebirth
> pay twice (once through `ValuePerPrestige`, again through the gear curve), and at `^0.55` it was shaped for
> the single-digit gear counts a rebirth pays -- so every other gear source detonated it. Achievements paid
> out 5 to 1,000 gears; "Hold $1,000" alone was a permanent ×2.67 on all income. Gears are now rebirth
> currency with no passive effect, granted only by a rebirth, and `ValuePerPrestige` is the single payoff.
> See `GameMath.prestigeValueMultiplier`.

Our rebirth reward is a gears→value multiplier (`GearPower = 0.55`, cap ×1,000,000), which is a different
system from a flat +25% per rebirth. Replacing it is a real change, not a number tweak, and it interacts
with the upgrade cap: ours already grants +3 to +7 levels per prestige depending on the upgrade.

---

## 7. Playtime rewards

The proposal's principle is the right one: **these should boost progression, not perform it.** Total free
cash across two hours should sit below the Workshop unlock so the track can never buy an area on its own.

| Milestone | Current | Proposed |
| --- | --- | --- |
| 5 min | $1,000 | — |
| 10 min | $2,500 | — |
| 15 min | — | $2,500 + 5m Magnet Potion |
| 20 min | Cash Potion | — |
| 30 min | $8,000 | $5,000 + 5m Cash Potion |
| 45 min | 1 spin | 5m Luck + 5m Spawn Potion, no cash |
| 1 hr | Luck Potion | $10,000 + 10m Cash Potion + 1 egg |
| 1 hr 20 | **$30,000** | 10m Magnet Potion + 1 egg, no cash |
| 1 hr 40 | Strength Potion | $15,000 + 10m Luck + 5m Spawn |
| 2 hr | **$75,000** + 3 spins | $25,000 + 15m Super Cash + 15m Super Luck + guaranteed Rare+ pet |

**Current total cash: $116,500. Proposed: $57,500.**

Against the *current* Workshop price of $12,500, today's track pays for the area **nine times over** — the
5-minute reward alone is 8% of it. That is a genuine problem independent of everything else here, and it
is the cheapest thing on this list to fix.

The proposal also wants **active** playtime, not server time — activity meaning collected, moved, sold or
purchased within ~60s. We currently accumulate on a plain 5-second tick (`TickSeconds = 5`), so an
overnight AFK claims the whole track.

### Potions

We have four already, at **10 minutes** each: Cash ×2, Strength +15, Luck ×3, God (×5 cash, +100 str,
+15 range, ×3 collection, ×0.4 respawn, ×5 luck). The proposal wants shorter, weaker, more numerous:
+20% cash / +25% collection / +30% luck / +20% spawn at **5 minutes**.

Two of its rules we already follow: same-type potions **stack duration** rather than multiplying
(`startAt = max(now, existing) + duration`), and different types stack multiplicatively. No change needed.

There is no Spawn Potion today — that one is new.

---

## 8. Pets, magnets, skins

| | Current | Proposed |
| --- | --- | --- |
| Free pet slots | **2** (`BaseEquipSlots`), upgradeable | 3 |
| Premium slots | shared with free | 1 dedicated |
| Junkyard Egg | **$3,500** | $4,000 |
| Workshop Egg | **$35,000** | $35,000 ✓ |
| Quantum Egg | **$250,000** | $220,000 |
| Pet storage | 50 | — |
| Free pet value cap | none | +100% combined |
| Advanced Magnet | **$60,000** | $250,000 ("Medium") |
| Quantum Magnet | **Robux/premium** | $3,000,000 cash |
| Plot skins | 4% / 8% / 15% | 3% / 6% / 10%, equipped only, no stacking |

Egg prices are close enough to leave alone. The interesting ones:

**Pet bonuses must be additive, not multiplicative** — worth checking `GameMath.petEffectMultipliers`
against that, because three Nebula pets at +30% each is +90% if added and ×2.2 if multiplied.

**The Quantum Magnet decision is the good idea in this section.** At $3M against a $2M rebirth, the player
genuinely has to choose: prestige now, or grind another million for a permanent upgrade that survives it.
That only works if magnets survive rebirth (they do) and if it is cash, not Robux — see decision 5.

**One premium pet slot** is a real anti-whale rail: it stops five bought pets stacking into 4× an F2P
player's income. Worth taking.

---

## 9. Caps

| Thing | Current | Proposed |
| --- | --- | --- |
| Movement speed | cap 28 (EffectCap) | soft cap ~26 |
| Magnet range | cap 42 | soft cap 40–45 ✓ |
| Respawn floor | **absolute `max(0.45s, …)`** | **40–45% of the original interval** |
| Free pet value | none | +100% |
| Luck | cap 8 on the Rarity upgrade | not capped in the proposal |

Ours are already close on movement and range. **The respawn floor is the one worth changing**, and the
proposal is right: an absolute 0.45s floor means a 2-second MetalCan and a 12-second ScrapCar can both
reach the same rate, which quietly erases the difference between cheap and expensive scrap at high Spawn
Rate. A proportional floor keeps the ratio intact.

The gap the proposal misses, because it assumed a linear luck curve: **nothing caps total luck.** The
Rarity upgrade caps at 8, but potions, pets, events and rebirths multiply on top with no ceiling, and with
a 2.6 exponent on Nebula that compounds fast. If we keep exponents, cap the multiplier that feeds them.

---

## 10. Scrap Index — free progression

Currently the index tracks one row per scrap with a `HighestVariant`, so it is **18 rows**. Rarity is
already independent of type, so the data for **90 variants** (18 × 5) is nearly there — it needs
per-variant discovery rather than a single highest-seen.

Proposed milestone rewards: 25 → Cash Potion, 50 → exclusive pet, 75 → exclusive magnet skin, 90/90 →
title or aura. We already have a titles system and an achievements system to hang those on.

Cheap, and it gives completionists something entirely separate from rebirth grinding.

---

## 11. Not now, but do not paint over it

The proposal's duplicate sink — 5 identical pets → Shiny (×1.4), 5 Shiny → Charged (×1.3) — is the
long-term answer to pet power creep, and the reason to cap free-pet bonuses at +100% now. Worth knowing it
is the plan so nobody "fixes" the cap later by raising it.

---

## What I would do first, if you want an order

1. **Playtime cash** — $116,500 → $57,500. One config file, immediately makes the early game not
   self-solving, no dependencies on anything else here.
2. **Respawn floor** → proportional. One line, and it restores the difference between cheap and
   expensive scrap.
3. **Roll back some of my density/respawn changes** — I moved these ~5× and ~40% this session for
   "feels empty" reasons, and that is now pulling against pacing. Density can stay high for *looks* if
   respawn slows to compensate.
4. **Then the rebase**, as one change: scrap values, area prices, rebirth cost and growth, upgrade costs.
   These are one number in different clothes and cannot be moved separately without breaking the ratios.
5. Caps, luck ceiling, the index, pets/magnets last — they shape the curve rather than setting it.

Steps 1–3 are cheap and reversible. Step 4 is the actual work, and it is the one that wants a playtest
before anything else is layered on top.

---

## Not done, and why

**1. Quantum Magnet stays a Robux game pass.** The design makes it a $3M cash purchase to create the
"rebirth now or grind for the permanent magnet?" decision. It is a live SKU in `MonetizationConfig`, and
deleting a paid product is a business decision, not balance — which is what this pass was scoped to. The
*decision* still exists at the tier below: the Advanced Magnet is now $250,000, about a fifth of the
Graveyard unlock, so buying it visibly delays the next area. Say the word and I will move Quantum too.

**2. Plot skins were not retuned.** The design lowers them from 4/8/15% to 3/6/10%. There are no plot
skins in any config — nothing to change yet. Worth using 3/6/10 when they are built.

**3. `StoredWeight` still holds a slot count.** Storage is slots now, but the field kept its name: renaming
it means a schema migration plus every client readout and atom. The HUD reads as a count already, so what a
player sees is correct — but the field name lies to the next reader. Follow-up rename, deliberately
recorded rather than hidden.

**4. Active-playtime gating.** Rewards still accrue on a plain 5-second tick (`TickSeconds = 5`), so an
overnight AFK session still claims the whole ladder. The design wants accrual only when the player has
collected, moved, sold or bought inside the last ~60s. The cash on the track is now small enough
($57,500 against a $75,000 Workshop) that AFK cannot buy an area, so this is no longer urgent — but it is
still the difference between rewarding play and rewarding uptime.

**Also not done, and deliberately:** the 90-variant Scrap Index and the Shiny/Charged duplicate sink. Both
are new progression systems rather than balance, and both want their own pass.

---

## Two places I departed from the design, and why

**Nebula stays at 0.02% with the exponential luck curve.** The design argued Nebula down from 1% to
0.025%; we were already at 0.02%, so the recommendation was aimed at a number we do not have. The real
risk it could not see is the *curve*: ours is `weight × luck^2.6`, which compounds super-linearly, and
every source multiplies — upgrade, potion, event, pets, and now rebirths. Uncapped that reaches a 4.5%
Nebula rate. So instead of flattening the curve, `ScrapConfig.MaximumLuckMultiplier = 6` caps the product,
which holds the best case near 1 in 64. The rarity value multipliers also stay at ×1/2/5/15/75 rather than
dropping to ×1/2/4/8/25: keeping our rarer rate *and* taking the smaller payout would have made Nebula
worse than either design intended.

**Upgrade base costs were solved, not copied.** The design specified `cost = base × growth^level` with
bases of $250–$1,250, totalling ~$295,770 to max at level 10. Our formula is
`base × (level+1)^power × growth^√level`, which grows far more slowly at high level — dropping those bases
in gave **$2,652,104**, more than the $2,000,000 rebirth, so maxing before prestige became impossible
rather than expensive. The bases were solved backwards from the design's intended per-upgrade totals under
our own curve: **$295,187**, within 0.2%, with the curve that is already tested. If the formula ever
changes these must be re-solved.

## One thing worth watching in playtest

**Two of six Graveyard scraps cannot be lifted on a first run.** Reachable magnet strength at rebirth 0 is
22 with the Basic magnet and 30 with the Advanced; FuelTank needs 35 and ScrapCar 45. That may be exactly
right — it gives rebirth a visible reward and gives the new red reject-flash something real to point at —
but it means the Graveyard's headline scrap is a second-run prize. If it reads as frustration rather than
aspiration, lower those two requirements rather than inflating strength, which is load-bearing for every
other area.
