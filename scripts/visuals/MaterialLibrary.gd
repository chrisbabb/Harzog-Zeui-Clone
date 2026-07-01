class_name MaterialLibrary
extends RefCounted
## Shared library of reusable StandardMaterial3D resources for the game's
## procedural "final-style" visuals (see UnitVisualFactory/BuildingVisualFactory).
## These are procedural final-style placeholder materials meant to be
## replaceable by authored Blender/texture assets later -- the palette and
## roles here (team body/emissive, metals, energy, terrain) are the ones
## final art should match. See ART_DIRECTION.md for the full palette.
##
## Every getter below returns the SAME cached resource on every call, so
## most mesh parts across the whole battlefield can safely share one
## material instance directly (material_override = MaterialLibrary.xxx()).
## The one exception is any part that needs per-instance mutation (a
## flashing hull on damage, a pulsing capture ring) -- callers should
## .duplicate() the returned material before mutating it, so the shared
## original is never touched.

const _PLAYER_BODY_COLOR: Color = Color(0.2, 0.6, 1.0)
const _PLAYER_EMISSIVE_COLOR: Color = Color(0.35, 0.85, 1.0)
const _ENEMY_BODY_COLOR: Color = Color(1.0, 0.3, 0.2)
const _ENEMY_EMISSIVE_COLOR: Color = Color(1.0, 0.55, 0.15)
const _NEUTRAL_BODY_COLOR: Color = Color(0.6, 0.6, 0.6)
const _NEUTRAL_EMISSIVE_COLOR: Color = Color(0.8, 0.82, 0.88)
const _DARK_METAL_COLOR: Color = Color(0.16, 0.18, 0.22)
const _LIGHT_METAL_COLOR: Color = Color(0.58, 0.61, 0.66)
const _TERRAIN_GRASS_COLOR: Color = Color(0.28, 0.36, 0.24)
const _TERRAIN_DIRT_COLOR: Color = Color(0.34, 0.29, 0.21)
const _TERRAIN_ROAD_COLOR: Color = Color(0.15, 0.15, 0.17)
const _ENERGY_BLUE_COLOR: Color = Color(0.35, 0.85, 1.0)
const _ENERGY_RED_COLOR: Color = Color(1.0, 0.35, 0.25)
const _WARNING_YELLOW_COLOR: Color = Color(1.0, 0.85, 0.2)
const _SMOKE_DARK_COLOR: Color = Color(0.12, 0.12, 0.13, 0.55)
const _GLASS_DARK_COLOR: Color = Color(0.05, 0.08, 0.11, 0.65)

const _BODY_ROUGHNESS: float = 0.65
const _BODY_METALLIC: float = 0.15
const _METAL_ROUGHNESS: float = 0.45
const _METAL_METALLIC: float = 0.4
const _EMISSIVE_ENERGY: float = 1.6
const _GLASS_ROUGHNESS: float = 0.1

static var _player_body: StandardMaterial3D
static var _player_emissive: StandardMaterial3D
static var _enemy_body: StandardMaterial3D
static var _enemy_emissive: StandardMaterial3D
static var _neutral_body: StandardMaterial3D
static var _neutral_emissive: StandardMaterial3D
static var _dark_metal: StandardMaterial3D
static var _light_metal: StandardMaterial3D
static var _terrain_grass: StandardMaterial3D
static var _terrain_dirt: StandardMaterial3D
static var _terrain_road: StandardMaterial3D
static var _energy_blue: StandardMaterial3D
static var _energy_red: StandardMaterial3D
static var _warning_yellow: StandardMaterial3D
static var _smoke_dark: StandardMaterial3D
static var _glass_dark: StandardMaterial3D


static func player_body() -> StandardMaterial3D:
	if _player_body == null:
		_player_body = _make_body(_PLAYER_BODY_COLOR)
	return _player_body


