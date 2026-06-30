extends TestBase
## Verify that a Projectile's friendly-fire guard prevents damage to same-team bodies.


func run(_parent: Node = null) -> void:
	# Instantiate without adding to the scene tree so _ready() does not fire.
	# The guard (if _detonated or body == source or body.get("team") == team)
	# returns before any scene-tree calls, making this safe to call directly.
	var projectile: Node = preload("res://scenes/effects/Projectile.tscn").instantiate()
	projectile.set("team", Constants.Team.PLAYER)

	# Mock body: same team, with a take_damage method to detect unwanted calls.
	var body_script := GDScript.new()
	body_script.source_code = (
		"extends Node\n"
		+ "var team: int = Constants.Team.PLAYER\n"
		+ "var hp: float = 100.0\n"
		+ "func take_damage(amount: float, _attacker = null) -> void:\n"
		+ "\thp -= amount\n"
	)
	body_script.reload()
	var friendly_body := Node.new()
	friendly_body.set_script(body_script)

	projectile.call("_on_body_entered", friendly_body)

	assert_eq(friendly_body.get("hp"), 100.0, "friendly body takes no damage")

	# Confirm the guard does NOT block an enemy body (different team).
	var enemy_body := Node.new()
	enemy_body.set_script(body_script)
	enemy_body.set("team", Constants.Team.ENEMY)

	var detonated: bool = projectile.get("_detonated")
	var source: Object = projectile.get("source")
	var proj_team: int = projectile.get("team")
	var guard_fires: bool = (detonated or enemy_body == source or enemy_body.get("team") == proj_team)
	assert_false(guard_fires, "guard does not block enemy body")

	friendly_body.free()
	enemy_body.free()
	projectile.free()
