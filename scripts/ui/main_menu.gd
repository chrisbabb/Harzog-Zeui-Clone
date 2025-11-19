extends Control
## MainMenu - Main menu screen
##
## Options:
## - Start Game -> Match Setup
## - Settings -> Settings Menu
## - Exit -> Quit game


func _ready() -> void:
	GameManager.current_state = GameManager.GameState.MAIN_MENU


func _on_start_game_pressed() -> void:
	# Go to match setup screen
	get_tree().change_scene_to_file("res://scenes/ui/match_setup.tscn")


func _on_settings_pressed() -> void:
	# Go to settings screen
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")


func _on_exit_pressed() -> void:
	# Quit game
	get_tree().quit()
