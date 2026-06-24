class_name AnchorlessOrbContactSystem
extends OrbContactSystem


func _physics_process(_delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	_set_active_orb(_registry.get_contact_orb_at(_platform.position.x))
