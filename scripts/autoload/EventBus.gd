extends Node
## Autoload singleton providing a global signal bus so unrelated systems
## (UI, units, buildings, economy, AI) can communicate without holding
## direct references to one another.

signal money_changed(team: int, amount: float)

signal unit_created(unit: Node)
signal unit_destroyed(unit: Node)
signal unit_picked_up(unit: Node)
signal unit_dropped(unit: Node)
signal unit_order_changed(unit: Node, order: int)

signal building_captured(building: Node, new_team: int)
signal building_damaged(building: Node, amount: float, attacker: Node)
signal building_destroyed(building: Node)

signal commander_mode_changed(team: int, mode: int)
signal commander_fuel_changed(team: int, value: float)
signal commander_ammo_changed(team: int, value: float)
signal commander_died(commander: Node)

signal match_started
signal match_ended(winning_team: int)

signal enemy_wave_launched(attacking_team: int, unit_count: int)

signal build_menu_requested(team: int)
signal command_menu_requested(team: int)
# team: -1 = broadcast to all players
signal hud_message(text: String, team: int)
signal audio_event_requested(event_name: String)
signal camera_shake_requested(strength: float)
