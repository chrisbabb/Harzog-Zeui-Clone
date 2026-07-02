extends Control
## One drifting layer of scrolling grid lines or dots (MainMenu.tscn uses a
## single faint one as a tactical-readout overlay above the 3D title
## diorama; stack several at different spacing/speed/alpha for a parallax
## depth effect). Loops seamlessly by wrapping the draw offset modulo the
## cell spacing -- an animated layer with no shader and no imported texture.

@export var spacing: float = 100.0
@export var scroll_velocity: Vector2 = Vector2(-10.0, -5.0)
@export var line_color: Color = Color(0.35, 0.85, 1.0, 0.1)
@export var line_width: float = 1.0
@export var draw_dots: bool = false
@export var dot_radius: float = 1.5

const _REDRAW_INTERVAL: float = 1.0 / 30.0

var _offset: Vector2 = Vector2.ZERO
var _redraw_timer: float = 0.0


func _process(delta: float) -> void:
	_offset += scroll_velocity * delta
	_offset.x = fmod(_offset.x, spacing)
	_offset.y = fmod(_offset.y, spacing)

	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = _REDRAW_INTERVAL
		queue_redraw()


func _draw() -> void:
	var start_x: float = fmod(_offset.x, spacing) - spacing
	var start_y: float = fmod(_offset.y, spacing) - spacing

	if draw_dots:
		var gx: float = start_x
		while gx < size.x + spacing:
			var gy: float = start_y
			while gy < size.y + spacing:
				draw_circle(Vector2(gx, gy), dot_radius, line_color)
				gy += spacing
			gx += spacing
		return

	var x: float = start_x
	while x < size.x + spacing:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), line_color, line_width)
		x += spacing

	var y: float = start_y
	while y < size.y + spacing:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, line_width)
		y += spacing
