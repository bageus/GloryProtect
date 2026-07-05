class_name BoardingEnemyVisual
extends Node2D

const FALLBACK_ASSET_ARCHETYPE_ID := &"basic"

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("BoardingEnemyController") var controller_path: NodePath
@export_group("Animation")
@export_range(1.0, 30.0, 0.5) var idle_frame_rate: float = 5.0
@export_range(1.0, 30.0, 0.5) var run_frame_rate: float = 9.0
@export_range(1.0, 30.0, 0.5) var attack_frame_rate: float = 10.0
@export_range(1.0, 30.0, 0.5) var climb_frame_rate: float = 7.0
@export_range(1.0, 30.0, 0.5) var jump_frame_rate: float = 10.0
@export_range(1.0, 30.0, 0.5) var flying_frame_rate: float = 8.0
@export_range(1.0, 30.0, 0.5) var death_frame_rate: float = 8.0
@export_range(32.0, 160.0, 1.0) var atlas_asset_height: float = 88.0
@export_range(32.0, 160.0, 1.0) var atlas_asset_max_width: float = 96.0
@export_range(0.0, 1.0, 0.01) var asset_alpha_crop_threshold: float = 0.08
@export var asset_offset: Vector2 = Vector2.ZERO

var _body_radius: float = 12.0
var _body_color: Color = Color(0.92, 0.24, 0.2)
var _accent_color: Color = Color(1.0, 0.72, 0.62)
var _archetype_id: StringName = &"basic"
var _animation: CharacterAnimationController = CharacterAnimationController.new()
var _presentation_state_id: StringName = &"idle"
var _behavior_state_id: StringName = &""
var _last_global_x: float = 0.0
var _detached_death: bool = false
var _enemy: BoardingEnemy
var _melee: MeleeAttackComponent
var _asset_source_rect_cache: Dictionary = {}

@onready var _health: HealthComponent = get_node(health_path)
@onready var _controller: BoardingEnemyController = get_node(controller_path)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enemy = get_parent() as BoardingEnemy
	_melee = get_node("../MeleeAttackComponent") as MeleeAttackComponent
	if _enemy != null:
		_enemy.visual_state_changed.connect(_on_enemy_visual_state_changed)
	_last_global_x = global_position.x
	_health.health_changed.connect(_on_health_changed)
	_animation.set_facing_right(false)
	_animation.play(&"idle", _get_frame_count(&"idle"), idle_frame_rate)
	queue_redraw()


func _process(delta: float) -> void:
	if _detached_death:
		_animation.tick(delta)
		if _animation.is_finished():
			queue_free()
		else:
			queue_redraw()
		return
	var movement_delta: float = global_position.x - _last_global_x
	_last_global_x = global_position.x
	_animation.face_delta(movement_delta, 0.05)
	_update_animation(_resolve_presentation_state(movement_delta), delta)
	queue_redraw()


func configure(archetype: BoardingEnemyArchetype) -> void:
	assert(archetype != null, "BoardingEnemyVisual requires an archetype")
	_body_radius = maxf(4.0, archetype.body_radius)
	_body_color = archetype.body_color
	_accent_color = archetype.accent_color
	_archetype_id = archetype.archetype_id
	if is_node_ready():
		_animation.play(
			_presentation_state_id,
			_get_frame_count(_presentation_state_id),
			_get_frame_rate(_presentation_state_id),
			_presentation_state_id not in [&"attack", &"jump", &"landing", &"death"]
		)
		queue_redraw()


func detach_for_death() -> void:
	if _detached_death:
		return
	_detached_death = true
	_presentation_state_id = &"death"
	_behavior_state_id = &""
	var target_parent: Node = get_parent().get_parent() if get_parent() != null else null
	if target_parent != null:
		reparent(target_parent, true)
	_controller = null
	_health = null
	_enemy = null
	_melee = null
	_animation.play(&"death", _get_frame_count(&"death"), death_frame_rate, false, true)
	queue_redraw()


func get_presentation_state_id() -> StringName:
	return _presentation_state_id


func get_animation_frame() -> int:
	return _animation.get_frame_index()


func get_archetype_id() -> StringName:
	return _archetype_id


func is_facing_right() -> bool:
	return _animation.is_facing_right()


func is_detached_death() -> bool:
	return _detached_death


func get_asset_frame_count_for_tests(state_id: StringName) -> int:
	return _get_effective_asset_frame_count(state_id)


func get_asset_frame_paths_for_tests(state_id: StringName) -> PackedStringArray:
	if BoardingEnemyVisualTextureBank.get_frame_count(_archetype_id, state_id) > 0:
		return BoardingEnemyVisualAssetCatalog.get_frame_paths(_archetype_id, state_id)
	return BoardingEnemyVisualAssetCatalog.get_frame_paths(FALLBACK_ASSET_ARCHETYPE_ID, state_id)


func has_replacement_asset_for_tests(state_id: StringName) -> bool:
	return get_asset_frame_count_for_tests(state_id) > 0


func has_current_replacement_asset_for_tests() -> bool:
	return _get_current_texture() != null


