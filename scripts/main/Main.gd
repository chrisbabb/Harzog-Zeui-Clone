extends Node
## Entry point scene. Immediately hands off to the main menu.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/MainMenu.tscn"


func _ready() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
