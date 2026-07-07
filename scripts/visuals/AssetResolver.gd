class_name AssetResolver
extends RefCounted
## Final-asset loading with procedural fallback -- the single entry point
## for unit/building visuals. Looks for hand-authored final assets under
## assets/art/final/{units,buildings}/ and instantiates them when present;
## otherwise generates the procedural placeholder via UnitVisualFactory /
## BuildingVisualFactory. This lets finished art land one file at a time
## (and be rolled back by deleting a file) without touching gameplay code.
## The authoring contract final assets must follow -- node names, sizes,
## orientation, import settings -- is documented in ASSET_PIPELINE.md.
##
## On a successfully loaded final asset, team materials are applied to the
## designated team-color slots (see _apply_team_slots): mesh nodes named
## TeamColor / TeamColor_01 / ... get the team body material, and
## TeamGlow* / EmissiveStrip* nodes get the team emissive. Assets missing
## those nodes still load fine -- the skip is logged once per asset, never
## per instance, and nothing crashes.

const FINAL_ART_ROOT: String = "res://assets/art/final"
const UNITS_SUBDIR: String = "units"
const BUILDINGS_SUBDIR: String = "buildings"

## Checked in order: a .tscn wrapper (lets artists tune materials/offsets
## in-editor) wins over the raw .glb export next to it.
const CANDIDATE_EXTENSIONS: Array[String] = ["tscn", "glb"]

## One-shot warning latches keyed by asset path, so a problem asset that
## spawns sixty times (units) or every match (buildings) warns exactly once
## per session instead of flooding the log.
static var _warned_paths: Dictionary = {}


# ---------------------------------------------------------------------------
# Path resolution / existence checks
# ---------------------------------------------------------------------------

## Resolved path of the final asset for this unit type, or "" when no final
## asset exists yet. File base names are the lowercase Constants.UnitType
## keys (e.g. SCOUT_BUGGY -> scout_buggy.glb).
static func get_unit_asset_path(unit_type: int) -> String:
	return _resolve_path(UNITS_SUBDIR, Constants.UnitType.keys()[unit_type].to_lower())


## Resolved path of the final asset for this building type ("hq"/"outpost"),
## or "" when no final asset exists yet.
static func get_building_asset_path(building_type: int) -> String:
	return _resolve_path(BUILDINGS_SUBDIR, Constants.BuildingType.keys()[building_type].to_lower())


static func has_final_unit_asset(unit_type: int) -> bool:
	return get_unit_asset_path(unit_type) != ""


static func has_final_building_asset(building_type: int) -> bool:
	return get_building_asset_path(building_type) != ""


# ---------------------------------------------------------------------------
# Visual instantiation (final asset -> procedural fallback)
# ---------------------------------------------------------------------------

## The visual root for a unit: the final asset if one exists and loads,
## otherwise UnitVisualFactory's procedural placeholder. Callers treat the
## result identically either way (UnitAnimator/DamageStateController look
## named parts up defensively).
static func instantiate_unit_visual(unit_type: int, team: int) -> Node3D:
	var final_visual: Node3D = _instantiate_final(get_unit_asset_path(unit_type), team)
	if final_visual != null:
		return final_visual
	return UnitVisualFactory.create_visual(unit_type, team)


## The visual root for an HQ or outpost, with the same fallback contract as
## instantiate_unit_visual.
static func instantiate_building_visual(building_type: int, team: int) -> Node3D:
	var final_visual: Node3D = _instantiate_final(get_building_asset_path(building_type), team)
	if final_visual != null:
		return final_visual
	if building_type == Constants.BuildingType.HQ:
		return BuildingVisualFactory.create_hq_visual(team)
	return BuildingVisualFactory.create_outpost_visual(team)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _resolve_path(subdir: String, file_base: String) -> String:
	for extension in CANDIDATE_EXTENSIONS:
		var path: String = "%s/%s/%s.%s" % [FINAL_ART_ROOT, subdir, file_base, extension]
		if ResourceLoader.exists(path):
			return path
	return ""


## Instantiates the resolved final asset and applies team slots, or returns
## null (warning once) on any failure so the caller falls back to the
## procedural build -- a broken asset file can never crash a spawn.
static func _instantiate_final(path: String, team: int) -> Node3D:
	if path == "":
		return null

	var scene: PackedScene = ResourceLoader.load(path) as PackedScene
	if scene == null:
		_warn_once(path, "failed to load as a PackedScene; using the procedural fallback")
		return null

	var instance: Node = scene.instantiate()
	if not (instance is Node3D):
		if instance != null:
			instance.free()
		_warn_once(path, "root is not a Node3D; using the procedural fallback")
		return null

	var visual := instance as Node3D
	visual.name = "Visual"
	_apply_team_slots(visual, team, path)
	return visual


## Applies team materials to the designated slots: every MeshInstance3D
## whose name starts with "TeamColor" (covers TeamColor, TeamColor_01, ...)
## gets the team body material; "TeamGlow*" and "EmissiveStrip*" get the
## team emissive. One duplicated material instance is shared across a
## visual's slots (so they tint as a set, and per-instance mutation stays
## safe); MaterialLibrary's cached originals are never touched. An asset
## with none of these nodes just logs one warning and renders as authored.
static func _apply_team_slots(visual: Node3D, team: int, path: String) -> void:
	var body_material: StandardMaterial3D = null
	var emissive_material: StandardMaterial3D = null
	var found_any: bool = false

	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.name.begins_with("TeamColor"):
			if body_material == null:
				body_material = MaterialLibrary.body_for_team(team).duplicate()
			mesh.material_override = body_material
			found_any = true
		elif mesh.name.begins_with("TeamGlow") or mesh.name.begins_with("EmissiveStrip"):
			if emissive_material == null:
				emissive_material = MaterialLibrary.emissive_for_team(team).duplicate()
			mesh.material_override = emissive_material
			found_any = true

	if not found_any:
		_warn_once(path, "has no TeamColor/TeamColor_01/TeamGlow/EmissiveStrip nodes; team tint skipped")


static func _warn_once(path: String, message: String) -> void:
	if _warned_paths.has(path):
		return
	_warned_paths[path] = true
	push_warning("AssetResolver: %s %s." % [path, message])
