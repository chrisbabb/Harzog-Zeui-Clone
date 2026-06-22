extends Node
## Autoload singleton holding shared constant values for Skyforge Command.
## No game state lives here — only fixed configuration values.

# Teams
enum Team { NEUTRAL, PLAYER, ENEMY }

# Commander transform modes
enum CommanderMode { GROUND, AIR }

# Unit categories
enum UnitClass { INFANTRY, VEHICLE, AIR, TURRET }

# Build/command menu action types
enum CommandAction { MOVE, ATTACK, HOLD, FOLLOW, STOP }

# Camera
const CAMERA_DEFAULT_SIZE: float = 20.0
const CAMERA_MIN_SIZE: float = 8.0
const CAMERA_MAX_SIZE: float = 40.0
const CAMERA_ANGLE_DEGREES: float = -45.0

# Commander movement
const COMMANDER_GROUND_SPEED: float = 6.0
const COMMANDER_AIR_SPEED: float = 12.0
const COMMANDER_TRANSFORM_COOLDOWN: float = 0.75

# Generic unit movement
const UNIT_DEFAULT_SPEED: float = 4.0
const UNIT_NAVIGATION_ARRIVAL_DISTANCE: float = 0.5

# Economy defaults
const STARTING_RESOURCES: int = 200
const RESOURCE_TICK_INTERVAL: float = 1.0
const RESOURCE_TICK_AMOUNT: int = 5

# Buildings
const BASE_STARTING_HEALTH: float = 1000.0
const OUTPOST_STARTING_HEALTH: float = 400.0

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
