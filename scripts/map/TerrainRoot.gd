extends Node3D
## Placeholder terrain controller. Bakes a navigation mesh from the static
## ground geometry nested under this node so NavigationAgent3D-driven units
## have a walkable surface as soon as the match starts.

@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	navigation_region.bake_navigation_mesh()
