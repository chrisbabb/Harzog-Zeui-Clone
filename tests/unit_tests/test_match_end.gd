extends TestBase
## Verify GameState.end_match sets match_active=false and records the winner.

var _signal_winner: int = -1


func _on_match_ended(winning_team: int) -> void:
	_signal_winner = winning_team


func run(_parent: Node = null) -> void:
	GameState.reset_match_state()

	GameState.start_match()
	assert_true(GameState.match_active, "match_active is true after start_match")
	assert_eq(GameState.winner, -1, "winner is -1 before match ends")

	EventBus.match_ended.connect(_on_match_ended)
	GameState.end_match(Constants.Team.ENEMY)
	EventBus.match_ended.disconnect(_on_match_ended)

	assert_false(GameState.match_active, "match_active is false after end_match")
	assert_eq(GameState.winner, Constants.Team.ENEMY, "winner is set to ENEMY")
	assert_eq(_signal_winner, Constants.Team.ENEMY, "match_ended signal carries correct winner")

	GameState.reset_match_state()