func get_current_asset_state_for_tests() -> StringName:
	return _resolve_asset_state(_presentation_state_id)


func get_current_asset_archetype_id_for_tests() -> StringName:
	return _resolve_asset_archetype_id(get_current_asset_state_for_tests())


func get_asset_state_for_tests(state_id: StringName) -> StringName:
	return _resolve_asset_state(state_id)


func is_using_asset_sprite_for_tests() -> bool:
	return _get_current_texture() != null


func should_draw_procedural_for_tests() -> bool:
	return false


func is_asset_mirrored_for_tests() -> bool:
	return BoardingEnemyVisualAssetCatalog.should_mirror_for_facing(
		_animation.is_facing_right()
	)


func get_current_asset_source_rect_for_tests() -> Rect2:
	return _get_current_source_rect()


func get_current_asset_texture_size_for_tests() -> Vector2:
	var texture: Texture2D = _get_current_texture()
	return texture.get_size() if texture != null else Vector2.ZERO


func get_current_asset_draw_size_for_tests() -> Vector2:
	return _fit_asset_size(_get_current_source_rect().size)


func get_behavior_presentation_state_for_tests(
	state_id: StringName,
	movement_delta: float = 0.0
) -> StringName:
	return _resolve_behavior_presentation_state(state_id, movement_delta)


func debug_set_facing_right_for_tests(facing_right: bool) -> void:
	_animation.set_facing_right(facing_right)
	queue_redraw()


func _resolve_presentation_state(movement_delta: float) -> StringName:
	var is_moving: bool = absf(movement_delta) > 0.05
	if _behavior_state_id != &"":
		var behavior_state: StringName = _resolve_behavior_presentation_state(
			_behavior_state_id,
			movement_delta
		)
		if behavior_state != &"":
			return behavior_state
		if is_moving:
			return &"run"
	if _controller == null:
		return &"run" if is_moving else &"idle"
	match _controller.get_state():
		BoardingEnemyController.State.CLIMBING:
			return &"climb"
		BoardingEnemyController.State.FIGHTING:
			return &"attack"
		BoardingEnemyController.State.JUMPING:
			return &"jump"
		BoardingEnemyController.State.ON_PLATFORM:
			return &"run" if is_moving else &"idle"
		BoardingEnemyController.State.WAITING_WITHOUT_PATH, BoardingEnemyController.State.RUNNING_TO_ANCHOR:
			return &"run"
		_:
			return &"run" if is_moving else &"idle"


static func _resolve_behavior_presentation_state(
	state_id: StringName,
	movement_delta: float
) -> StringName:
	match state_id:
		&"flying":
			return &"flying"
		&"landing":
			return &"landing"
		&"attacking", &"arming":
			return &"attack"
		&"boarded":
			return &"run" if absf(movement_delta) > 0.05 else &"idle"
		&"waiting", &"waiting_without_path":
			return &"idle"
		&"running_to_rope", &"running_to_anchor":
			return &"run"
		&"dead", &"death":
			return &"death"
		_:
			return &""


func _update_animation(state_id: StringName, delta: float) -> void:
	_presentation_state_id = state_id
	var frame_count: int = _get_frame_count(state_id)
	match state_id:
		&"run":
			_animation.play(&"run", frame_count, run_frame_rate)
			_animation.tick(delta)
		&"attack":
			_animation.play(&"attack", frame_count, attack_frame_rate, false)
			_animation.set_normalized_progress(_get_attack_progress())
		&"climb":
			_animation.play(&"climb", frame_count, climb_frame_rate)
			_animation.tick(delta)
		&"jump":
			_animation.play(&"jump", frame_count, jump_frame_rate, false)
			_animation.tick(delta)
		&"flying":
			_animation.play(&"flying", frame_count, flying_frame_rate)
			_animation.tick(delta)
		&"landing":
			_animation.play(&"landing", frame_count, flying_frame_rate, false)
			_animation.tick(delta)
		&"death":
			_animation.play(&"death", frame_count, death_frame_rate, false)
			_animation.tick(delta)
		_:
			_animation.play(&"idle", frame_count, idle_frame_rate)
			_animation.tick(delta)


func _get_frame_count(state_id: StringName) -> int:
	var asset_state: StringName = _resolve_asset_state(state_id)
	if asset_state != &"":
		var asset_count: int = _get_effective_asset_frame_count(asset_state)
		if asset_count > 0:
			return _get_logical_frame_count_for_assets(asset_state, asset_count)
	match state_id:
		&"death", &"landing":
			return 4
		&"climb":
			return 3
		_:
			return 6


func _get_logical_frame_count_for_assets(state_id: StringName, asset_count: int) -> int:
	match state_id:
		&"attack":
			return max(asset_count, 6)
		&"death", &"landing":
			return max(asset_count, 4)
		&"climb":
			return max(asset_count, 3)
		_:
			return asset_count


func _get_frame_rate(state_id: StringName) -> float:
	match state_id:
		&"run":
			return run_frame_rate
		&"attack":
			return attack_frame_rate
		&"climb":
			return climb_frame_rate
		&"jump":
			return jump_frame_rate
		&"flying", &"landing":
			return flying_frame_rate
		&"death":
			return death_frame_rate
		_:
			return idle_frame_rate


