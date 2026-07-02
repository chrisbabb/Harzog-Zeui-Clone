class_name TacticalIcon
extends Control
## A small reusable icon widget for the Skyforge Command tactical UI --
## draws one of IconFactory's vector-style unit/order/building icons,
## team-colored, scaled to whatever size this Control is given. Used by
## BuildMenu cards, CommandMenu rows, and HUD's carried-unit display.
## (Minimap draws IconFactory icons directly in its own _draw() instead of
## instancing this node, since it's already doing custom immediate-mode
## drawing there.)
##
## Callers are responsible for sizing (custom_minimum_size) and
## mouse_filter, matching the plain ColorRect swatches this replaces.

@export var icon_type: int = IconFactory.IconType.TANK:
	set(value):
		icon_type = value
		queue_redraw()

## Team whose accent color (UIThemeFactory.team_accent) tints the icon,
## unless icon_color_override below is set to a non-transparent color.
@export var team: int = Constants.Team.NEUTRAL:
	set(value):
		team = value
		queue_redraw()

## Explicit color, bypassing the team-accent lookup. Leave at the default
## fully-transparent sentinel to color by team instead.
@export var icon_color_override: Color = Color(0.0, 0.0, 0.0, 0.0):
	set(value):
		icon_color_override = value
		queue_redraw()


func _draw() -> void:
	var color: Color = icon_color_override if icon_color_override.a > 0.0 else UIThemeFactory.team_accent(team)
	IconFactory.draw_icon(self, icon_type, Rect2(Vector2.ZERO, size), color)
