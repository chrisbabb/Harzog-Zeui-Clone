extends StaticBody2D
class_name MiniBase
## MiniBase - Small capturable base that can be controlled by peons
##
## Features:
## - Neutral by default
## - Captured by getting 4 peons inside
## - Shows visual bars with dots for each player's peon count
## - When a player reaches 4 peons, all others reset

# Ownership
var owner_slot: int = -1  # -1 means neutral
var team_color: String = "Neutral"
var is_neutral: bool = true

# Peon count capture system
const PEONS_NEEDED_TO_CAPTURE: int = 4
var peon_counts: Dictionary = {}  # player_slot -> count of peons inside
var peons_inside: Dictionary = {}  # peon_instance -> player_slot (for tracking)

# Visual elements
var visual_rect: ColorRect = null
var capture_bars: Array = []  # Visual bars showing peon counts
var capture_zone: Area2D = null

# Player color mapping
const PLAYER_COLORS = {
	"Red": Color(1.0, 0.3, 0.3, 1.0),
	"Blue": Color(0.3, 0.5, 1.0, 1.0),
	"Green": Color(0.3, 1.0, 0.3, 1.0),
	"Yellow": Color(1.0, 1.0, 0.3, 1.0),
	"Purple": Color(0.8, 0.3, 0.8, 1.0),
	"Orange": Color(1.0, 0.6, 0.2, 1.0)
}


func _ready() -> void:
	add_to_group("mini_bases")
	add_to_group("buildings")
	z_index = 0  # Ensure bases render below air units
	_create_visual()
	_create_capture_zone()


func _process(_delta: float) -> void:
	# Update peon counts by checking which peons are still inside
	_update_peon_counts()

	# Update visual bars
	_update_capture_bars()

	# Check for capture
	_check_for_capture()


## Create visual representation
func _create_visual() -> void:
	# Create base square
	visual_rect = ColorRect.new()
	visual_rect.size = Vector2(60, 60)
	visual_rect.position = Vector2(-30, -30)
	visual_rect.color = Color(0.5, 0.5, 0.5, 1.0)  # Gray for neutral
	add_child(visual_rect)

	# Add collision shape for the base itself
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(60, 60)
	collision.shape = shape
	add_child(collision)

	# Add label
	var label = Label.new()
	label.text = "Mini Base"
	label.position = Vector2(-25, -50)
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)

	# Create capture bars (one for each potential player)
	_create_capture_bars()


## Create capture zone to detect peons
func _create_capture_zone() -> void:
	capture_zone = Area2D.new()
	capture_zone.name = "CaptureZone"

	# Larger detection area around the base
	var zone_collision = CollisionShape2D.new()
	var zone_shape = CircleShape2D.new()
	zone_shape.radius = 100.0  # Peons must be within 100 units
	zone_collision.shape = zone_shape
	capture_zone.add_child(zone_collision)

	# Set collision layers so it only detects units
	capture_zone.collision_layer = 0
	capture_zone.collision_mask = 1  # Units are on layer 1

	# Connect signals
	capture_zone.body_entered.connect(_on_body_entered_capture_zone)
	capture_zone.body_exited.connect(_on_body_exited_capture_zone)
	capture_zone.area_entered.connect(_on_area_entered_capture_zone)
	capture_zone.area_exited.connect(_on_area_exited_capture_zone)

	add_child(capture_zone)


## Create visual bars for showing peon counts
func _create_capture_bars() -> void:
	var num_players = GameManager.active_players.size()
	if num_players == 0:
		num_players = 4  # Default to 4 if not initialized yet

	var bar_width = 40
	var bar_height = 8
	var bar_spacing = 2
	var start_y = 35  # Below the base

	for i in range(num_players):
		var bar_container = Control.new()
		bar_container.position = Vector2(-bar_width / 2, start_y + i * (bar_height + bar_spacing))
		bar_container.size = Vector2(bar_width, bar_height)

		# Black background bar
		var bg_bar = ColorRect.new()
		bg_bar.size = Vector2(bar_width, bar_height)
		bg_bar.color = Color(0.1, 0.1, 0.1, 1.0)
		bar_container.add_child(bg_bar)

		# Store dots for this bar (up to 4 dots)
		var dots = []
		for j in range(PEONS_NEEDED_TO_CAPTURE):
			var dot = ColorRect.new()
			var dot_size = 6
			dot.size = Vector2(dot_size, dot_size)
			dot.position = Vector2(2 + j * (dot_size + 2), 1)
			dot.color = Color(0.1, 0.1, 0.1, 1.0)  # Start invisible (same as background)
			dot.visible = false
			bar_container.add_child(dot)
			dots.append(dot)

		capture_bars.append({
			"container": bar_container,
			"dots": dots,
			"player_slot": -1  # Will be assigned based on active players
		})

		add_child(bar_container)

	# Assign player slots to bars
	_assign_bars_to_players()


## Assign bars to active players
func _assign_bars_to_players() -> void:
	for i in range(min(capture_bars.size(), GameManager.active_players.size())):
		if i < GameManager.active_players.size():
			capture_bars[i]["player_slot"] = GameManager.active_players[i].slot_index


## Handle body/area entering capture zone
func _on_body_entered_capture_zone(body: Node) -> void:
	_try_add_peon(body)


