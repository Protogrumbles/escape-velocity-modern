# Modern Escape Velocity — design summary

Condensed from the full 12-page design document (GDD v0.1,
`modern-escape-velocity-design-doc.pdf`, kept outside this repo).
Nothing here invents lore that contradicts that document; where this
repo's slice 1 differs from the full vision, the difference is
marked **Slice 1**.

> **One-sentence pitch:** It feels like the UI8 fly demo — mouse-steered,
> banking, trailing — and it plays like Escape Velocity (Ambrosia,
> 1996): hyperjump between systems, land to trade and take missions,
> earn credits, and outfit a ship that is unmistakably yours.

## 1. Vision

You start with a shuttle and a debt. The galaxy does not care. You
are a new captain with a small ship, a thin wallet, and no
reputation. Fly anywhere. Land anywhere that will have you. Haul
cargo, run missions, fight or flee — and slowly become someone the
galaxy has to reckon with.

**Design pillars — cut anything that breaks these:**

1. **Flying is the game.** If flying between two planets is not fun
   with no cargo, no mission, and no enemy, nothing else saves it.
   Flight feel is built and tuned first, before content.
2. **Choose your living.** Trader, courier, bounty hunter, pirate,
   explorer, or faction loyalist — all first-class paths from the
   first hour, not endgame specialisations.
3. **Choices leave marks.** Reputation, legal record, and faction
   standing persist. Ports open and close because of what you did,
   not just what you bought.
4. **Readable, never fussy.** Top-down clarity at combat speed. No
   3D camera fights, no spreadsheet walls. Depth comes from routes,
   loadouts, and relationships.

**North-star test:** mute the HUD, remove every enemy and planet,
and fly in an empty system for 60 seconds. If that minute is not
pleasurable, the art and motion work is not done yet.

## 2. Visual direction — the fly demo's ocean becomes space