static func player_emissive() -> StandardMaterial3D:
	if _player_emissive == null:
		_player_emissive = _make_emissive(_PLAYER_EMISSIVE_COLOR)
	return _player_emissive


static func enemy_body() -> StandardMaterial3D:
	if _enemy_body == null:
		_enemy_body = _make_body(_ENEMY_BODY_COLOR)
	return _enemy_body


static func enemy_emissive() -> StandardMaterial3D:
	if _enemy_emissive == null:
		_enemy_emissive = _make_emissive(_ENEMY_EMISSIVE_COLOR)
	return _enemy_emissive


static func neutral_body() -> StandardMaterial3D:
	if _neutral_body == null:
		_neutral_body = _make_body(_NEUTRAL_BODY_COLOR)
	return _neutral_body


static func neutral_emissive() -> StandardMaterial3D:
	if _neutral_emissive == null:
		_neutral_emissive = _make_emissive(_NEUTRAL_EMISSIVE_COLOR)
	return _neutral_emissive


static func dark_metal() -> StandardMaterial3D:
	if _dark_metal == null:
		_dark_metal = _make_metal(_DARK_METAL_COLOR)
	return _dark_metal


static func light_metal() -> StandardMaterial3D:
	if _light_metal == null:
		_light_metal = _make_metal(_LIGHT_METAL_COLOR)
	return _light_metal


static func terrain_grass() -> StandardMaterial3D:
	if _terrain_grass == null:
		_terrain_grass = _make_matte(_TERRAIN_GRASS_COLOR)
	return _terrain_grass


static func terrain_dirt() -> StandardMaterial3D:
	if _terrain_dirt == null:
		_terrain_dirt = _make_matte(_TERRAIN_DIRT_COLOR)
	return _terrain_dirt


static func terrain_road() -> StandardMaterial3D:
	if _terrain_road == null:
		_terrain_road = _make_matte(_TERRAIN_ROAD_COLOR)
	return _terrain_road


static func energy_blue() -> StandardMaterial3D:
	if _energy_blue == null:
		_energy_blue = _make_emissive(_ENERGY_BLUE_COLOR)
	return _energy_blue


static func energy_red() -> StandardMaterial3D:
	if _energy_red == null:
		_energy_red = _make_emissive(_ENERGY_RED_COLOR)
	return _energy_red


static func warning_yellow() -> StandardMaterial3D:
	if _warning_yellow == null:
		_warning_yellow = _make_emissive(_WARNING_YELLOW_COLOR)
	return _warning_yellow


static func smoke_dark() -> StandardMaterial3D:
	if _smoke_dark == null:
		_smoke_dark = StandardMaterial3D.new()
		_smoke_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_dark.albedo_color = _SMOKE_DARK_COLOR
	return _smoke_dark


static func glass_dark() -> StandardMaterial3D:
	if _glass_dark == null:
		_glass_dark = StandardMaterial3D.new()
		_glass_dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_dark.albedo_color = _GLASS_DARK_COLOR
		_glass_dark.roughness = _GLASS_ROUGHNESS
	return _glass_dark


## Team-keyed convenience lookups, so factories don't need to branch on
## Constants.Team.* at every call site.
static func body_for_team(team: int) -> StandardMaterial3D:
	if team == Constants.Team.PLAYER:
		return player_body()
	elif team == Constants.Team.ENEMY:
		return enemy_body()
	return neutral_body()


static func emissive_for_team(team: int) -> StandardMaterial3D:
	if team == Constants.Team.PLAYER:
		return player_emissive()
	elif team == Constants.Team.ENEMY:
		return enemy_emissive()
	return neutral_emissive()


static func _make_body(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = _BODY_ROUGHNESS
	material.metallic = _BODY_METALLIC
	return material


static func _make_metal(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = _METAL_ROUGHNESS
	material.metallic = _METAL_METALLIC
	return material


static func _make_matte(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


static func _make_emissive(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = _EMISSIVE_ENERGY
	return material
