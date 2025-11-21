extends Node
## InputManager - Handles input mapping for up to 4 players
##
## Supports:
## - Keyboard + Mouse (Player 1 default)
## - Controller 1-4
## - Remappable controls
## - Conflict detection

# Input device types
enum InputDevice {
	KEYBOARD_MOUSE,
	CONTROLLER_1,
	CONTROLLER_2,
	CONTROLLER_3,
	CONTROLLER_4
}

# Default control bindings
var default_bindings: Dictionary = {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"attack": MOUSE_BUTTON_LEFT,
	"transform": KEY_SPACE,
	"pickup": KEY_E,
	"deploy": KEY_R,
	"build_menu": KEY_B,
	"confirm": KEY_ENTER,
	"cancel": KEY_ESCAPE
}

# Player input mappings
# Key: player_index (1-4)
# Value: { "device": InputDevice, "bindings": Dictionary }
var player_mappings: Dictionary = {}


func _ready() -> void:
	print("InputManager initialized")
	_ensure_input_actions_exist()
	_setup_default_mappings()


## Ensure all input actions exist in InputMap (fix missing actions)
func _ensure_input_actions_exist() -> void:
	var actions = ["move_up", "move_down", "move_left", "move_right", "attack", "transform", "pickup", "deploy", "build_menu"]
	var keys = [KEY_W, KEY_S, KEY_A, KEY_D, MOUSE_BUTTON_LEFT, KEY_SPACE, KEY_E, KEY_R, KEY_B]

	for i in range(actions.size()):
		var action_name = "p1_%s" % actions[i]

		# Create action if it doesn't exist
		if not InputMap.has_action(action_name):
			print("Creating missing action: %s" % action_name)
			InputMap.add_action(action_name)

			# Add the key/button event
			if i < 4 or i >= 5:  # All except attack (which is mouse)
				var event = InputEventKey.new()
				event.physical_keycode = keys[i]
				InputMap.action_add_event(action_name, event)
			elif i == 4:  # Attack - mouse button
				var event = InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				InputMap.action_add_event(action_name, event)

	print("Input actions verified/created")


## Setup default input mappings for 4 players
func _setup_default_mappings() -> void:
	# Player 1: Keyboard + Mouse
	player_mappings[1] = {
		"device": InputDevice.KEYBOARD_MOUSE,
		"bindings": default_bindings.duplicate()
	}

	# Players 2-4: Controllers (if connected)
	for i in range(2, 5):
		player_mappings[i] = {
			"device": InputDevice.CONTROLLER_1 + (i - 2),
			"bindings": _get_default_controller_bindings()
		}


## Get default controller bindings
func _get_default_controller_bindings() -> Dictionary:
	return {
		"move_up": JOY_BUTTON_DPAD_UP,
		"move_down": JOY_BUTTON_DPAD_DOWN,
		"move_left": JOY_BUTTON_DPAD_LEFT,
		"move_right": JOY_BUTTON_DPAD_RIGHT,
		"attack": JOY_BUTTON_A,
		"transform": JOY_BUTTON_B,
		"pickup": JOY_BUTTON_X,
		"deploy": JOY_BUTTON_Y,
		"build_menu": JOY_BUTTON_LEFT_SHOULDER,
		"confirm": JOY_BUTTON_A,
		"cancel": JOY_BUTTON_B
	}


## Check if a specific action is pressed for a player
func is_action_pressed(player_index: int, action: String) -> bool:
	if not player_mappings.has(player_index):
		return false

	var mapping = player_mappings[player_index]
	var device = mapping.device

	# Keyboard + Mouse
	if device == InputDevice.KEYBOARD_MOUSE:
		var action_name = "p%d_%s" % [player_index, action]
		return Input.is_action_pressed(action_name)

	# Controller
	else:
		var controller_id = device - InputDevice.CONTROLLER_1
		return Input.is_joy_button_pressed(controller_id, mapping.bindings[action])


## Check if a specific action was just pressed for a player
func is_action_just_pressed(player_index: int, action: String) -> bool:
	if not player_mappings.has(player_index):
		return false

	var mapping = player_mappings[player_index]
	var device = mapping.device

	# Keyboard + Mouse
	if device == InputDevice.KEYBOARD_MOUSE:
		return Input.is_action_just_pressed("p%d_%s" % [player_index, action])

	# Controller
	else:
		var controller_id = device - InputDevice.CONTROLLER_1
		# For controllers, we need to track button states manually
		# This is a simplified version
		return Input.is_joy_button_pressed(controller_id, mapping.bindings[action])


## Get movement vector for a player (-1 to 1 for both axes)
func get_movement_vector(player_index: int) -> Vector2:
	var vector = Vector2.ZERO

	# Check each direction
	if is_action_pressed(player_index, "move_right"):
		vector.x += 1.0
	if is_action_pressed(player_index, "move_left"):
		vector.x -= 1.0
	if is_action_pressed(player_index, "move_down"):
		vector.y += 1.0
	if is_action_pressed(player_index, "move_up"):
		vector.y -= 1.0

	# Normalize only if non-zero to avoid errors
	if vector.length_squared() > 0:
		return vector.normalized()
	return vector


## Get aim direction for a player (used for aiming attacks)
## For keyboard+mouse: returns direction to mouse
## For controller: returns right stick direction
func get_aim_direction(player_index: int) -> Vector2:
	if not player_mappings.has(player_index):
		return Vector2.ZERO

	var mapping = player_mappings[player_index]
	var device = mapping.device

	# Keyboard + Mouse: aim towards mouse position
	if device == InputDevice.KEYBOARD_MOUSE:
		# This will need to be implemented per-viewport for split-screen
		return Vector2.RIGHT  # Placeholder

	# Controller: use right stick
	else:
		var controller_id = device - InputDevice.CONTROLLER_1
		var aim_x = Input.get_joy_axis(controller_id, JOY_AXIS_RIGHT_X)
		var aim_y = Input.get_joy_axis(controller_id, JOY_AXIS_RIGHT_Y)
		return Vector2(aim_x, aim_y).normalized()


## Remap a control for a player
func remap_control(player_index: int, action: String, new_key_or_button: int) -> bool:
	if not player_mappings.has(player_index):
		return false

	# Check for conflicts
	if _has_conflict(player_index, action, new_key_or_button):
		push_warning("Control conflict detected for player %d" % player_index)
		return false

	player_mappings[player_index].bindings[action] = new_key_or_button
	return true


## Check if a binding would conflict with existing bindings
func _has_conflict(player_index: int, action: String, key_or_button: int) -> bool:
	var mapping = player_mappings[player_index]

	for existing_action in mapping.bindings:
		if existing_action != action and mapping.bindings[existing_action] == key_or_button:
			return true

	return false


## Reset player controls to defaults
func reset_to_defaults(player_index: int) -> void:
	if not player_mappings.has(player_index):
		return

	var device = player_mappings[player_index].device

	if device == InputDevice.KEYBOARD_MOUSE:
		player_mappings[player_index].bindings = default_bindings.duplicate()
	else:
		player_mappings[player_index].bindings = _get_default_controller_bindings()


## Change player's input device
func set_player_device(player_index: int, device: InputDevice) -> void:
	if not player_mappings.has(player_index):
		player_mappings[player_index] = {
			"device": device,
			"bindings": {}
		}
	else:
		player_mappings[player_index].device = device

	# Reset bindings for new device
	reset_to_defaults(player_index)
