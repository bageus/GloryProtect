class_name BuildableGridVisualPolished
extends BuildableGridVisual

@export_range(0.05, 0.5, 0.01) var turret_asset_scale: float = 0.19


func _create_turret_visual() -> void:
	var turret_visual := TurretVisualController.new()
	turret_visual.name = "TurretVisualController"
	turret_visual.turret_asset_scale = turret_asset_scale
	turret_visual.configure(
		_platform,
		_grid,
		_turrets,
		_turret_input,
		_enemies,
		balance
	)
	add_child(turret_visual)
