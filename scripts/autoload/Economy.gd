extends Node
## Autoload singleton tracking each team's money and passive income.
## Income is continuous (per-second rates applied every frame) rather than
## ticked, so callers always read a smoothly increasing value.

var player_money: float = Constants.STARTING_MONEY
var enemy_money: float = Constants.STARTING_MONEY

# Cumulative credits gained this match (income, AI bonuses -- any positive
# delta; spending doesn't subtract). Starting credits are assigned directly
# in reset() so they never count. Read by the match-end stats panel.
var player_earned: float = 0.0
var enemy_earned: float = 0.0


func _process(delta: float) -> void:
	if not GameState.match_active:
		return
	process_income(delta)


func reset() -> void:
	player_money = GameState.selected_starting_credits
	enemy_money = GameState.selected_starting_credits
	player_earned = 0.0
	enemy_earned = 0.0


func get_money(team: int) -> float:
	return player_money if team == Constants.Team.PLAYER else enemy_money


func get_total_earned(team: int) -> float:
	return player_earned if team == Constants.Team.PLAYER else enemy_earned


func can_afford(team: int, amount: float) -> bool:
	return get_money(team) >= amount


func spend(team: int, amount: float) -> bool:
	if not can_afford(team, amount):
		return false
	_apply_delta(team, -amount)
	return true


func add_money(team: int, amount: float) -> void:
	_apply_delta(team, amount)


func process_income(delta: float) -> void:
	for team in [Constants.Team.PLAYER, Constants.Team.ENEMY]:
		var hq: Node = GameState.player_hq if team == Constants.Team.PLAYER else GameState.enemy_hq
		if hq == null or not is_instance_valid(hq):
			continue
		var income: float = Constants.BASE_INCOME_PER_SECOND
		for outpost in GameState.outposts:
			if is_instance_valid(outpost) and outpost.get("team") == team:
				income += Constants.OUTPOST_INCOME_PER_SECOND
		_apply_delta(team, income * delta)


func _apply_delta(team: int, amount: float) -> void:
	if team == Constants.Team.PLAYER:
		player_money += amount
		if amount > 0.0:
			player_earned += amount
	else:
		enemy_money += amount
		if amount > 0.0:
			enemy_earned += amount
	EventBus.money_changed.emit(team, get_money(team))
