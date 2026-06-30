# Balance Notes

This document records the design intent behind Skyforge Command's combat,
economy, and AI tuning. It's the companion to the `# balance:`-style comments
scattered through `Constants.gd`, `data/units.json`, `Commander.gd`,
`EnemyCommanderBot.gd`, and `EnemyAI.gd` — read those for the exact numbers,
read this for *why* they're set that way.

## Design goals

- Early game rewards capturing outposts over turtling.
- Mid game is about defending what you've taken and counterattacking.
- Late game allows HQ assaults, but only with heavy units/artillery in
  numbers — never a lone rush.
- The commander is a real combat threat but can't solo-win a match.
- Anti-air discourages a player (or AI) from just flying the commander
  over the battlefield and bombing everything unanswered.
- Supply trucks and capture drones are both unarmed support units that
  matter a lot but die fast if caught without escort.

## Unit roles

All stats below are current as of this pass; see `data/units.json` for the
authoritative numbers.

| Unit | Cost | Role |
|---|---|---|
| Scout Buggy | 120 | Cheap, fast early capturer/scout. Decent capture_power (0.9), weak combat stats — wins races to outposts, loses fights to anything dedicated. |
| Tank | 220 | The generalist main-line attacker. Best raw cost-efficiency in the roster (see below) — the unit every composition is built around. |
| Missile Crawler | 260 | Flexible support: meaningful ground damage plus real anti-air (28). The cheaper of the two AA-capable units. |
| Artillery | 340 | Long range (28), heavy single-target damage (45), but slow, fragile (140 HP, light armor), and the worst capturer in the game (0.25). Built for sieging HQs/outposts from outside their effective retaliation range, not front-line brawling. |
| Anti-Air | 280 | Highest air_damage (36) in the game — the dedicated "commander denial" unit. Mediocre vs ground. |
| Supply Truck | 180 | Unarmed. Repairs/refuels/rearms allies in a 9m radius. Slowest capturer that still meaningfully captures (0.2) — useful in a pinch, never the plan. Dies to anything if caught alone. |
| Capture Drone | 160 | Unarmed. By far the fastest capturer (2.2 capture_power, ~2.7s per outpost vs the 6s base). Only 90 HP and light armor — the most fragile unit in the game by a wide margin. |
| Heavy Walker | 560 | The premium late-game specialist: highest HP (480) and heavy armor (30% damage reduction), strong ground damage (38) plus minor secondary air damage (6). Most expensive unit by far and *not* a flat upgrade over Tank on a cost-efficiency basis — see below. Outpost-locked out of production (HQ only), reinforcing its late-game identity. |

### Cost-efficiency check ("no single unit dominates")

