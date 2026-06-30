extends Node
## Autoload singleton holding shared constant values for Skyforge Command.
## No game state lives here — only fixed configuration values.

# Teams
enum Team { PLAYER, ENEMY, NEUTRAL }

# Commander transform modes
enum CommanderMode { AIR, GROUND }

# Buildable/spawnable unit types
enum UnitType {
	SCOUT_BUGGY,
	TANK,
	MISSILE_CRAWLER,
	ARTILLERY,
	ANTI_AIR,
	SUPPLY_TRUCK,
	CAPTURE_DRONE,
	HEAVY_WALKER,
}

# Orders a unit can be given via the command menu
enum UnitOrder {
	HOLD_POSITION,
	PATROL_RADIUS,
	ADVANCE_TO_TARGET,
	ATTACK_BASE,
	CAPTURE_OUTPOST,
	DEFEND_OUTPOST,
	SUPPORT_ALLIES,
}

# Building categories
enum BuildingType { HQ, OUTPOST }

# Skirmish setup: map layout presets and match speed options
enum MapPreset { GREEN_DIVIDE, IRON_BASIN, ASH_LINE }
enum MatchSpeed { NORMAL, FAST }

const MATCH_SPEED_MULTIPLIERS: Dictionary = {
	MatchSpeed.NORMAL: 1.0,
	MatchSpeed.FAST: 1.5,
}

# Display names for UnitOrder, shared by the command menu and HUD/build menu feedback
const UNIT_ORDER_NAMES: Dictionary = {
	UnitOrder.HOLD_POSITION: "Hold Position",
	UnitOrder.PATROL_RADIUS: "Patrol Radius",
	UnitOrder.ADVANCE_TO_TARGET: "Advance To Target",
	UnitOrder.ATTACK_BASE: "Attack Enemy HQ",
	UnitOrder.CAPTURE_OUTPOST: "Capture Nearest Outpost",
	UnitOrder.DEFEND_OUTPOST: "Defend Friendly Outpost",
	UnitOrder.SUPPORT_ALLIES: "Support Allies",
}

# Abbreviations for UnitOrder, shown on the floating order label above units
const UNIT_ORDER_ABBREVIATIONS: Dictionary = {
	UnitOrder.HOLD_POSITION: "HOLD",
	UnitOrder.PATROL_RADIUS: "PATROL",
	UnitOrder.ADVANCE_TO_TARGET: "ADV",
	UnitOrder.ATTACK_BASE: "HQ",
	UnitOrder.CAPTURE_OUTPOST: "CAP",
	UnitOrder.DEFEND_OUTPOST: "DEF",
	UnitOrder.SUPPORT_ALLIES: "SUP",
}

# Economy
const STARTING_MONEY: int = 800
const BASE_INCOME_PER_SECOND: int = 8
const OUTPOST_INCOME_PER_SECOND: int = 4

# Player commander stats
const MAX_PLAYER_FUEL: float = 100.0
const MAX_PLAYER_AMMO: float = 80.0
const PLAYER_AIR_SPEED: float = 22.0
const PLAYER_GROUND_SPEED: float = 11.0
const PLAYER_TRANSFORM_TIME: float = 0.45

# Pickup / capture ranges and timings
const PICKUP_RANGE: float = 4.5
const DROP_RANGE: float = 5.0
const CAPTURE_RADIUS: float = 6.0
const OUTPOST_CAPTURE_TIME: float = 6.0

# Outpost capture speed: CaptureZone.gd divides OUTPOST_CAPTURE_TIME by each
# occupant's capture rate. Units use their own "capture_power" stat from
# data/units.json (so e.g. Capture Drones are the fastest and Supply Trucks
# the slowest); the commander instead uses this flat, deliberately middling
# rate so it's a viable capturer in a pinch but never the optimal choice --
# escorting a drone is always faster.
const COMMANDER_CAPTURE_POWER: float = 0.6
const DEFAULT_UNIT_CAPTURE_POWER: float = 1.0

# Command menu order-changing: a unit's order can only be changed while it's
# carried, or while the commander is in GROUND mode within this range of it.
const ORDER_RANGE: float = 5.0
const ORDER_CHANGE_COST: int = 20

# Building health
const HQ_MAX_HP: float = 3000.0
const OUTPOST_MAX_HP: float = 1000.0

