class_name IconFactory
extends RefCounted
## Procedural "vector-style" tactical icon generator for Skyforge Command --
## no external art assets, every icon is a short list of simple shape
## primitives (line/circle/arc/polygon) authored in normalized 0..1 space,
## rendered through one of two backends:
##   - draw_icon(): immediate-mode CanvasItem drawing, for 2D UI. Used
##     directly by TacticalIcon.gd, and by Minimap.gd's building markers.
##   - generate_texture(): rasterizes the same primitives into a cached
##     ImageTexture, for Unit.gd's 3D-world floating order icon (Sprite3D).
## Mirrors MaterialLibrary/UnitVisualFactory/UIThemeFactory's stateless
## static-utility pattern.

enum IconType {
	# Units
	SCOUT_BUGGY, TANK, MISSILE_CRAWLER, ARTILLERY, ANTI_AIR, SUPPLY_TRUCK, CAPTURE_DRONE, HEAVY_WALKER,
	# Orders
	HOLD_POSITION, PATROL_RADIUS, ADVANCE_TO_TARGET, ATTACK_BASE, CAPTURE_OUTPOST, DEFEND_OUTPOST, SUPPORT_ALLIES,
	# Buildings
	HQ, OUTPOST,
}

const DEFAULT_TEXTURE_SIZE: int = 48

static var _texture_cache: Dictionary = {}


# ---------------------------------------------------------------------------
# Constants.* -> IconType mapping
# ---------------------------------------------------------------------------

static func icon_for_unit_type(unit_type: int) -> IconType:
	match unit_type:
		Constants.UnitType.SCOUT_BUGGY: return IconType.SCOUT_BUGGY
		Constants.UnitType.TANK: return IconType.TANK
		Constants.UnitType.MISSILE_CRAWLER: return IconType.MISSILE_CRAWLER
		Constants.UnitType.ARTILLERY: return IconType.ARTILLERY
		Constants.UnitType.ANTI_AIR: return IconType.ANTI_AIR
		Constants.UnitType.SUPPLY_TRUCK: return IconType.SUPPLY_TRUCK
		Constants.UnitType.CAPTURE_DRONE: return IconType.CAPTURE_DRONE
		Constants.UnitType.HEAVY_WALKER: return IconType.HEAVY_WALKER
		_: return IconType.TANK


static func icon_for_order(order: int) -> IconType:
	match order:
		Constants.UnitOrder.HOLD_POSITION: return IconType.HOLD_POSITION
		Constants.UnitOrder.PATROL_RADIUS: return IconType.PATROL_RADIUS
		Constants.UnitOrder.ADVANCE_TO_TARGET: return IconType.ADVANCE_TO_TARGET
		Constants.UnitOrder.ATTACK_BASE: return IconType.ATTACK_BASE
		Constants.UnitOrder.CAPTURE_OUTPOST: return IconType.CAPTURE_OUTPOST
		Constants.UnitOrder.DEFEND_OUTPOST: return IconType.DEFEND_OUTPOST
		Constants.UnitOrder.SUPPORT_ALLIES: return IconType.SUPPORT_ALLIES
		_: return IconType.HOLD_POSITION


static func icon_for_building_type(building_type: int) -> IconType:
	return IconType.HQ if building_type == Constants.BuildingType.HQ else IconType.OUTPOST


# ---------------------------------------------------------------------------
# Shape data -- each icon is a short Array of primitive Dictionaries in
# normalized (0..1, 0..1) space, (0,0) top-left / (1,1) bottom-right. Kept to
# 1-4 primitives per icon so they stay legible at small on-screen sizes.
# ---------------------------------------------------------------------------

