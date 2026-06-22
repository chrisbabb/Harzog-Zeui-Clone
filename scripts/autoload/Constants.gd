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

# Building health
const HQ_MAX_HP: float = 3000.0
const OUTPOST_MAX_HP: float = 1000.0

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