The reference reel (UI8's Fly demo, Instagram reel DfxNTXJhzIe) is
**not 3D and uses no Mode 7**. The jet, clouds, and terrain are
**stacked slices** — offset horizontal pixel layers that shift when
the jet banks, dives, or rolls, revealing side faces: voxel-like
pseudo-3D depth, no polygons, no 3D model. Every layer of that
trick has a direct space equivalent:

| Fly demo layer | This game |
|---|---|
| Blue ocean | Deep starfield, 3 depths (star layers scroll at 0.2x, 0.5x, 1.0x of ship speed) — **implemented**: the backdrop module's SPACE mode draws exactly this, and the scene sets `mode = 1` on the Backdrop node |
| White clouds + shadows | Nebula wisps, two layers (slow far tint, fast near streaks) — **implemented** in the same SPACE mode |
| Green islands | Planets, stations, asteroids — landable bodies, destinations not decoration |
| Jet sprite, banking | Ship sprite, banking (one sprite, rotated to heading, bank-left / bank-right frames in turns) |
| Wingtip contrails | Engine trails (fading particles at each engine; trails curve in a bank) |
| Click barrel roll | Evasive roll — 0.5 s, breaks missile lock |
| Stacked slices | Stacked-slice ships, nebula, and bodies — banking/rolling shifts layers and exposes side faces |

### Three cameras, cycled with Space

Space cycles **chase** (from behind the ship), **overhead** (the
classic top-down view), and **cockpit** (radar, dials, artificial
horizon), each switch taking about 1.4 seconds. The stacked-slice
world renders in all three.

### Art rules

- Pixel art, drawn once, readable small. Silhouette first: a
  freighter and a fighter must never be confused at a glance.
- **Restraint in the ship, intensity in the effects.** Hulls stay in
  muted faction palettes. Engine glow, trails, shield hits, and
  explosions carry the saturated colour.
- **Every system has a colour identity.** Core systems run teal and
  warm white; frontier systems run amber and dust; contested systems
  run red-shifted nebulae.
- **Motion is an art asset.** Camera lag, offset ship shadow, speed
  lines at high burn, zoom-out as speed rises — specified and tuned,
  not left to chance.

## 3. Core flight model

Point where you want to go. Drift like you mean it. The demo's
steering plus EV's physics underneath: velocity is persistent,
thrust adds acceleration along the nose (not along velocity), no
automatic friction except a very gentle drag cap. Turn rate is the
ship stat that matters most — starting shuttle slow and forgiving,
interceptor roughly 2.5x the shuttle, capital ships stately.

| Input | Action |
|---|---|
| Mouse position | Desired heading (ship turns toward cursor at its turn rate; banking automatic) |
| Hold left mouse / W | Main thrust (along the nose — this is what creates drift) |
| S | Retro / brake burn (weak reverse thrust) |
| Shift (hold) | Afterburner (higher thrust/top speed, drains fuel/energy, brighter trails, camera eases out) |
| Click (in flight) | Barrel roll (0.5 s, missile-lock break, small sideways velocity kick) |
| Right mouse / F | Fire primary; hold for turrets |
| L near a body | Land / dock (requires low relative speed inside the landing radius) |
| J, then click a route | Hyperjump (from the galaxy map; must be clear of gravity wells and combat) |

Camera: follows with lag (ship leads, camera catches up), looks
ahead slightly along velocity, zooms out smoothly as speed rises.
Feel checklist: camera lag, offset ship shadow, nebula passing
faster than the far starfield, curving trails in a bank, zoom-out on
burn — all five ship in the first prototype.

Gamepad support (left stick = heading, right trigger = thrust) and
full keyboard-only steering are planned for the vertical slice, not
the first prototype. Touch is out of scope until flight feel is
proven on mouse.

## 4. Galaxy and landing

The galaxy is a graph: star systems are nodes, hyperjump routes are
edges. Full game targets 80–120 systems; about 30 core systems are
hand-authored, the frontier beyond is procedurally assembled from
authored parts (seeded, reproducible). Inside a system: 1–4 landable
bodies plus asteroid fields, derelicts, and jump points, with ambient
traffic going about its business.

Hyperjump costs fuel by distance; fuel is bought at ports and is the
galaxy's natural range limiter early on. Charge-up takes a few
seconds; heavy fire can disrupt it. Arrival is at a system jump
point, never directly at a planet — you always fly the last leg.

Landing opens the port screen: commodity exchange, refuel and
repair, mission board, shipyard (larger ports), outfitter, bar
(tips, rumours), passenger lounge, faction offices. Planets have a
government, a tech level, and an economy type; those three facts
drive what is sold, what it costs, which missions appear, and
whether patrol scans you.

**Slice 1:** one system, three landable bodies (Astraea Prime,
Kestrel Station, Vireo), no hyperjump yet. Port functions are
keyboard-driven (see README.md), not screens.

## 5. Economy and trading

Buy low where it is made. Sell high where it is wanted.

| Commodity | Cheap where | Dear where |
|---|---|---|
| Food | Agricultural worlds | Mining and station systems |
| Industrial goods | Industrial worlds | Frontier colonies |
| Ore and metal | Mining systems | Industrial and shipyard worlds |
| Medicine | High-tech core worlds | Frontier and plague systems |
| Luxuries | Core and resort worlds | Wealthy stations |
| Contraband | Unregulated frontier | Core worlds (if you get in) — illegal in patrolled space |

Price logic: base price by economy match, plus a per-port stock
level that moves as you trade, plus events. No random noise the
player cannot read — the port screen shows why a price is high or
low in plain language. Cargo is physical: hold space is finite,
mass affects handling, jettisoning cargo to outrun a pirate is
always an option.

**Guardrail:** trading should be a good living, never the only good
living. If combat or missions pay noticeably worse per hour at equal
risk, rebalance them — not trading.

**Slice 1:** fixed per-planet base prices only (data/planets.json).
No stock movement, no events, no mass effects, no contraband yet.
See `scripts/economy.gd`.

## 6. Missions, story, and factions

Mission board (repeatable): delivery/courier, passenger, bounty and
patrol, escort, rush and special. Four to six factions hold the core
systems (trade federation, independent worlds alliance, corporate
combine, frontier freeholders, organised pirate confederacy), each
with a hand-written storyline of roughly 8–12 missions; storylines
conflict and the game says plainly when a choice is a point of no
return. There is no single main quest gating the galaxy.

Reputation, in three visible numbers: faction standing (per
faction), legal record, combat rating.

**Slice 1:** four repeatable delivery missions (data/missions.json).
No passengers, bounties, escorts, factions, or storylines yet.

## 7. Combat and AI

Combat is flight skill plus the ship you chose to build. Fights are
short, positional, and Newtonian. Fixed guns fire along the nose;
turrets track a selected target; missiles lock and are countered by
the barrel roll, point defence, or outrunning them. Shields
recharge out of fire; armour does not. A disabled ship can be
boarded, looted, or left.

AI archetypes: trader (flees, jettisons cargo), patrol (scans,
warns, engages lawbreakers), pirate (demands cargo first, fights
second), bounty hunter / rival, escort / wing. NPCs cheat on
information, never on physics.

Losing your ship is not game over: you escape in a pod, lose the
ship and cargo, keep your credits (minus a rescue and insurance
bite), and wake up at a port in a borrowed shuttle.

**Slice 1:** no enemies, no AI, no damage. F fires a shot that
flies straight and expires. Combat and AI arrive in Stage C.

## 8. Ships and outfitting

Launch roster target: 18–24 hulls — shuttle, courier, freighter
(light to heavy), interceptor / fighter, gunship / cruiser, exotic /
faction hulls (story rewards). Every hull has fixed hardpoints and a
general outfit-space and mass budget for shields, engines, cargo
expansion, fuel, and utility gear (hidden hold, mining laser,
passenger cabins, boarding gear, sensors, afterburner). Ships can be
captured as well as bought.

**Slice 1:** four hulls (data/ships/*.json) — shuttle (starter),
fighter, interceptor, freighter. Ship visuals use the
pixel-ship-factory params format (`ship_params_version: 1`); stats
(thrust, turn rate, hull HP, cargo, weapon) live in the same file
under `stats`. No shipyard, outfitting, or capture yet.

## 9. Interface, HUD, and audio

In-flight HUD: shield and armour bars, speed and heading, fuel,
credits, current system, radar / sensor ring, target frame, and
off-screen pointers for destination and mission objectives. Port
screens are one click apart and always show credits, cargo used /
free, fuel, and date in the same corner. The commodity screen shows
buy / sell, your average cost, and the plain-language reason for
the price.

Audio: engine hum pitched to thrust, near-silence in a drift,
wind-like nebula wash at speed; dry punchy gun sounds; a shield-hit
shimmer distinct from an armour clang; sparse ambient music that
layers tension in combat.

Save: one persistent captain save with autosave on landing and
jumping, plus manual save at any port. Versioned serialised state
from day one.

**Slice 1:** label-based HUD (no radar, no shield bars, no audio),
manual save/load only (K / O), versioned JSON save
(`user://escape_velocity_save.json`, v1).

## 10. Technical architecture

**Prototype in the browser. Ship in Godot.** Stage A (feel
prototype) is HTML5 Canvas + JavaScript — closest to the reference
demo, fastest loop for tuning steering, drift, trails, camera, and
parallax. Production is **Godot 4, 2D** — scenes, save system, input
mapping, audio buses, desktop export — with the same 2D sprite
approach. No 3D engine, no multiplayer in v1, no live-service
economy. This is a complete, ownable, offline game.

Core systems: fixed-timestep flight simulation (heading, thrust,
velocity, mass including cargo), decoupled from render rate;
rendering layers in strict draw order (far stars, far nebula,
system bodies, ships and shadows, near nebula, particles, HUD);
data-driven content (ships, outfits, commodities, systems, missions
in data files, not code); seeded, reproducible galaxy generation;
behaviour-state AI over the same flight model the player uses;
versioned saves.

Performance budget: locked 60 fps on modest hardware with a few
hundred active particles and 20–30 ships in system. If a feature
threatens that, the feature changes — not the budget.

## 11. Scope, roadmap, and risks

| Stage | Contents | Exit test |
|---|---|---|
| A — Feel prototype | One empty system, one ship, mouse steering, Newtonian drift, trails, nebula parallax, camera, barrel roll | 60 seconds of empty flying is fun (North-star test) |
| B — Loop prototype | 2 systems, 1 jump route, 2 ports, 4 commodities, delivery missions, credits, save | A stranger completes a trade run unaided and wants a second one |
| C — Vertical slice | 6 systems, combat + 3 AI archetypes, shipyard + outfitter, 3 hulls, one faction mini-arc (3 missions) | 30–45 minutes that feel like the full game in miniature |
| D — Full game | 80–120 systems, 18–24 hulls, 4–6 faction storylines, full economy and encounters | Content-complete; balance and polish pass |

**This repo is Stage B, slice 1:** one system, three ports, five
commodities, four delivery missions, four hulls, save/load — the
loop, before combat and hyperjump.

Risks and mitigations (from the GDD): drift frustrates new players
(generous starting turn rate, optional flight-assist toggle, first
mission is just flying to a nearby station); content volume
(data-driven authoring, hand-built core + procedural frontier);
economy exploits (stock-sensitive pricing, mass and fuel costs,
route-profit telemetry); scope creep toward 3D or multiplayer
(this document — the 2D, single-player sandbox is the game).

## 12. Decisions recorded in the GDD

1. Prototype platform: web Canvas first for feel, Godot 4 for production.
2. Primary fantasy: open sandbox with all livings equal; no forced main quest.
3. Flight assist default: on for the starter shuttle, fades as ships improve.
4. Art: original pixel art at one consistent density; no mixed asset packs.
5. Release target: desktop first (Steam-style), offline, single purchase.

Reference: UI8 Fly demo via Instagram reel
(https://www.instagram.com/reels/DfxNTXJhzIe/) and the Escape
Velocity series design lineage. All planets, factions, prices, and
missions in this repo are fictional and illustrative.
