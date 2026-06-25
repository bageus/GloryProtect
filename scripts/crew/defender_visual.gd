class_name DefenderVisual
extends Node2D

signal death_animation_finished(defender_id: int)

const WARRIOR_IDLE_TEXTURES: Array[Texture2D] = [
	preload("res://visual/defenders/warrior/base/idle/warrior_idle_01.png"),
	preload("res://visual/defenders/warrior/base/idle/warrior_idle_02.png"),
	preload("res://visual/defenders/warrior/base/idle/warrior_idle_03.png"),
	preload("res://visual/defenders/warrior/base/idle/warrior_idle_04.png"),
	preload("res://visual/defenders/warrior/base/idle/warrior_idle_05.png"),
	preload("res://visual/defenders/warrior/base/idle/warrior_idle_06.png"),
]
const WARRIOR_RUN_LEFT_TEXTURES: Array[Texture2D] = [
	preload("res://visual/defenders/warrior/base/run/left/warrior_run_left_01.png"),
	preload("res://visual/defenders/warrior/base/run/left/warrior_run_left_02.png"),
	preload("res://visual/defenders/warrior/base/run/left/warrior_run_left_03.png"),
	preload("res://visual/defenders/warrior/base/run/left/warrior_run_left_04.png"),
]
const WARRIOR_RUN_RIGHT_TEXTURES: Array[Texture2D] = [
	preload("res://visual/defenders/warrior/base/run/right/warrior_run_right_01.png"),
	preload("res://visual/defenders/warrior/base/run/right/warrior_run_right_02.png"),
	preload("res://visual/defenders/warrior/base/run/right/warrior_run_right_03.png"),
	preload("res://visual/defenders/warrior/base/run/right/warrior_run_right_04.png"),
]
const WARRIOR_ATTACK_LEFT_TEXTURES: Array[Texture2D] = [
	preload("res://visual/defenders/warrior/base/attack/left/warrior_attack_left_01.png"),
	preload("res://visual/defenders/warrior/base/attack/left/warrior_attack_left_02.png"),
	preload("res://visual/defenders/warrior/base/attack/left/warrior_attack_left_03.png"),
	preload("res://visual/defenders/warrior/base/attack/left/warrior_attack_left_04.png"),
	preload("res://visual/defenders/warrior/base/attack/left/warrior_attack_left_05.png"),
]
const WARRIOR_ATTACK_RIGHT_TEXTURES: Array[Texture2D] = [
	preload("res://visual/defenders/warrior/base/attack/right/warrior_attack_right_01.png"),
	preload("res://visual/defenders/warrior/base/attack/right/warrior_attack_right_02.png"),
	preload("res://visual/defenders/warrior/base/attack/right/warrior_attack_right_03.png"),
	preload("res://visual/defenders/warrior/base/attack/right/warrior_attack_right_04.png"),
	preload("res://visual/defenders/warrior/base/attack/right/warrior_attack_right_05.png"),
]
const WARRIOR_DIE_RIGHT_TEXTURES: Array[Texture2D] = [
	preload("res://visual/defenders/die/warrior_die_right_01.png"),
	preload("res://visual/defenders/die/warrior_die_right_02.png"),
]

enum AnimationState {
	IDLE,
	RUN,
	ATTACK,
	DYING,
	HIDDEN,
}

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("StatusEffectComponent") var status_effects_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath = NodePath(
	"../../../CrewRoleManager"
)
@export_range(4.0, 40.0, 1.0) var body_radius: float = 14.0
@export var body_color: Color = Color(0.45, 0.8, 1.0)
@export_group("Defender Assets")
@export_range(32.0, 128.0, 1.0) var asset_height: float = 72.0
@export_range(32.0, 128.0, 1.0) var asset_max_width: float = 72.0
@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold: float = 0.08
@export var asset_offset: Vector2 = Vector2.ZERO
@export_group("Animation")
@export_range(1.0, 30.0, 0.5) var idle_frame_rate: float = 6.0
@export_range(1.0, 30.0, 0.5) var run_frame_rate: float = 10.0
@export_range(1.0, 30.0, 0.5) var attack_frame_rate: float = 12.0
@export_range(1.0, 30.0, 0.5) var death_frame_rate: float = 6.0

