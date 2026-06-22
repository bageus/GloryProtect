class_name AnchorVisualActive
extends AnchorVisualOverlay

func _ready() -> void:
	super._ready()
	winch_size = _winch_source_rect.size * object_asset_scale
	anchor_size = _anchor_source_rect.size * object_asset_scale
	clamp_size = _clamp_source_rect.size * object_asset_scale
	stowed_chain_length = 40.0

func _draw() -> void:
	if _store == null:
		return
	for item: AnchorRuntime in _store.get_all():
		_draw_anchor(item)
	_draw_winch_posts()

func _draw_anchor(item: AnchorRuntime) -> void:
	var start: Vector2 = _get_anchor_chain_start(item.anchor_id)
	if item.state == AnchorRuntime.State.STOWED:
		_draw_stowed_anchor(item, start)
		_draw_available_clamp(item)
	elif item.state == AnchorRuntime.State.QUEUED:
		_draw_stowed_anchor(item, start)
		_draw_clamp(item.target_ground_point, _get_clamp_tint(item))
	elif item.state == AnchorRuntime.State.INSTALLING:
		_draw_installing_anchor(item, start)
	elif item.is_holding():
		_draw_attached_anchor(item, start, _geometry.get_runtime_ground_point(item))
	elif item.state == AnchorRuntime.State.RETURNING:
		_draw_returning_anchor(item, start, _geometry.get_runtime_ground_point(item))
