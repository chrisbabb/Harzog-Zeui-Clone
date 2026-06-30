extends TestBase
## Verify Economy spend / add / can_afford logic.


func run(_parent: Node = null) -> void:
	var saved_player := Economy.player_money
	var saved_enemy := Economy.enemy_money

	Economy.player_money = 1000.0
	Economy.enemy_money = 500.0

	# add_money
	Economy.add_money(Constants.Team.PLAYER, 200.0)
	assert_eq(Economy.player_money, 1200.0, "add_money increases player balance")

	Economy.add_money(Constants.Team.ENEMY, 100.0)
	assert_eq(Economy.enemy_money, 600.0, "add_money increases enemy balance")

	# can_afford
	assert_true(Economy.can_afford(Constants.Team.PLAYER, 100.0), "can_afford true when funds sufficient")
	assert_false(Economy.can_afford(Constants.Team.PLAYER, 99999.0), "can_afford false when funds insufficient")

	# spend — success
	var before_spend := Economy.player_money
	var spent := Economy.spend(Constants.Team.PLAYER, 300.0)
	assert_true(spent, "spend returns true when affordable")
	assert_eq(Economy.player_money, before_spend - 300.0, "spend deducts correct amount")

	# spend — failure (insufficient funds)
	var before_reject := Economy.player_money
	var rejected := Economy.spend(Constants.Team.PLAYER, 999999.0)
	assert_false(rejected, "spend returns false when funds insufficient")
	assert_eq(Economy.player_money, before_reject, "spend does not deduct on failure")

	# Restore
	Economy.player_money = saved_player
	Economy.enemy_money = saved_enemy
