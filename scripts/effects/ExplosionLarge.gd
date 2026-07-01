extends "res://scripts/effects/Explosion.gd"
## Thin specialization of Explosion.gd pre-configured as a large explosion.
## Spawned by VFXManager.spawn_explosion_large() (building destruction).
## All particle/material/fade behavior is inherited from Explosion.gd, not
## duplicated -- this class only decides which of the two presets to use.

func _ready() -> void:
	super._ready()
	setup(true)
