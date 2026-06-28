class_name TurretVisualControllerPolished
extends TurretVisualController

@export_range(0.05, 0.5, 0.01) var polished_asset_scale: float = 0.19


func _ready() -> void:
	_apply_polished_scale()
	super._ready()


func _process(delta: float) -> void:
	_apply_polished_scale()
	super._process(delta)


func _draw() -> void:
	_apply_polished_scale()
	super._draw()


func get_effective_asset_scale() -> float:
	return polished_asset_scale


func _apply_polished_scale() -> void:
	turret_asset_scale = polished_asset_scale
