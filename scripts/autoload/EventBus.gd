extends Node
## Autoload singleton providing a global signal bus so unrelated systems
## (UI, units, buildings, AI) can communicate without direct references.

signal commander_transformed(commander: Node, new_mode: int)
signal commander_died(commander: Node)

signal unit_spawned(unit: Node)
signal unit_died(unit: Node)
signal unit_selected(unit: Node)
signal unit_deselected(unit: Node)

signal building_constructed(building: Node)
signal building_destroyed(building: Node)
signal building_captured(building: Node, new_team: int)

signal resources_changed(team: int, amount: int)
signal build_menu_requested
signal command_menu_requested

signal game_paused
signal game_resumed
signal match_started
signal match_ended(winning_team: int)