# Armor reduces incoming damage by a flat percentage, keyed by the "armor"
# string from data/units.json (also used as the default for buildings).
const ARMOR_DAMAGE_MULTIPLIERS: Dictionary = {
	"light": 1.0,
	"medium": 0.85,
	"heavy": 0.70,
}

# Enemy AI difficulty tuning, indexed by EnemyAI.Difficulty (EASY=0,
# NORMAL=1, HARD=2). Centralized here rather than left as private consts on
# EnemyAI.gd so every balance knob for the skirmish opponent lives in one
# place. See BALANCE_NOTES.md for the reasoning behind each tier.
#
# Seconds between AI decision ticks (build/order evaluation) -- lower means
# the AI reassesses the battlefield more often, reading as more aggressive.
const AI_DECISION_INTERVALS: Array[float] = [5.0, 3.0, 1.5]
# Flat bonus income/sec layered on top of the shared economy. Normal is kept
# at 0 so it competes on equal economic footing with the player; only Hard
# gets a deliberately slight edge rather than an overwhelming one.
const AI_BONUS_INCOME_PER_SEC: Array[float] = [0.0, 0.0, 3.0]
# Combat units required before a coordinated attack wave launches early.
const AI_WAVE_THRESHOLDS: Array[int] = [2, 3, 5]
# Max seconds between forced wave launches regardless of threshold -- keeps
# Easy's pressure sparse and infrequent, Hard's pressure near-constant.
const AI_WAVE_INTERVALS: Array[float] = [36.0, 24.0, 15.0]
# Distance from the enemy HQ that counts as "under threat" from player
# units, triggering a defensive unit-type bias regardless of difficulty.
const AI_THREAT_RADIUS: float = 30.0

# Maximum number of ground units either team may field simultaneously.
const MAX_UNITS_PER_TEAM: int = 60

# Shared brief flash applied to a body's material when it takes damage.
const DAMAGE_FLASH_DURATION: float = 0.12
const DAMAGE_FLASH_COLOR: Color = Color(1.0, 1.0, 1.0)

# Generic ground-unit movement defaults, for unit types without a tuned speed yet
const UNIT_DEFAULT_SPEED: float = 4.0
const UNIT_NAVIGATION_ARRIVAL_DISTANCE: float = 0.5

# Input action names (kept in one place to avoid typos at call sites)
const ACTION_MOVE_FORWARD: String = "move_forward"
const ACTION_MOVE_BACK: String = "move_back"
const ACTION_MOVE_LEFT: String = "move_left"
const ACTION_MOVE_RIGHT: String = "move_right"
const ACTION_FIRE_PRIMARY: String = "fire_primary"
const ACTION_TRANSFORM_MODE: String = "transform_mode"
const ACTION_PICKUP_DROP: String = "pickup_drop"
const ACTION_OPEN_BUILD_MENU: String = "open_build_menu"
const ACTION_OPEN_COMMAND_MENU: String = "open_command_menu"
const ACTION_CONFIRM: String = "confirm"
const ACTION_CANCEL: String = "cancel"
const ACTION_PAUSE: String = "pause"
const ACTION_MINIMAP_ZOOM: String = "minimap_zoom"
const ACTION_CYCLE_ORDER: String = "cycle_order"
const ACTION_AIM_RIGHT: String = "aim_right"
const ACTION_AIM_LEFT: String = "aim_left"
const ACTION_AIM_FORWARD: String = "aim_forward"
const ACTION_AIM_BACK: String = "aim_back"

# Battlefield dimensions
const ARENA_LENGTH: float = 220.0
const ARENA_WIDTH: float = 120.0

# Camera follow/clamp behavior
const CAMERA_FOLLOW_SPEED: float = 4.0
const CAMERA_CLAMP_MARGIN: Vector2 = Vector2(35.0, 24.0)

# Team color coding, shared by buildings/units and minimap alike
const COLOR_PLAYER: Color = Color(0.2, 0.6, 1.0)
const COLOR_ENEMY: Color = Color(1.0, 0.3, 0.2)
const COLOR_NEUTRAL: Color = Color(0.6, 0.6, 0.6)


static func team_color(team: int) -> Color:
	if team == Team.PLAYER:
		return COLOR_PLAYER
	elif team == Team.ENEMY:
		return COLOR_ENEMY
	return COLOR_NEUTRAL


static func armor_multiplier(armor: String) -> float:
	return ARMOR_DAMAGE_MULTIPLIERS.get(armor, 1.0)