var _selected: bool = false
var _poisoned: bool = false
var _poison_stacks: int = 0
var _role_id: int = CrewRole.Id.FREE_FIGHTER
var _state: AnimationState = AnimationState.IDLE
var _frame_index: int = 0
var _frame_elapsed: float = 0.0
var _facing_right: bool = true
var _idle_source_rects: Array[Rect2] = []
var _run_left_source_rects: Array[Rect2] = []
var _run_right_source_rects: Array[Rect2] = []
var _attack_left_source_rects: Array[Rect2] = []
var _attack_right_source_rects: Array[Rect2] = []
var _death_source_rects: Array[Rect2] = []
var _defender: Defender
var _movement: DefenderMovement
var _melee: MeleeAttackComponent
var _role_manager: CrewRoleManager

@onready var _health: HealthComponent = get_node(health_path)
@onready var _status_effects: StatusEffectComponent = get_node(status_effects_path)


func _ready() -> void:
	_idle_source_rects = _build_source_rects(WARRIOR_IDLE_TEXTURES)
	_run_left_source_rects = _build_source_rects(WARRIOR_RUN_LEFT_TEXTURES)
	_run_right_source_rects = _build_source_rects(WARRIOR_RUN_RIGHT_TEXTURES)
	_attack_left_source_rects = _build_source_rects(WARRIOR_ATTACK_LEFT_TEXTURES)
	_attack_right_source_rects = _build_source_rects(WARRIOR_ATTACK_RIGHT_TEXTURES)
	_death_source_rects = _build_source_rects(WARRIOR_DIE_RIGHT_TEXTURES)
	_defender = get_parent() as Defender
	_movement = get_node("../DefenderMovement") as DefenderMovement
	_melee = get_node("../MeleeAttackComponent") as MeleeAttackComponent
	_role_manager = get_node_or_null(role_manager_path) as CrewRoleManager
	if _role_manager != null:
		_role_manager.assignment_changed.connect(_on_assignment_changed)
		_sync_role_from_manager()
	if _defender != null:
		_defender.died.connect(_on_defender_died)
	if _melee != null:
		_melee.attack_started.connect(_on_attack_started)
		_melee.attack_finished.connect(_on_attack_finished)
	_health.health_changed.connect(_on_health_changed)
	_status_effects.poison_changed.connect(_on_poison_changed)
	queue_redraw()


func _process(delta: float) -> void:
	if _state == AnimationState.HIDDEN:
		return
	if _state == AnimationState.DYING:
		_advance_death(delta)
	elif _state == AnimationState.ATTACK:
		_advance_clamped(WARRIOR_ATTACK_RIGHT_TEXTURES.size(), attack_frame_rate, delta)
	else:
		_sync_locomotion_state()
		if _state == AnimationState.RUN:
			_advance_loop(WARRIOR_RUN_RIGHT_TEXTURES.size(), run_frame_rate, delta)
		else:
			_advance_loop(WARRIOR_IDLE_TEXTURES.size(), idle_frame_rate, delta)
	queue_redraw()


func configure(new_radius: float, new_color: Color) -> void:
	body_radius = new_radius
	body_color = new_color
	if is_node_ready():
		queue_redraw()


func set_role(role_id: int) -> void:
	if _role_id == role_id:
		return
	_role_id = role_id
	queue_redraw()


func set_selected(is_selected: bool) -> void:
	if _selected == is_selected:
		return
	_selected = is_selected
	queue_redraw()


func is_selected() -> bool:
	return _selected


func play_death() -> void:
	if _state == AnimationState.DYING or _state == AnimationState.HIDDEN:
		return
	_state = AnimationState.DYING
	_frame_index = 0
	_frame_elapsed = 0.0
	visible = true
	if _defender != null:
		_defender.visible = true
	queue_redraw()


func get_animation_state() -> int:
	return _state


func get_animation_frame() -> int:
	return _frame_index


func is_facing_right() -> bool:
	return _facing_right


