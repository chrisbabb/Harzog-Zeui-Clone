class_name MapGenerator
extends RefCounted
## Stateless battlefield layout generator.
## Builds both HQs and the neutral outposts, then hands off to
## TerrainVisualGenerator for everything about how the ground looks and
## what's scattered on it (zones, roads, cliffs, obstacles, decorations).
## Called once from the gameplay scene's _ready().

const HQ_SCENE: PackedScene = preload("res://scenes/buildings/Base.tscn")
const OUTPOST_SCENE: PackedScene = preload("res://scenes/buildings/Outpost.tscn")

## One layout per Constants.MapPreset. "outposts" lists are priority-ordered
## (highest-priority first) so generate_battlefield() can slice the first N
## for whatever GameState.selected_outpost_count was chosen (5/7/9) while
## keeping each map's character -- e.g. Iron Basin's middle cluster stays
## first so its outposts read as "strong middle" even at the lowest count.
const MAP_LAYOUTS: Dictionary = {
	# Balanced, open central field: hand-placed rather than mirrored, so
	# neither side reads as a perfect reflection of the other.
	Constants.MapPreset.GREEN_DIVIDE: {
		"player_hq": Vector3(-90.0, 0.0, 0.0),
		"enemy_hq": Vector3(90.0, 0.0, 0.0),
		"outposts": [
			Vector3(6.0, 0.0, 3.0),
			Vector3(-50.0, 0.0, 4.0),
			Vector3(58.0, 0.0, 6.0),
			Vector3(-9.0, 0.0, -35.0),
			Vector3(10.0, 0.0, 32.0),
			Vector3(-55.0, 0.0, -32.0),
			Vector3(52.0, 0.0, -29.0),
			Vector3(-60.0, 0.0, 28.0),
			Vector3(48.0, 0.0, 34.0),
		],
		"obstacles": [
			Vector3(-30.0, 0.0, -18.0),
			Vector3(-20.0, 0.0, 22.0),
			Vector3(25.0, 0.0, -20.0),
			Vector3(32.0, 0.0, 18.0),
			Vector3(0.0, 0.0, -12.0),
		],
	},
	# More obstacles, strong middle outposts: HQs pulled in slightly so the
	# crowded, obstacle-heavy center is reachable early and worth fighting for.
	Constants.MapPreset.IRON_BASIN: {
		"player_hq": Vector3(-85.0, 0.0, 0.0),
		"enemy_hq": Vector3(85.0, 0.0, 0.0),
		"outposts": [
			Vector3(-12.0, 0.0, -14.0),
			Vector3(14.0, 0.0, -10.0),
			Vector3(-10.0, 0.0, 16.0),
			Vector3(16.0, 0.0, 18.0),
			Vector3(-58.0, 0.0, -22.0),
			Vector3(58.0, 0.0, -20.0),
			Vector3(-56.0, 0.0, 24.0),
			Vector3(56.0, 0.0, 26.0),
			Vector3(0.0, 0.0, -34.0),
		],
		"obstacles": [
			Vector3(-30.0, 0.0, -8.0),
			Vector3(-28.0, 0.0, 20.0),
			Vector3(30.0, 0.0, -6.0),
			Vector3(28.0, 0.0, 22.0),
			Vector3(0.0, 0.0, -26.0),
			Vector3(0.0, 0.0, 30.0),
			Vector3(-45.0, 0.0, 4.0),
			Vector3(45.0, 0.0, 2.0),
			Vector3(5.0, 0.0, -2.0),
		],
	},
	# Long, narrow battlefield: HQs pushed apart, outposts confined to a
	# tight central band so the frontline forms fast and stays aggressive.
	Constants.MapPreset.ASH_LINE: {
		"player_hq": Vector3(-100.0, 0.0, 0.0),
		"enemy_hq": Vector3(100.0, 0.0, 0.0),
		"outposts": [
			Vector3(0.0, 0.0, -8.0),
			Vector3(0.0, 0.0, 10.0),
			Vector3(-30.0, 0.0, -14.0),
			Vector3(30.0, 0.0, 12.0),
			Vector3(-30.0, 0.0, 14.0),
			Vector3(30.0, 0.0, -12.0),
			Vector3(-60.0, 0.0, -10.0),
			Vector3(60.0, 0.0, 8.0),
			Vector3(62.0, 0.0, -16.0),
		],
		"obstacles": [
			Vector3(-40.0, 0.0, -22.0),
			Vector3(-40.0, 0.0, 22.0),
			Vector3(40.0, 0.0, -22.0),
			Vector3(40.0, 0.0, 22.0),
		],
	},
}

static func generate_battlefield(game_root: Node3D, map_name: String = "") -> void:
	var world_root: Node3D = game_root.get_node("WorldRoot")
	var buildings_root: Node3D = world_root.get_node("BuildingsRoot")

	var map_id: int = _resolve_map_id(map_name)
	var layout: Dictionary = MAP_LAYOUTS.get(
		map_id, MAP_LAYOUTS[Constants.MapPreset.GREEN_DIVIDE]
	)
	var player_hq_position: Vector3 = layout["player_hq"]
	var enemy_hq_position: Vector3 = layout["enemy_hq"]
	var all_outposts: Array = layout["outposts"]
	var outpost_count: int = clamp(GameState.selected_outpost_count, 1, all_outposts.size())
	var outpost_positions: Array = all_outposts.slice(0, outpost_count)
	var obstacle_positions: Array = layout["obstacles"]

	TerrainVisualGenerator.generate(world_root, player_hq_position, enemy_hq_position,
		outpost_positions, obstacle_positions, MapPresets.get_preset(map_id))

	buildings_root.add_child(create_hq(Constants.Team.PLAYER, player_hq_position))
	buildings_root.add_child(create_hq(Constants.Team.ENEMY, enemy_hq_position))

	for outpost_position in outpost_positions:
		buildings_root.add_child(create_outpost(outpost_position))

	NavigationManager.rebake_navigation(game_root)


## Callers normally rely on GameState.selected_map (set by SkirmishSetup);
## passing a display name like "Iron Basin" overrides it -- for direct
## scene launches, debug commands, or future campaign scripting.
static func _resolve_map_id(map_name: String) -> int:
	if map_name != "":
		var named_id: int = MapPresets.find_by_name(map_name)
		if named_id != -1:
			return named_id
		push_warning("MapGenerator: unknown map name '%s' -- using selected map instead" % map_name)
	return GameState.selected_map


static func create_hq(team: int, position: Vector3) -> Node3D:
	var hq: Node3D = HQ_SCENE.instantiate()
	hq.setup(team, position)
	return hq


static func create_outpost(position: Vector3) -> Node3D:
	var outpost: Node3D = OUTPOST_SCENE.instantiate()
	outpost.position = position
	return outpost
