class_name BuildableGridVisualPolished
extends BuildableGridVisual

@export_range(0.05, 0.5, 0.01) var turret_asset_scale: float = 0.19


func _ready() -> void:
	super._ready()
	_apply_turret_scale()
	call_deferred("_apply_turret_scale")


func _process(delta: float) -> void:
	_apply_turret_scale()
	super._process(delta)


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


func _apply_turret_scale() -> void:
	var turret_visual := get_node_or_null(
		"TurretVisualController"
	) as TurretVisualController
	if turret_visual == null:
		return
	if is_equal_approx(turret_visual.turret_asset_scale, turret_asset_scale):
		return
	turret_visual.turret_asset_scale = turret_asset_scale
	turret_visual.queue_redraw()