func _get_attack_progress() -> float:
	if _melee == null:
		return 0.0
	return _melee.get_windup_progress()


func _draw() -> void:
	var texture: Texture2D = _get_current_texture()
	var source_rect: Rect2 = _get_current_source_rect()
	var asset_size: Vector2 = _fit_asset_size(source_rect.size)
	var feet := Vector2(0.0, _body_radius + 4.0) + asset_offset
	var asset_rect := Rect2(feet - Vector2(asset_size.x * 0.5, asset_size.y), asset_size)
	if texture != null:
		draw_texture_rect_region(texture, asset_rect, source_rect, Color.WHITE)
	if not _detached_death:
		_draw_health_bar(asset_rect)


func _get_current_texture() -> Texture2D:
	var asset_state: StringName = _resolve_asset_state(_presentation_state_id)
	var asset_archetype_id: StringName = _resolve_asset_archetype_id(asset_state)
	if asset_state == &"" or asset_archetype_id == &"":
		return null
	var frames: Array[Texture2D] = BoardingEnemyVisualTextureBank.get_frames(asset_archetype_id, asset_state)
	if frames.is_empty():
		return null
	return frames[_get_asset_frame_index(_animation.get_frame_index(), frames.size(), asset_state)]


func _get_current_source_rect() -> Rect2:
	var texture: Texture2D = _get_current_texture()
	if texture == null:
		return Rect2(Vector2.ZERO, Vector2(atlas_asset_max_width, atlas_asset_height))
	return _get_asset_source_rect(texture)


func _fit_asset_size(source_size: Vector2) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2(atlas_asset_max_width, atlas_asset_height)
	var asset_scale: float = atlas_asset_height / source_size.y
	if source_size.x * asset_scale > atlas_asset_max_width:
		asset_scale = atlas_asset_max_width / source_size.x
	return source_size * asset_scale


func _resolve_asset_state(state_id: StringName) -> StringName:
	var candidates: Array[StringName] = []
	_append_candidate(candidates, state_id)
	match state_id:
		&"waiting", &"waiting_without_path":
			_append_candidate(candidates, &"idle")
		&"running_to_rope", &"running_to_anchor":
			_append_candidate(candidates, &"run")
		&"attacking", &"arming":
			_append_candidate(candidates, &"attack")
		&"dead":
			_append_candidate(candidates, &"death")
		&"boarded":
			_append_candidate(candidates, &"run")
		_:
			pass
	_append_candidate(candidates, &"idle")
	_append_candidate(candidates, &"run")
	for candidate: StringName in candidates:
		if _get_effective_asset_frame_count(candidate) > 0:
			return candidate
	return &""


func _resolve_asset_archetype_id(asset_state: StringName) -> StringName:
	if asset_state == &"":
		return &""
	if BoardingEnemyVisualTextureBank.get_frame_count(_archetype_id, asset_state) > 0:
		return _archetype_id
	if BoardingEnemyVisualTextureBank.get_frame_count(FALLBACK_ASSET_ARCHETYPE_ID, asset_state) > 0:
		return FALLBACK_ASSET_ARCHETYPE_ID
	return &""


func _get_effective_asset_frame_count(asset_state: StringName) -> int:
	var asset_archetype_id: StringName = _resolve_asset_archetype_id(asset_state)
	if asset_archetype_id == &"":
		return 0
	return BoardingEnemyVisualTextureBank.get_frame_count(asset_archetype_id, asset_state)


func _append_candidate(candidates: Array[StringName], state_id: StringName) -> void:
	if state_id == &"" or state_id in candidates:
		return
	candidates.append(state_id)


func _get_asset_frame_index(logical_frame: int, asset_count: int, asset_state: StringName) -> int:
	if asset_count <= 1:
		return 0
	var logical_count: int = max(_get_logical_frame_count_for_assets(asset_state, asset_count), 1)
	if logical_count <= 1:
		return 0
	var progress: float = float(clampi(logical_frame, 0, logical_count - 1)) / float(logical_count - 1)
	return clampi(roundi(progress * float(asset_count - 1)), 0, asset_count - 1)


func _get_asset_source_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	if _asset_source_rect_cache.has(texture):
		return _asset_source_rect_cache[texture]
	var source_rect: Rect2 = TextureRegionLayout.get_alpha_bounds(
		texture,
		asset_alpha_crop_threshold
	)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		source_rect = Rect2(Vector2.ZERO, texture.get_size())
	_asset_source_rect_cache[texture] = source_rect
	return source_rect


func _draw_health_bar(asset_rect: Rect2) -> void:
	if _health == null or not is_instance_valid(_health):
		return
	var segment_width := 8.0
	var segment_height := 4.0
	var gap := 2.0
	var total_width := float(_health.max_health) * segment_width + float(_health.max_health - 1) * gap
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


func _on_enemy_visual_state_changed(_enemy_id: int, state_id: StringName) -> void:
	_behavior_state_id = state_id


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	queue_redraw()