static func _shapes_for(icon_type: IconType) -> Array:
	match icon_type:
		IconType.SCOUT_BUGGY:
			return [_poly([Vector2(0.5, 0.14), Vector2(0.82, 0.82), Vector2(0.18, 0.82)])]

		IconType.TANK:
			return [
				_poly([Vector2(0.16, 0.55), Vector2(0.84, 0.55), Vector2(0.84, 0.8), Vector2(0.16, 0.8)]),
				_circle(Vector2(0.5, 0.45), 0.22),
				_line(Vector2(0.5, 0.45), Vector2(0.85, 0.18), 0.08),
			]

		IconType.MISSILE_CRAWLER:
			return [
				_poly([Vector2(0.16, 0.65), Vector2(0.84, 0.65), Vector2(0.84, 0.85), Vector2(0.16, 0.85)]),
				_line(Vector2(0.35, 0.65), Vector2(0.25, 0.18), 0.06),
				_line(Vector2(0.5, 0.65), Vector2(0.5, 0.13), 0.06),
				_line(Vector2(0.65, 0.65), Vector2(0.75, 0.18), 0.06),
			]

		IconType.ARTILLERY:
			return [
				_poly([Vector2(0.25, 0.6), Vector2(0.75, 0.6), Vector2(0.75, 0.85), Vector2(0.25, 0.85)]),
				_line(Vector2(0.5, 0.62), Vector2(0.92, 0.08), 0.075),
			]

		IconType.ANTI_AIR:
			return [
				_poly([Vector2(0.25, 0.65), Vector2(0.75, 0.65), Vector2(0.75, 0.85), Vector2(0.25, 0.85)]),
				_line(Vector2(0.42, 0.65), Vector2(0.3, 0.14), 0.06),
				_line(Vector2(0.58, 0.65), Vector2(0.7, 0.14), 0.06),
			]

		IconType.SUPPLY_TRUCK:
			return [
				_poly([Vector2(0.4, 0.14), Vector2(0.6, 0.14), Vector2(0.6, 0.86), Vector2(0.4, 0.86)]),
				_poly([Vector2(0.14, 0.4), Vector2(0.86, 0.4), Vector2(0.86, 0.6), Vector2(0.14, 0.6)]),
			]

		IconType.CAPTURE_DRONE:
			return [
				_circle(Vector2(0.5, 0.5), 0.35, false, 0.08),
				_circle(Vector2(0.5, 0.5), 0.1),
			]

		IconType.HEAVY_WALKER:
			return [
				_poly([Vector2(0.2, 0.18), Vector2(0.8, 0.18), Vector2(0.8, 0.55), Vector2(0.2, 0.55)]),
				_poly([Vector2(0.25, 0.55), Vector2(0.4, 0.55), Vector2(0.4, 0.86), Vector2(0.25, 0.86)]),
				_poly([Vector2(0.6, 0.55), Vector2(0.75, 0.55), Vector2(0.75, 0.86), Vector2(0.6, 0.86)]),
			]

		IconType.HOLD_POSITION:
			return [_poly([
				Vector2(0.5, 0.13), Vector2(0.83, 0.28), Vector2(0.83, 0.55),
				Vector2(0.5, 0.89), Vector2(0.17, 0.55), Vector2(0.17, 0.28),
			])]

		IconType.PATROL_RADIUS:
			return [
				_arc(Vector2(0.5, 0.5), 0.32, -30.0, 250.0, 0.07),
				_poly([Vector2(0.72, 0.2), Vector2(0.88, 0.22), Vector2(0.78, 0.36)]),
			]

		IconType.ADVANCE_TO_TARGET:
			return [_poly([
				Vector2(0.5, 0.11), Vector2(0.86, 0.55), Vector2(0.63, 0.55), Vector2(0.63, 0.89),
				Vector2(0.37, 0.89), Vector2(0.37, 0.55), Vector2(0.14, 0.55),
			])]

		IconType.ATTACK_BASE:
			return [
				_circle(Vector2(0.5, 0.5), 0.36, false, 0.06),
				_circle(Vector2(0.5, 0.5), 0.21, false, 0.06),
				_circle(Vector2(0.5, 0.5), 0.07),
			]

		IconType.CAPTURE_OUTPOST:
			return [
				_line(Vector2(0.3, 0.14), Vector2(0.3, 0.87), 0.06),
				_poly([Vector2(0.3, 0.17), Vector2(0.78, 0.32), Vector2(0.3, 0.47)]),
			]

		IconType.DEFEND_OUTPOST:
			return [
				_poly([
					Vector2(0.5, 0.11), Vector2(0.73, 0.22), Vector2(0.73, 0.4),
					Vector2(0.5, 0.58), Vector2(0.27, 0.4), Vector2(0.27, 0.22),
				]),
				_poly([Vector2(0.37, 0.58), Vector2(0.63, 0.58), Vector2(0.63, 0.88), Vector2(0.37, 0.88)]),
			]

		IconType.SUPPORT_ALLIES:
			return [
				_circle(Vector2(0.26, 0.5), 0.14),
				_circle(Vector2(0.74, 0.5), 0.14),
				_line(Vector2(0.26, 0.5), Vector2(0.74, 0.5), 0.06),
			]

		IconType.HQ:
			return [
				_poly([
					Vector2(0.5, 0.12), Vector2(0.87, 0.38), Vector2(0.72, 0.86),
					Vector2(0.28, 0.86), Vector2(0.13, 0.38),
				]),
				_poly([Vector2(0.5, 0.4), Vector2(0.63, 0.55), Vector2(0.5, 0.7), Vector2(0.37, 0.55)], false, 0.045),
			]

		IconType.OUTPOST:
			return [
				_circle(Vector2(0.5, 0.82), 0.3, false, 0.06),
				_poly([Vector2(0.27, 0.14), Vector2(0.73, 0.14), Vector2(0.73, 0.28), Vector2(0.27, 0.28)]),
				_poly([Vector2(0.38, 0.28), Vector2(0.62, 0.28), Vector2(0.62, 0.8), Vector2(0.38, 0.8)]),
			]

		_:
			return [_circle(Vector2(0.5, 0.5), 0.3)]


