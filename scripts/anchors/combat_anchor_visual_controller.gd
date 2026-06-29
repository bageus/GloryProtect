class_name CombatAnchorVisualController
extends AnchorVisualController

@export_range(1.0, 8.0, 0.25) var electric_arc_speed: float = 4.5
@export_range(4.0, 20.0, 1.0) var electric_arc_spacing: float = 10.0
@export_range(1.0, 8.0, 0.5) var electric_arc_amplitude: float = 4.0

var _anchor_host: CombatAnchorHostSystem
var _combat_anchors: CombatAnchorSystem


func configure_combat(
	store: AnchorRuntimeStore,
	geometry: AnchorGeometry,
	balance: AnchorBalance,
	is_operator_available: Callable,
	is_simulation_active: Callable,
	anchor_host: CombatAnchorHostSystem,
	combat_anchors: CombatAnchorSystem
) -> void:
	_anchor_host = anchor_host
	_combat_anchors = combat_anchors
	configure(
		store,
		geometry,
		balance,
		is_operator_available,
		is_simulation_active
	)
	if (
		_combat_anchors != null
		and not _combat_anchors.upgrades_changed.is_connected(
			_on_upgrades_changed
		)
	):
		_combat_anchors.upgrades_changed.connect(_on_upgrades_changed)


func is_electric_visual_active(anchor_id: int) -> bool:
	if _anchor_host == null or _combat_anchors == null or anchor_id < 0:
		return false
	if not (
		_combat_anchors.upgrades.periodic_electric_enabled
		or _combat_anchors.upgrades.has_electric_specialization()
	):
		return false
	var state: int = _anchor_host.get_anchor_state(anchor_id)
	return state in [
		AnchorRuntime.State.ATTACHED,
		AnchorRuntime.State.OVERLOADED,
	]


func _draw_attached_anchor(
	anchor: AnchorRuntime,
	start: Vector2,
	ground: Vector2
) -> void:
	super._draw_attached_anchor(anchor, start, ground)
	if not is_electric_visual_active(anchor.anchor_id):
		return
	_draw_electric_arcs(
		start,
		_get_clamp_connection_point(ground),
		anchor.anchor_id
	)


func _draw_electric_arcs(
	start: Vector2,
	finish: Vector2,
	anchor_id: int
) -> void:
	var segment: Vector2 = finish - start
	var length: float = segment.length()
	if length <= 1.0:
		return
	var direction: Vector2 = segment / length
	var normal := direction.rotated(PI * 0.5)
	var point_count: int = maxi(5, ceili(length / electric_arc_spacing))
	var phase: float = (
		_warning_elapsed * electric_arc_speed + float(anchor_id) * 1.91
	)
	var arc := PackedVector2Array()
	for index: int in range(point_count + 1):
		var ratio: float = float(index) / float(point_count)
		var arc_point: Vector2 = start.lerp(finish, ratio)
		var envelope: float = sin(ratio * PI)
		var jitter: float = (
			sin(phase + float(index) * 2.37)
			+ sin(phase * 1.73 - float(index) * 1.19) * 0.45
		)
		arc_point += normal * jitter * electric_arc_amplitude * envelope
		arc.append(arc_point)
	draw_polyline(
		arc,
		Color(0.3, 0.82, 1.0, 0.55),
		5.0,
		true
	)
	draw_polyline(
		arc,
		Color(0.88, 0.98, 1.0, 1.0),
		2.0,
		true
	)

	var branch_count: int = maxi(2, floori(length / 80.0))
	for branch_index: int in range(branch_count):
		var ratio: float = fposmod(
			phase * 0.11 + float(branch_index) / float(branch_count),
			1.0
		)
		var origin: Vector2 = start.lerp(finish, ratio)
		var side: float = -1.0 if branch_index % 2 == 0 else 1.0
		var branch_end := (
			origin
			+ normal * electric_arc_amplitude * 2.4 * side
			+ direction * 6.0
		)
		draw_line(
			origin,
			branch_end,
			Color(0.75, 0.96, 1.0, 0.9),
			1.5,
			true
		)


func _on_upgrades_changed() -> void:
	queue_redraw()