func _draw() -> void:
	if _state == AnimationState.HIDDEN:
		return
	var source_rect: Rect2 = _get_current_source_rect()
	var asset_size: Vector2 = _fit_asset_size(source_rect.size)
	var feet := Vector2(0.0, body_radius) + asset_offset
	var asset_rect := Rect2(
		feet - Vector2(asset_size.x * 0.5, asset_size.y),
		asset_size
	)

	if _state != AnimationState.DYING and _selected:
		var selection_radius: float = maxf(body_radius + 6.0, asset_size.x * 0.34)
		draw_arc(
			feet + Vector2(0.0, -3.0),
			selection_radius,
			0.0,
			TAU,
			40,
			Color(1.0, 0.84, 0.25),
			3.0
		)
		draw_circle(
			feet + Vector2(0.0, selection_radius + 5.0),
			3.5,
			Color(1.0, 0.84, 0.25)
		)

	var texture: Texture2D = _get_current_texture()
	if texture != null:
		var tint := Color.WHITE
		if _poisoned and _state != AnimationState.DYING:
			tint = Color(0.72, 1.0, 0.62, 1.0)
		draw_texture_rect_region(texture, asset_rect, source_rect, tint)

	if _state == AnimationState.DYING:
		return
	if _poisoned:
		_draw_poison_indicator(asset_rect)
	_draw_health_segments(asset_rect)


func _build_source_rects(textures: Array[Texture2D]) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for texture: Texture2D in textures:
		result.append(TextureRegionLayout.get_alpha_bounds(texture, alpha_crop_threshold))
	return result


func _sync_locomotion_state() -> void:
	var moving: bool = (
		_movement != null
		and _movement.is_moving()
		and not _movement.is_paused()
	)
	if moving:
		var delta_x: float = _movement.get_target_x() - _defender.position.x
		if absf(delta_x) > 0.01:
			_facing_right = delta_x > 0.0
		_set_animation_state(AnimationState.RUN)
	else:
		_set_animation_state(AnimationState.IDLE)


func _set_animation_state(new_state: AnimationState) -> void:
	if _state == new_state:
		return
	_state = new_state
	_frame_index = 0
	_frame_elapsed = 0.0


func _advance_loop(frame_count: int, frame_rate: float, delta: float) -> void:
	if frame_count <= 1 or frame_rate <= 0.0:
		return
	var frame_duration: float = 1.0 / frame_rate
	_frame_elapsed += maxf(0.0, delta)
	while _frame_elapsed >= frame_duration:
		_frame_elapsed -= frame_duration
		_frame_index = (_frame_index + 1) % frame_count


func _advance_clamped(frame_count: int, frame_rate: float, delta: float) -> void:
	if frame_count <= 1 or frame_rate <= 0.0 or _frame_index >= frame_count - 1:
		return
	var frame_duration: float = 1.0 / frame_rate
	_frame_elapsed += maxf(0.0, delta)
	while _frame_elapsed >= frame_duration and _frame_index < frame_count - 1:
		_frame_elapsed -= frame_duration
		_frame_index += 1


func _advance_death(delta: float) -> void:
	if death_frame_rate <= 0.0:
		_finish_death_animation()
		return
	var frame_duration: float = 1.0 / death_frame_rate
	_frame_elapsed += maxf(0.0, delta)
	while _frame_elapsed >= frame_duration:
		_frame_elapsed -= frame_duration
		if _frame_index < WARRIOR_DIE_RIGHT_TEXTURES.size() - 1:
			_frame_index += 1
		else:
			_finish_death_animation()
			return


func _finish_death_animation() -> void:
	_state = AnimationState.HIDDEN
	visible = false
	if _defender != null:
		_defender.visible = false
	death_animation_finished.emit(_defender.defender_id if _defender != null else -1)


func _get_current_texture() -> Texture2D:
	if _state == AnimationState.DYING:
		return WARRIOR_DIE_RIGHT_TEXTURES[
			mini(_frame_index, WARRIOR_DIE_RIGHT_TEXTURES.size() - 1)
		]
	if _role_id == CrewRole.Id.DRIVER:
		return null
	if _state == AnimationState.ATTACK:
		var attacks: Array[Texture2D] = (
			WARRIOR_ATTACK_RIGHT_TEXTURES
			if _facing_right
			else WARRIOR_ATTACK_LEFT_TEXTURES
		)
		return attacks[mini(_frame_index, attacks.size() - 1)]
	if _state == AnimationState.RUN:
		var runs: Array[Texture2D] = (
			WARRIOR_RUN_RIGHT_TEXTURES
			if _facing_right
			else WARRIOR_RUN_LEFT_TEXTURES
		)
		return runs[mini(_frame_index, runs.size() - 1)]
	return WARRIOR_IDLE_TEXTURES[mini(_frame_index, WARRIOR_IDLE_TEXTURES.size() - 1)]


