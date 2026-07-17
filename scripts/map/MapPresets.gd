class_name MapPresets
extends RefCounted
## Static per-map identity and dressing data for the skirmish maps.
## MapGenerator.MAP_LAYOUTS owns each map's gameplay layout (HQ, outpost,
## and obstacle positions); this module owns everything about how a map is
## described and dressed: the display name/description/difficulty that
## SkirmishSetup previews, the terrain palette and zone weighting, road
## color, cliff density, per-map scatter-decoration recipe, hand-placed set
## pieces, and which center feature TerrainVisualGenerator builds. Adding a
## map is then one MAP_LAYOUTS entry plus one PRESETS entry -- no code
## changes in the generators.
##
## Fixed-decoration positions are hand-verified against MAP_LAYOUTS to sit
## clear of every HQ/outpost/obstacle (see TerrainVisualGenerator's
## defensive re-check, which protects against future layout edits).

const PRESETS: Dictionary = {
	# Green-gray proving ground: bright grass, a clean pale road network,
	# power nodes strung along the frontline, and a glowing central causeway.
	Constants.MapPreset.GREEN_DIVIDE: {
		"name": "Green Divide",
		"description": "Open grasslands split by a glowing central causeway. Clear roads and a balanced outpost spread make this the standard proving ground.",
		"difficulty": "Recruit",
		"default_outposts": 9,
		"zone_colors": {
			"grass": Color(0.3, 0.38, 0.25),
			"dirt": Color(0.36, 0.31, 0.22),
			"metal": Color(0.18, 0.19, 0.21),
			"scorched": Color(0.12, 0.1, 0.09),
		},
		"zone_weights": {
			"scorched_base": 0.03,
			"scorched_center_bonus": 0.1,
			"dirt": 0.22,
			"metal": 0.08,
		},
		"road_color": Color(0.19, 0.19, 0.21),
		"cliff_count": 4,
		"decoration_counts": {
			"rock_cluster": 6,
			"power_node": 6,
			"crate_stack": 4,
			"antenna": 2,
			"energy_pylon": 2,
			"wreck": 2,
			"scorch_mark": 3,
		},
		# Power nodes marching along the central corridor, so the map's
		# "scattered power grid" identity is guaranteed even on unlucky
		# scatter rolls.
		"fixed_decorations": [
			{"kind": "power_node", "position": Vector3(-30.0, 0.0, 2.0)},
			{"kind": "power_node", "position": Vector3(30.0, 0.0, 4.0)},
			{"kind": "power_node", "position": Vector3(0.0, 0.0, 22.0)},
			{"kind": "power_node", "position": Vector3(-2.0, 0.0, -24.0)},
		],
		"center_feature": "bridge_band",
	},
	# Industrial crater floor: waste-gray ground, rust streaks, heavy plate
	# zones, darker roads, and machinery set pieces ringing the basin.
	Constants.MapPreset.IRON_BASIN: {
		"name": "Iron Basin",
		"description": "A machine graveyard inside an industrial crater. The rich middle outposts decide the match -- if you can hold their chokepoints.",
		"difficulty": "Veteran",
		"default_outposts": 7,
		"zone_colors": {
			"grass": Color(0.24, 0.23, 0.2),
			"dirt": Color(0.3, 0.22, 0.16),
			"metal": Color(0.13, 0.14, 0.17),
			"scorched": Color(0.09, 0.08, 0.08),
		},
		"zone_weights": {
			"scorched_base": 0.06,
			"scorched_center_bonus": 0.12,
			"dirt": 0.24,
			"metal": 0.3,
		},
		"road_color": Color(0.1, 0.11, 0.13),
		"cliff_count": 6,
		"decoration_counts": {
			"metal_plate": 5,
			"pipe_run": 4,
			"glow_vent": 4,
			"broken_machine": 4,
			"antenna": 4,
			"crate_stack": 3,
			"rock_cluster": 3,
			"scorch_mark": 3,
			"wreck": 2,
		},
		# Vents breathing inside the basin, pipes/plates/machines around its
		# rim -- the crater reads industrial from any camera position.
		"fixed_decorations": [
			{"kind": "glow_vent", "position": Vector3(-20.0, 0.0, 4.0)},
			{"kind": "glow_vent", "position": Vector3(22.0, 0.0, 6.0)},
			{"kind": "glow_vent", "position": Vector3(0.0, 0.0, 8.0)},
			{"kind": "pipe_run", "position": Vector3(-40.0, 0.0, -14.0)},
			{"kind": "pipe_run", "position": Vector3(40.0, 0.0, 16.0)},
			{"kind": "metal_plate", "position": Vector3(0.0, 0.0, -16.0)},
			{"kind": "metal_plate", "position": Vector3(10.0, 0.0, 26.0)},
			{"kind": "broken_machine", "position": Vector3(-36.0, 0.0, 28.0)},
			{"kind": "broken_machine", "position": Vector3(36.0, 0.0, -24.0)},
		],
		"center_feature": "crater",
	},
	# Burned-out frontline corridor: ash ground, heavy scorching, wrecks and
	# warning lights along the no-man's-land scar at mid-field.
	Constants.MapPreset.ASH_LINE: {
		"name": "Ash Line",
		"description": "A scorched frontline corridor. Few outposts, short supply lines, and constant contact -- matches here end fast, one way or the other.",
		"difficulty": "Elite",
		"default_outposts": 5,
		"zone_colors": {
			"grass": Color(0.2, 0.18, 0.17),
			"dirt": Color(0.22, 0.16, 0.12),
			"metal": Color(0.15, 0.15, 0.16),
			"scorched": Color(0.07, 0.06, 0.06),
		},
		"zone_weights": {
			"scorched_base": 0.22,
			"scorched_center_bonus": 0.3,
			"dirt": 0.24,
			"metal": 0.1,
		},
		"road_color": Color(0.12, 0.11, 0.11),
		"cliff_count": 3,
		"decoration_counts": {
			"wreck": 7,
			"scorch_mark": 8,
			"warning_light": 5,
			"ruined_structure": 3,
			"smoke_column": 2,
			"rock_cluster": 4,
			"crate_stack": 2,
		},
		# Warning lights bracketing the frontline scar, ruins pushed to each
		# side's rear, and two smoke columns rising off no-man's-land.
		"fixed_decorations": [
			{"kind": "warning_light", "position": Vector3(0.0, 0.0, -24.0)},
			{"kind": "warning_light", "position": Vector3(0.0, 0.0, 26.0)},
			{"kind": "warning_light", "position": Vector3(14.0, 0.0, 0.0)},
			{"kind": "warning_light", "position": Vector3(-14.0, 0.0, 2.0)},
			{"kind": "ruined_structure", "position": Vector3(-70.0, 0.0, 20.0)},
			{"kind": "ruined_structure", "position": Vector3(72.0, 0.0, -18.0)},
			{"kind": "ruined_structure", "position": Vector3(-50.0, 0.0, 28.0)},
			{"kind": "smoke_column", "position": Vector3(6.0, 0.0, 34.0)},
			{"kind": "smoke_column", "position": Vector3(-4.0, 0.0, -30.0)},
		],
		"center_feature": "front_scar",
	},
}


static func get_preset(map_id: int) -> Dictionary:
	return PRESETS.get(map_id, PRESETS[Constants.MapPreset.GREEN_DIVIDE])


## Ordered to match Constants.MapPreset's values, because SkirmishSetup's
## map OptionButton index doubles as the enum value (see configure_skirmish).
static func all_map_ids() -> Array[int]:
	return [
		Constants.MapPreset.GREEN_DIVIDE,
		Constants.MapPreset.IRON_BASIN,
		Constants.MapPreset.ASH_LINE,
	]


## Case-insensitive display-name lookup ("iron basin" -> IRON_BASIN), for
## callers that select a map by name instead of enum value -- direct scene
## launches, debug commands, or future campaign scripting. Returns -1 when
## no map matches, so callers can fall back to GameState.selected_map.
static func find_by_name(map_name: String) -> int:
	for map_id in PRESETS.keys():
		var preset_name: String = PRESETS[map_id]["name"]
		if preset_name.nocasecmp_to(map_name) == 0:
			return map_id
	return -1
