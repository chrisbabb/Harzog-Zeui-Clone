extends Control
class_name CargoIndicator
## CargoIndicator - Shows what unit the player is carrying
##
## Features:
## - Displays cargo status
## - Shows unit type being carried

var hero: TransformerHero = null

# UI elements
var background: ColorRect = null
var cargo_label: Label = null


func _ready() -> void:
	# Create background
	background = ColorRect.new()
	background.size = Vector2(250, 50)
	background.color = Color(0.1, 0.1, 0.1, 0.8)
	add_child(background)

	# Create cargo label
	cargo_label = Label.new()
	cargo_label.position = Vector2(10, 10)
	cargo_label.add_theme_font_size_override("font_size", 16)
	cargo_label.text = "Cargo: Empty"
	add_child(cargo_label)

	# Position below build progress indicator
	position = Vector2(20, 190)
	size = Vector2(250, 50)


func set_hero(player_hero: TransformerHero) -> void:
	hero = player_hero


func _process(_delta: float) -> void:
	_update_display()


func _update_display() -> void:
	if not cargo_label or not hero:
		return

	if hero.cargo_unit_type == "":
		cargo_label.text = "Cargo: Empty (Press E to pickup)"
		cargo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	else:
		cargo_label.text = "Cargo: %s (Press E to deploy)" % hero.cargo_unit_type.capitalize()
		cargo_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
