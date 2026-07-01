class_name UIThemeFactory
extends RefCounted
## Shared runtime UI helpers for the Skyforge Command sci-fi tactical theme.
## Most of the look lives in the static assets/ui/SkyforgeTheme.tres resource
## (applied globally via project.godot's gui/theme/custom); this class covers
## what a single static Theme can't -- per-team accent recoloring, dynamic
## StyleBoxFlat resources for data-driven elements (unit cards, command
## rows), and the shared pulse/selection-border Tween animations reused
## across HUD, BuildMenu, CommandMenu, and Minimap. Mirrors MaterialLibrary's
## stateless static-utility pattern.

const CYAN_ACCENT: Color = Color(0.35, 0.85, 1.0)
const ORANGE_ACCENT: Color = Color(1.0, 0.55, 0.15)
const NEUTRAL_ACCENT: Color = Color(0.75, 0.78, 0.85)
const WARNING_COLOR: Color = Color(1.0, 0.85, 0.2)
const DANGER_COLOR: Color = Color(1.0, 0.3, 0.25)
const SUCCESS_COLOR: Color = Color(0.4, 0.95, 0.6)

const CARD_BG: Color = Color(0.07, 0.1, 0.15, 0.85)
const CARD_BG_SELECTED: Color = Color(0.1, 0.15, 0.22, 0.92)
const CARD_BG_DISABLED: Color = Color(0.05, 0.06, 0.08, 0.5)

const PULSE_SPEED: float = 3.5
const SELECTION_PULSE_SPEED: float = 2.2


static func team_accent(team: int) -> Color:
	if team == Constants.Team.PLAYER:
		return CYAN_ACCENT
	elif team == Constants.Team.ENEMY:
		return ORANGE_ACCENT
	return NEUTRAL_ACCENT


## Re-tints a Panel's border to this HUD instance's own team accent --
## duplicates the style first so the shared theme resource (and every other
## Panel using it) is never mutated. Only meaningfully changes anything for
## ENEMY (local multiplayer's P2 HUD); PLAYER/NEUTRAL already match the
## theme's default cyan.
static func apply_team_accent(panel: Panel, team: int) -> void:
	if team == Constants.Team.PLAYER:
		return
	var base_style: StyleBox = panel.get_theme_stylebox("panel")
	if base_style == null or not (base_style is StyleBoxFlat):
		return
	var style: StyleBoxFlat = (base_style as StyleBoxFlat).duplicate()
	style.border_color = Color(team_accent(team), style.border_color.a)
	panel.add_theme_stylebox_override("panel", style)


## A small dark card-style StyleBoxFlat for dynamically-built elements
## (BuildMenu unit cards, CommandMenu order rows) that can't be pre-baked
## into the static theme since their count/content is data-driven.
static func make_card_style(accent_color: Color, selected: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG_DISABLED if disabled else (CARD_BG_SELECTED if selected else CARD_BG)
	style.border_width_left = 3 if selected else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.25 if disabled else (0.95 if selected else 0.45))
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style


## Starts an infinitely-looping border-alpha "breathing" animation on a
## card's StyleBoxFlat, used to mark the currently-selected BuildMenu card.
## Contract: `base_style` must already be the instance actively applied to
## the control (e.g. via add_theme_stylebox_override("panel", base_style))
## -- this mutates that same resource in place each frame rather than
## swapping styles, since a StyleBoxFlat is a Resource (reference type).
static func animate_selection_pulse(control: CanvasItem, base_style: StyleBoxFlat) -> Tween:
	var tween: Tween = control.create_tween()
	tween.set_loops()
	var bright: Color = base_style.border_color
	var dim := Color(bright.r, bright.g, bright.b, bright.a * 0.35)
	tween.tween_method(
		func(c: Color) -> void: base_style.border_color = c,
		bright, dim, 1.0 / SELECTION_PULSE_SPEED
	).set_trans(Tween.TRANS_SINE)
	tween.tween_method(
		func(c: Color) -> void: base_style.border_color = c,
		dim, bright, 1.0 / SELECTION_PULSE_SPEED
	).set_trans(Tween.TRANS_SINE)
	return tween


## A continuous, gentle "alive" pulse (Minimap under-attack ring, enemy HQ
## objective marker, HUD low-fuel/ammo bars, MainMenu focused button) --
## loops forever until the caller kills the returned Tween (e.g. when the
## underlying condition stops applying).
static func continuous_pulse(control: CanvasItem, low_alpha: float = 0.4, high_alpha: float = 1.0, speed: float = 2.0) -> Tween:
	var tween: Tween = control.create_tween()
	tween.set_loops()
	tween.tween_property(control, "modulate:a", high_alpha, 1.0 / speed).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate:a", low_alpha, 1.0 / speed).set_trans(Tween.TRANS_SINE)
	return tween