static func _poly(points: Array, filled: bool = true, width: float = 0.05) -> Dictionary:
	return {"t": "poly", "pts": points, "filled": filled, "w": width}


static func _circle(center: Vector2, radius: float, filled: bool = true, width: float = 0.05) -> Dictionary:
	return {"t": "circle", "c": center, "r": radius, "filled": filled, "w": width}


static func _line(a: Vector2, b: Vector2, width: float) -> Dictionary:
	return {"t": "line", "a": a, "b": b, "w": width}


static func _arc(center: Vector2, radius: float, from_deg: float, to_deg: float, width: float) -> Dictionary:
	return {"t": "arc", "c": center, "r": radius, "from": from_deg, "to": to_deg, "w": width}


# ---------------------------------------------------------------------------
# CanvasItem backend -- 2D UI (TacticalIcon.gd, Minimap.gd building markers)
# ---------------------------------------------------------------------------

## Draws icon_type's shapes into rect, uniformly scaled to rect's smaller
## dimension (and centered) so icons never distort in a non-square rect.
static func draw_icon(ci: CanvasItem, icon_type: int, rect: Rect2, color: Color) -> void:
	var icon_scale: float = min(rect.size.x, rect.size.y)
	var offset: Vector2 = rect.position + (rect.size - Vector2(icon_scale, icon_scale)) * 0.5
	for shape in _shapes_for(icon_type):
		_draw_shape(ci, shape, offset, icon_scale, color)


static func _draw_shape(ci: CanvasItem, shape: Dictionary, offset: Vector2, icon_scale: float, color: Color) -> void:
	match shape["t"]:
		"poly":
			var pts: PackedVector2Array = PackedVector2Array()
			for p in shape["pts"]:
				pts.append(offset + (p as Vector2) * icon_scale)
			if shape["filled"]:
				ci.draw_colored_polygon(pts, color)
			else:
				var closed: PackedVector2Array = pts.duplicate()
				closed.append(pts[0])
				ci.draw_polyline(closed, color, shape["w"] * icon_scale, true)

		"circle":
			var center: Vector2 = offset + (shape["c"] as Vector2) * icon_scale
			if shape["filled"]:
				ci.draw_circle(center, shape["r"] * icon_scale, color)
			else:
				ci.draw_arc(center, shape["r"] * icon_scale, 0.0, TAU, 24, color, shape["w"] * icon_scale)

		"line":
			var a: Vector2 = offset + (shape["a"] as Vector2) * icon_scale
			var b: Vector2 = offset + (shape["b"] as Vector2) * icon_scale
			ci.draw_line(a, b, color, shape["w"] * icon_scale, true)

		"arc":
			var center: Vector2 = offset + (shape["c"] as Vector2) * icon_scale
			ci.draw_arc(
				center, shape["r"] * icon_scale,
				deg_to_rad(shape["from"]), deg_to_rad(shape["to"]),
				24, color, shape["w"] * icon_scale
			)


# ---------------------------------------------------------------------------
# Image/texture backend -- 3D world-space icons (Unit.gd's floating order
# icon, rendered via Sprite3D since Label3D can't display a texture).
# ---------------------------------------------------------------------------

## Rasterizes icon_type's shapes into an size x size ImageTexture, cached by
## (icon_type, color, size) so repeated calls for the same combination
## (extremely common -- e.g. every same-team unit on the same order) reuse
## one texture instead of re-rasterizing.
static func generate_texture(icon_type: int, color: Color, size: int = DEFAULT_TEXTURE_SIZE) -> ImageTexture:
	var key: String = "%d|%s|%d" % [icon_type, color.to_html(), size]
	if _texture_cache.has(key):
		return _texture_cache[key]

	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var icon_scale: float = float(size)
	for shape in _shapes_for(icon_type):
		_rasterize_shape(image, shape, icon_scale, color)

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


static func _rasterize_shape(image: Image, shape: Dictionary, icon_scale: float, color: Color) -> void:
	match shape["t"]:
		"poly":
			var pts: PackedVector2Array = PackedVector2Array()
			for p in shape["pts"]:
				pts.append((p as Vector2) * icon_scale)
			if shape["filled"]:
				_rasterize_filled_polygon(image, pts, color)
			else:
				var width: float = shape["w"] * icon_scale
				for i in range(pts.size()):
					_rasterize_thick_line(image, pts[i], pts[(i + 1) % pts.size()], width, color)

		"circle":
			var center: Vector2 = (shape["c"] as Vector2) * icon_scale
			var radius: float = shape["r"] * icon_scale
			if shape["filled"]:
				_rasterize_filled_circle(image, center, radius, color)
			else:
				_rasterize_ring(image, center, radius, shape["w"] * icon_scale, color)

		"line":
			var a: Vector2 = (shape["a"] as Vector2) * icon_scale
			var b: Vector2 = (shape["b"] as Vector2) * icon_scale
			_rasterize_thick_line(image, a, b, shape["w"] * icon_scale, color)

		"arc":
			var center: Vector2 = (shape["c"] as Vector2) * icon_scale
			_rasterize_arc(image, center, shape["r"] * icon_scale, shape["from"], shape["to"], shape["w"] * icon_scale, color)