func _on_area_entered_capture_zone(area: Node) -> void:
	# Sometimes units are Area2D
	_try_add_peon(area.get_parent() if area.get_parent() else area)


## Try to add a peon to the capture count
func _try_add_peon(entity: Node) -> void:
	# Must be a peon
	if not "unit_type" in entity or entity.unit_type != "peon":
		return

	# Must have owner info
	if not "owner_slot" in entity:
		return

	# Don't count if already counted
	if peons_inside.has(entity):
		return

	var player_slot = entity.owner_slot
	peons_inside[entity] = player_slot

	# Increment count
	peon_counts[player_slot] = peon_counts.get(player_slot, 0) + 1

	# Hide the peon while inside
	entity.visible = false

	print("Peon entered mini base - Player %d now has %d peons inside" % [player_slot, peon_counts[player_slot]])


## Handle body/area leaving capture zone
func _on_body_exited_capture_zone(body: Node) -> void:
	_try_remove_peon(body)


func _on_area_exited_capture_zone(area: Node) -> void:
	_try_remove_peon(area.get_parent() if area.get_parent() else area)


## Try to remove a peon from the capture count
func _try_remove_peon(entity: Node) -> void:
	if not peons_inside.has(entity):
		return

	var player_slot = peons_inside[entity]
	peons_inside.erase(entity)

	# Decrement count
	peon_counts[player_slot] = max(0, peon_counts.get(player_slot, 0) - 1)

	# Show the peon again when it exits
	if is_instance_valid(entity):
		entity.visible = true

	print("Peon left mini base - Player %d now has %d peons inside" % [player_slot, peon_counts[player_slot]])


## Update peon counts (remove dead/invalid peons)
func _update_peon_counts() -> void:
	var peons_to_remove = []

	for peon in peons_inside.keys():
		if not is_instance_valid(peon) or peon.is_queued_for_deletion():
			peons_to_remove.append(peon)

	for peon in peons_to_remove:
		var player_slot = peons_inside[peon]
		peons_inside.erase(peon)
		peon_counts[player_slot] = max(0, peon_counts.get(player_slot, 0) - 1)
		# Note: No need to make visible - peon is already dead/invalid


## Update visual capture bars
func _update_capture_bars() -> void:
	for bar_data in capture_bars:
		var player_slot = bar_data["player_slot"]
		if player_slot == -1:
			continue

		# Get player info
		var player_info = null
		for player in GameManager.active_players:
			if player.slot_index == player_slot:
				player_info = player
				break

		if not player_info:
			continue

		# Get peon count for this player
		var count = peon_counts.get(player_slot, 0)

		# Get player color
		var player_color = PLAYER_COLORS.get(player_info.color, Color.WHITE)

		# Update dots
		var dots = bar_data["dots"]
		for i in range(dots.size()):
			if i < count:
				dots[i].visible = true
				dots[i].color = player_color
			else:
				dots[i].visible = false


## Check if any player has reached capture threshold
func _check_for_capture() -> void:
	for player_slot in peon_counts.keys():
		var count = peon_counts[player_slot]

		if count >= PEONS_NEEDED_TO_CAPTURE:
			_capture_by_player(player_slot)
			break


## Capture the base for a player
func _capture_by_player(player_slot: int) -> void:
	# Find player info
	var player_info = null
	for player in GameManager.active_players:
		if player.slot_index == player_slot:
			player_info = player
			break

	if not player_info:
		return

	# Set new owner
	owner_slot = player_slot
	team_color = player_info.color
	is_neutral = false

	# Update visual
	_update_visual()

	print("Mini base captured by Player %d (%s)!" % [owner_slot, team_color])

	# Make all peons visible again before clearing
	for peon in peons_inside.keys():
		if is_instance_valid(peon):
			peon.visible = true

	# Reset ALL peon counts (including the capturing player)
	peon_counts.clear()
	peons_inside.clear()

	# Update resource generation
	_update_all_base_counts()


## Update base counts for all players (called after capture)
func _update_all_base_counts() -> void:
	# Count bases for each player
	var base_counts: Dictionary = {}

	# Count main bases
	for base in get_tree().get_nodes_in_group("main_bases"):
		if base.has_meta("owner_slot"):
			var slot = base.get_meta("owner_slot")
			base_counts[slot] = base_counts.get(slot, 0) + 1

	# Count mini bases
	for mini_base in get_tree().get_nodes_in_group("mini_bases"):
		if not mini_base.is_neutral:
			var slot = mini_base.owner_slot
			base_counts[slot] = base_counts.get(slot, 0) + 1

	# Update GameManager with new counts
	for player in GameManager.active_players:
		var slot = player.slot_index
		var count = base_counts.get(slot, 1)  # At least main base
		GameManager.set_player_base_count(slot, count)


## Update visual based on ownership
func _update_visual() -> void:
	if not visual_rect:
		return

	if is_neutral:
		visual_rect.color = Color(0.5, 0.5, 0.5, 1.0)  # Gray
	else:
		visual_rect.color = PLAYER_COLORS.get(team_color, Color(0.5, 0.5, 0.5, 1.0))


## Set initial ownership (for testing)
func set_owner_info(slot: int, color: String) -> void:
	owner_slot = slot
	team_color = color
	is_neutral = false
	_update_visual()
