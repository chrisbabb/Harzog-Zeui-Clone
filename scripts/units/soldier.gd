extends UnitBase
class_name Soldier
## Soldier - Basic ground combat unit
##
## Can attack: Ground units only (not air units)
## Cannot attack: Air units (flying units, heroes in plane mode)
## Purpose: Basic ground combat, weakest combat unit
## Targeting: Always targets closest enemy


func _ready() -> void:
	super._ready()
	unit_name = "Soldier"
	unit_type = "soldier"
	max_health = 80.0
	current_health = max_health
	move_speed = 100.0
	attack_range = 150.0
	attack_damage = 15.0
	attack_cooldown = 1.2
	detection_range = 350.0  # About 1/4 of viewable map (aggressive detection)
	is_flying = false
	z_index = 0  # Ground units render below air units

	# Soldiers are aggressive - they advance and attack enemies
	stance = Stance.ADVANCE


## Find closest target in range (ground units only)
func _find_best_target_in_range():
	# AI units only attack when visible to human players
	if not _is_human_player() and not _is_visible_to_human_player():
		return null

	var closest_target = null
	var closest_dist_sq = INF

	# Check all enemy units
	var all_units = get_tree().get_nodes_in_group("units")
	for unit in all_units:
		if _is_enemy(unit) and _can_target_unit(unit):
			var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, unit.global_position)
			if dist_sq <= detection_range * detection_range and dist_sq < closest_dist_sq:
				closest_target = unit
				closest_dist_sq = dist_sq

	# Also check enemy bases
	var all_bases = get_tree().get_nodes_in_group("main_bases")
	for base in all_bases:
		if _is_enemy(base):
			var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, base.global_position)
			if dist_sq <= detection_range * detection_range and dist_sq < closest_dist_sq:
				closest_target = base
				closest_dist_sq = dist_sq

	return closest_target


## Check if this unit belongs to a human player
func _is_human_player() -> bool:
	for player in GameManager.active_players:
		if player.slot_index == owner_slot and player.type == "Human":
			return true
	return false


## Check if this unit is visible to any human player's camera
func _is_visible_to_human_player() -> bool:
	var game_world = get_tree().root.get_node_or_null("GameWorld")
	if not game_world:
		return true  # Fallback: allow combat if can't find game world

	var cameras = game_world.get_player_cameras()
	for camera in cameras:
		if camera and camera.enabled:
			# Get camera's viewport rect in world coordinates
			var viewport = camera.get_viewport()
			if viewport:
				var viewport_rect = viewport.get_visible_rect()
				var camera_pos = camera.global_position

				# Simple check: is unit within ~800 units of camera (approximate screen)
				var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, camera_pos)
				if dist_sq <= 800.0 * 800.0:
					# Check if camera belongs to human player
					var camera_owner = camera.get_parent()
					if camera_owner and "owner_slot" in camera_owner:
						for player in GameManager.active_players:
							if player.slot_index == camera_owner.owner_slot and player.type == "Human":
								return true

	return false


## Check if this unit can target another unit
func _can_target_unit(unit) -> bool:
	# Cannot target flying units
	if "is_flying" in unit and unit.is_flying:
		return false

	# For transformer heroes, check their form
	if "current_form" in unit:
		# If hero is in plane mode, cannot target them
		if unit.current_form == 1:  # 1 = PLANE form
			return false

	return true


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not "team_color" in entity:
		return false

	return entity.team_color != team_color


## Choose where to march when no combat target (move toward enemy bases)
func _choose_strategic_target() -> Vector2:
	# Find nearest enemy base
	var enemy_bases = []
	for base in get_tree().get_nodes_in_group("main_bases"):
		if _is_enemy(base):
			enemy_bases.append(base)

	if not enemy_bases.is_empty():
		var closest_base = null
		var closest_dist_sq = INF

		for base in enemy_bases:
			var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, base.global_position)
			if dist_sq < closest_dist_sq:
				closest_base = base
				closest_dist_sq = dist_sq

		if closest_base:
			return closest_base.global_position

	# No enemy bases found, stay in place
	return global_position
