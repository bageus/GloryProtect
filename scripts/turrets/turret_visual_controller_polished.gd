class_name TurretVisualControllerPolished
extends TurretVisualController

const TARGET_ASSET_SCALE: float = 0.19


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
	return TARGET_ASSET_SCALE


func _apply_polished_scale() -> void:
	turret_asset_scale = TARGET_ASSET_SCALE