static func _rasterize_filled_polygon(image: Image, pts: PackedVector2Array, color: Color) -> void:
	var bounds: Array = _pixel_bounds(pts, 0.0, image.get_width(), image.get_height())
	for y in range(bounds[1], bounds[3] + 1):
		for x in range(bounds[0], bounds[2] + 1):
			if _point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				image.set_pixel(x, y, color)


static func _point_in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var j: int = poly.size() - 1
	for i in range(poly.size()):
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		if (pi.y > p.y) != (pj.y > p.y):
			var x_intersect: float = (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x
			if p.x < x_intersect:
				inside = not inside
		j = i
	return inside


static func _rasterize_filled_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var bounds: Array = _pixel_bounds_radius(center, radius, image.get_width(), image.get_height())
	var r_sq: float = radius * radius
	for y in range(bounds[1], bounds[3] + 1):
		for x in range(bounds[0], bounds[2] + 1):
			if Vector2(x + 0.5, y + 0.5).distance_squared_to(center) <= r_sq:
				image.set_pixel(x, y, color)


static func _rasterize_ring(image: Image, center: Vector2, radius: float, width: float, color: Color) -> void:
	var bounds: Array = _pixel_bounds_radius(center, radius + width * 0.5, image.get_width(), image.get_height())
	var half_w: float = width * 0.5
	for y in range(bounds[1], bounds[3] + 1):
		for x in range(bounds[0], bounds[2] + 1):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if absf(d - radius) <= half_w:
				image.set_pixel(x, y, color)


static func _rasterize_thick_line(image: Image, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var half_w: float = width * 0.5
	var bounds: Array = _pixel_bounds(PackedVector2Array([a, b]), half_w, image.get_width(), image.get_height())
	for y in range(bounds[1], bounds[3] + 1):
		for x in range(bounds[0], bounds[2] + 1):
			if _distance_to_segment(Vector2(x + 0.5, y + 0.5), a, b) <= half_w:
				image.set_pixel(x, y, color)


static func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _rasterize_arc(image: Image, center: Vector2, radius: float, from_deg: float, to_deg: float, width: float, color: Color) -> void:
	var bounds: Array = _pixel_bounds_radius(center, radius + width * 0.5, image.get_width(), image.get_height())
	var half_w: float = width * 0.5
	for y in range(bounds[1], bounds[3] + 1):
		for x in range(bounds[0], bounds[2] + 1):
			var point := Vector2(x + 0.5, y + 0.5)
			var d: float = point.distance_to(center)
			if absf(d - radius) > half_w:
				continue
			var angle_deg: float = rad_to_deg((point - center).angle())
			if _angle_in_range(angle_deg, from_deg, to_deg):
				image.set_pixel(x, y, color)


static func _angle_in_range(angle_deg: float, from_deg: float, to_deg: float) -> bool:
	var a: float = fposmod(angle_deg - from_deg, 360.0)
	var span: float = fposmod(to_deg - from_deg, 360.0)
	return a <= span


## Pixel-space integer bounding box (clamped to the image) for a set of
## points plus an extra margin (e.g. half a line/ring width), used to keep
## every rasterizer from scanning the whole image for a small shape.
static func _pixel_bounds(pts: PackedVector2Array, margin: float, width: int, height: int) -> Array:
	var min_x: float = pts[0].x
	var min_y: float = pts[0].y
	var max_x: float = pts[0].x
	var max_y: float = pts[0].y
	for p in pts:
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	var x0: int = max(0, int(floor(min_x - margin)))
	var y0: int = max(0, int(floor(min_y - margin)))
	var x1: int = min(width - 1, int(ceil(max_x + margin)))
	var y1: int = min(height - 1, int(ceil(max_y + margin)))
	return [x0, y0, x1, y1]


static func _pixel_bounds_radius(center: Vector2, radius: float, width: int, height: int) -> Array:
	var x0: int = max(0, int(floor(center.x - radius)))
	var y0: int = max(0, int(floor(center.y - radius)))
	var x1: int = min(width - 1, int(ceil(center.x + radius)))
	var y1: int = min(height - 1, int(ceil(center.y + radius)))
	return [x0, y0, x1, y1]