Using armor-adjusted effective HP (`hp / armor_multiplier`) and
armor-adjusted effective DPS (`(ground_damage/fire_rate) * armor_multiplier`
against its own armor class, as a proxy for "how much it costs an attacker
of the same armor tier to kill it"), Tank and Heavy Walker are the two
strongest by raw stats, which is intentional — they're both meant to be
strong. The tuning pass specifically pulled Heavy Walker's effHP/cost back
down to ~1.22 (was ~1.43, briefly beating Tank's ~1.39) by raising its cost
520→560, lowering its HP 520→480, and slowing its fire rate 1.8→2.0. Heavy
Walker still wins on raw survivability and is the only ground unit with any
air damage, but it's no longer strictly better than Tank per credit spent —
it's a premium, slow, expensive specialist instead of a flat upgrade.

## Counters

The roster is intentionally rock-paper-scissors rather than strictly
tiered:

- **Anti-Air / Missile Crawler beat an aggressive commander.** Nothing else
  in the game can touch an airborne commander; these two units are the
  entire answer to commander harassment. A commander that ignores AA
  presence near an objective will get shredded.
- **Artillery beats slow/stationary targets (buildings, parked Heavy
  Walkers) but loses to anything that closes distance.** Its range (28) is
  the longest in the game, but its HP (140) and armor (light) mean it dies
  fast in a straight fight once an enemy is inside that range.
- **Tank beats Scout Buggy and other light units** straight up on cost
  efficiency, but is out-ranged by Artillery and out-tanked by Heavy
  Walker.
- **Heavy Walker beats Tank in a 1:1 fight** (more HP, heavy armor, more
  damage) but costs 2.5x as much and moves at barely half the speed —
  Tank wins on cost-efficiency and mobility, Heavy Walker wins on raw
  power. Several Tanks for the price of one Heavy Walker can still
  overwhelm it.
- **Capture Drone / Supply Truck lose to literally everything** in a fight
  — they have zero weapons. They're high-value targets that need escort;
  losing an unescorted drone or truck to a single enemy scout is the
  intended risk/reward, not a bug.
- **Scout Buggy beats Capture Drone in a capture race when both arrive
  late**, since it can also fight, but loses the race outright if the drone
  has a head start (drone capture_power 2.2 vs buggy's 0.9).

## Intended strategies by phase

**Early game.** Starting money and the 0.9/2.2 capture_power of Scout
Buggy/Capture Drone make grabbing outposts the highest-value opening move —
each owned outpost adds `OUTPOST_INCOME_PER_SECOND` (4/sec) on top of the
base 8/sec HQ income, a 50% income increase per outpost, so contesting
outposts directly accelerates every later purchase. Sending a lone
Artillery or Heavy Walker this early is a poor trade: both have the worst
capture_power in the game and would arrive too slowly to contest anything
anyway.

**Mid game.** Once a few outposts are owned, Missile Crawler/Anti-Air
become relevant to hold them against enemy harassment (including enemy
commander dives), while Tanks contest neutral or enemy-owned ground.
`AI_THREAT_RADIUS` (30m around the HQ) governs when the AI itself shifts
into a defensive posture — same logic a player should apply manually:
defend what's under threat before pushing further.

**Late game.** HQ assaults are gated less by any single stat and more by
`HQ_MAX_HP` (3000) relative to unit DPS: a lone Heavy Walker (38 ground
damage / 2.0s fire rate ≈ 19 DPS, ~26% reduced further by the HQ's own
"heavy" default armor) would need well over two minutes of uncontested
fire to bring down an HQ alone, by which point production and repair would
have answered. Multiple Heavy Walkers/Artillery hitting together (or
arriving on the back of `EnemyAI`'s coordinated wave system / the
player manually massing a push) is what actually closes that gap —
exactly the "requires multiple units or strong commander support" goal.

**Commander, throughout.** The commander's GROUND-mode DPS (24 dmg /
0.4s cooldown = 60) is higher than any single unit's DPS, so it's a real
threat in a 1:1 duel against any unit in the game. But its 80-ammo pool
only sustains ~13 shots before a resupply is needed (down from 16 before
this pass), and a focused Anti-Air/Missile Crawler response punishes
reckless flying. It's deliberately strong enough to swing a skirmish, not
strong enough to replace an army.

## AI difficulty tuning

All AI balance knobs live in `Constants.gd` as `AI_*` arrays indexed by
`EnemyAI.Difficulty` (EASY=0, NORMAL=1, HARD=2):

- **`AI_DECISION_INTERVALS`** (5.0 / 3.0 / 1.5 sec) — how often the AI
  re-evaluates build/order decisions. Hard reads as far more reactive
  simply by deciding 3-4x more often than Easy.
- **`AI_BONUS_INCOME_PER_SEC`** (0 / 0 / 3.0) — Normal gets *no* economic
  edge over the player, so a Normal-difficulty game is a fair fight decided
  by play quality, not a hidden income bonus. Hard gets a deliberately
  slight edge (3/sec, ~37.5% of base HQ income) rather than an overwhelming
  one — enough to feel like a tougher opponent, not enough to win on
  economy alone.
- **`AI_WAVE_THRESHOLDS`** (2 / 3 / 5 units) and **`AI_WAVE_INTERVALS`**
  (36 / 24 / 15 sec) — Easy launches small, infrequent, predictable waves;
  Hard launches large waves under near-constant pressure.
- **`AI_THREAT_RADIUS`** (30m, shared across all difficulties) — the
  distance from the enemy HQ that triggers a defensive unit-order bias
  regardless of difficulty; only the *frequency* of reassessment differs
  per tier, not this radius itself.

`TacticalDirector.gd`'s per-difficulty unit-choice weighting (not modified
this pass — already correct) keeps Easy off Heavy Walker/Artillery/Anti-Air
entirely (a deliberately weak unit mix) while Hard has the full roster
available, satisfying "Easy: weak unit mix" / "Hard: better counters"
without needing new constants.

## Known balance risks

- **Heavy Walker vs. Tank is still close.** The cost-efficiency gap was
  narrowed, not eliminated entirely on purpose (Heavy Walker is *supposed*
  to be strong, just not strictly dominant) — if playtesting shows Heavy
  Walker spam is still the optimal HQ-only-production strategy, the next
  lever to pull is `speed` (3.2) or `fuel` (130), not HP/cost again.
- **Commander vs. Anti-Air is a hard counter, not a soft one.** Anti-Air's
  36 air_damage at 1.0 fire_rate (36 DPS) chunks the commander's 500 HP
  fast with no in-between state — a commander that flies near an Anti-Air
  unit either avoids it entirely or takes serious, fast damage. This is
  intentional ("discourage reckless harassment") but is a binary rather
  than a gradient; if it feels too punishing in practice, soften by raising
  Anti-Air's `fire_rate` value (i.e. slowing it down) rather than touching
  `air_damage`, to preserve its identity as the hard counter.
  *Status: not yet adjusted; this pass changed Anti-Air's ground_damage
  (5→7) and capture_power (0.4→0.35) only — air_damage was deliberately
  left untouched since it's the unit's entire reason to exist.*
- **The capture_power dead-data bug (fixed this pass).** Before this pass,
  `data/units.json`'s `capture_power` field was parsed by `UnitDatabase`
  but never read anywhere — `CaptureZone.gd` instead used three hardcoded
  local constants, so every non-drone, non-commander unit captured at an
  identical rate regardless of its JSON value. This silently flattened a
  chunk of the intended per-unit-type capture differentiation (e.g. Scout
  Buggy and Artillery captured at the same speed despite very different
  `capture_power` values in the data file). Fixed by adding
  `UnitDatabase.get_capture_power()` and wiring `CaptureZone._rate_for_body()`
  to use it; `Constants.COMMANDER_CAPTURE_POWER` /
  `Constants.DEFAULT_UNIT_CAPTURE_POWER` now hold the values that used to be
  hardcoded locals. Worth double-checking after this fix that no other
  `data/units.json` fields are similarly parsed-but-unused.
- **Outpost income ratio was left unchanged.** `OUTPOST_INCOME_PER_SECOND`
  (4) relative to `BASE_INCOME_PER_SECOND` (8) was already a 50% income
  boost per owned outpost before this pass, which already satisfies "make
  outpost income meaningful" — flagged here rather than changed to avoid
  unnecessary scope creep, but it's the first economy lever to revisit if
  playtesting shows outposts aren't worth contesting.
- **No automated test/playtest coverage.** This environment has no Godot
  binary available, so every change in this pass was verified by manual
  re-read of the edited files rather than by running the game. A real
  playtest pass (especially around the new commander ammo/cooldown numbers
  and the Heavy Walker/Tank balance) is recommended before relying on these
  numbers as final.
