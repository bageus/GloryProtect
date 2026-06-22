class_name AnchorVisualOverlay
extends AnchorVisualController

@export_range(0.05, 0.5, 0.01) var object_asset_scale: float = 0.24
@export var winch_vertical_offset: float = -76.0
@export var winch_chain_exit_offset: Vector2 = Vector2(0.0, 24.0)

func _ready() -> void:
	super._ready()
	z_index = 2

func _draw_winch_posts() -> void:
	for anchor_id: int in range(4):
		var side: int = AnchorRuntime.Side.LEFT if anchor_id < 2 else AnchorRuntime.Side.RIGHT
		_draw_winch(
			_get_winch_center(anchor_id),
			side == AnchorRuntime.Side.RIGHT,
			bool(_is_operator_available.call(side))
		)

func _get_winch_center(anchor_id: int) -> Vector2:
	return _geometry.get_platform_attachment_world(anchor_id) + Vector2(0.0, winch_vertical_offset)

func _get_anchor_chain_start(anchor_id: int) -> Vector2:
	return _get_winch_center(anchor_id) + winch_chain_exit_offset