func _get_current_source_rect() -> Rect2:
	if _state == AnimationState.DYING:
		return _death_source_rects[mini(_frame_index, _death_source_rects.size() - 1)]
	if _role_id == CrewRole.Id.DRIVER:
		return Rect2(Vector2.ZERO, Vector2(asset_max_width, asset_height))
	if _state == AnimationState.ATTACK:
		var attacks: Array[Rect2] = (
			_attack_right_source_rects
			if _facing_right
			else _attack_left_source_rects
		)
		return attacks[mini(_frame_index, attacks.size() - 1)]
	if _state == AnimationState.RUN:
		var runs: Array[Rect2] = (
			_run_right_source_rects
			if _facing_right
			else _run_left_source_rects
		)
		return runs[mini(_frame_index, runs.size() - 1)]
	return _idle_source_rects[mini(_frame_index, _idle_source_rects.size() - 1)]


func _fit_asset_size(source_size: Vector2) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2(asset_max_width, asset_height)
	var scale: float = asset_height / source_size.y
	if source_size.x * scale > asset_max_width:
		scale = asset_max_width / source_size.x
	return source_size * scale


func _draw_poison_indicator(asset_rect: Rect2) -> void:
	var marker_position := asset_rect.position + Vector2(
		asset_rect.size.x + 5.0,
		8.0
	)
	draw_circle(marker_position, 5.0, Color(0.52, 0.95, 0.25))
	for index: int in range(_poison_stacks):
		draw_circle(
			marker_position + Vector2(float(index - _poison_stacks + 1) * 3.0, 8.0),
			1.5,
			Color(0.76, 1.0, 0.5)
		)


func _draw_health_segments(asset_rect: Rect2) -> void:
	var segment_width := 8.0
	var segment_height := 4.0
	var gap := 2.0
	var total_width := (
		float(_health.max_health) * segment_width
		+ float(_health.max_health - 1) * gap
	)
	var start_x := asset_rect.get_center().x - total_width * 0.5
	var y := asset_rect.position.y - 8.0

	for index: int in range(_health.max_health):
		var rect := Rect2(
			Vector2(start_x + float(index) * (segment_width + gap), y),
			Vector2(segment_width, segment_height)
		)
		var fill := Color(0.18, 0.22, 0.25)
		if index < _health.current_health:
			fill = Color(0.35, 0.95, 0.48)
		draw_rect(rect, fill, true)
		draw_rect(rect, Color(0.75, 0.85, 0.9), false, 1.0)


func _sync_role_from_manager() -> void:
	if _role_manager == null or _defender == null:
		return
	var assignment: CrewAssignmentRuntime = _role_manager.get_assignment(
		_defender.defender_id
	)
	if assignment != null:
		set_role(assignment.current_role)


func _on_assignment_changed(
	defender_id: int,
	current_role: int,
	_target_role: int,
	_state_id: int
) -> void:
	if _defender == null or defender_id != _defender.defender_id:
		return
	set_role(current_role)


func _on_attack_started(target: HealthComponent) -> void:
	if _state == AnimationState.DYING or _state == AnimationState.HIDDEN:
		return
	var target_actor: Node2D = target.get_parent() as Node2D
	if target_actor != null and _defender != null:
		_facing_right = target_actor.global_position.x >= _defender.global_position.x
	_set_animation_state(AnimationState.ATTACK)
	queue_redraw()


func _on_attack_finished() -> void:
	if _state != AnimationState.ATTACK:
		return
	_sync_locomotion_state()
	queue_redraw()


func _on_defender_died(_defender_id: int) -> void:
	play_death()


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	queue_redraw()


func _on_poison_changed(active: bool, stacks: int, _remaining: float) -> void:
	_poisoned = active
	_poison_stacks = stacks
	queue_redraw()
