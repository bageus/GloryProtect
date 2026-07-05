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
@export_range(32.0, 128.0, 1.0) var atlas_asset_height: float = 72.0
@export_range(0.0, 1.0, 0.01) var asset_alpha_crop_threshold: float = 0.08

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
var _asset_sprite: Sprite2D

@onready var _health: HealthComponent = get_node(health_path)
@onready var _controller: BoardingEnemyController = get_node(controller_path)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_create_asset_sprite()
	_enemy = get_parent() as BoardingEnemy
	_melee = get_node("../MeleeAttackComponent") as MeleeAttackComponent
	if _enemy != null:
		_enemy.visual_state_changed.connect(_on_enemy_visual_state_changed)
	_last_global_x = global_position.x
	_health.health_changed.connect(_on_health_changed)
	_animation.set_facing_right(false)
	_animation.play(&"idle", _get_frame_count(&"idle"), idle_frame_rate)
	_sync_asset_sprite(_animation.get_frame_index())
	queue_redraw()


func _process(delta: float) -> void:
	if _detached_death:
		_animation.tick(delta)
		_sync_asset_sprite(_animation.get_frame_index())
		if _animation.is_finished():
			queue_free()
		else:
			queue_redraw()
		return
	var movement_delta: float = global_position.x - _last_global_x
	_last_global_x = global_position.x
	_animation.face_delta(movement_delta, 0.05)
	var next_state: StringName = _resolve_presentation_state(movement_delta)
	_update_animation(next_state, delta)
	_sync_asset_sprite(_animation.get_frame_index())
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
		_sync_asset_sprite(_animation.get_frame_index())
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
	_sync_asset_sprite(_animation.get_frame_index())
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
	return BoardingEnemyVisualAssetCatalog.get_frame_paths(_archetype_id, state_id)


func has_replacement_asset_for_tests(state_id: StringName) -> bool:
	return get_asset_frame_count_for_tests(state_id) > 0


func has_current_replacement_asset_for_tests() -> bool:
	return get_current_asset_state_for_tests() != &""


func get_current_asset_state_for_tests() -> StringName:
	return _resolve_asset_state(_presentation_state_id)


func get_current_asset_archetype_id_for_tests() -> StringName:
	return _resolve_asset_archetype_id(get_current_asset_state_for_tests())


func get_asset_state_for_tests(state_id: StringName) -> StringName:
	return _resolve_asset_state(state_id)


func is_using_asset_sprite_for_tests() -> bool:
	return _asset_sprite != null and _asset_sprite.visible and _asset_sprite.texture != null


func should_draw_procedural_for_tests() -> bool:
	var asset_state: StringName = get_current_asset_state_for_tests()
	return asset_state == &"" and not is_using_asset_sprite_for_tests()


func is_asset_mirrored_for_tests() -> bool:
	return BoardingEnemyVisualAssetCatalog.should_mirror_for_facing(_animation.is_facing_right())


func get_current_asset_source_rect_for_tests() -> Rect2:
	var asset_state: StringName = _resolve_asset_state(_presentation_state_id)
	if asset_state == &"":
		return Rect2()
	var asset_archetype_id: StringName = _resolve_asset_archetype_id(asset_state)
	if asset_archetype_id == &"":
		return Rect2()
	var frames: Array[Texture2D] = BoardingEnemyVisualAssetCatalog.get_frames(asset_archetype_id, asset_state)
	if frames.is_empty():
		return Rect2()
	return _get_asset_source_rect(frames[0])


func get_behavior_presentation_state_for_tests(state_id: StringName, movement_delta: float = 0.0) -> StringName:
	return _resolve_behavior_presentation_state(state_id, movement_delta)


func debug_set_facing_right_for_tests(facing_right: bool) -> void:
	_animation.set_facing_right(facing_right)
	_sync_asset_sprite(_animation.get_frame_index())


func _resolve_presentation_state(movement_delta: float) -> StringName:
	if _behavior_state_id != &"":
		var behavior_state: StringName = _resolve_behavior_presentation_state(
			_behavior_state_id,
			movement_delta
		)
		if behavior_state != &"":
			return behavior_state
	if _controller == null:
		return &"idle"
	match _controller.get_state():
		BoardingEnemyController.State.CLIMBING:
			return &"climb"
		BoardingEnemyController.State.FIGHTING:
			return &"attack"
		BoardingEnemyController.State.JUMPING:
			return &"jump"
		BoardingEnemyController.State.ON_PLATFORM:
			return &"run" if absf(movement_delta) > 0.05 else &"idle"
		BoardingEnemyController.State.WAITING_WITHOUT_PATH, BoardingEnemyController.State.RUNNING_TO_ANCHOR:
			return &"run"
		_:
			return &"idle"


static func _resolve_behavior_presentation_state(state_id: StringName, movement_delta: float) -> StringName:
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
	var frame: int = _animation.get_frame_index()
	var asset_state: StringName = _resolve_asset_state(_presentation_state_id)
	var sprite_ready: bool = _sync_asset_sprite(frame)
	if asset_state == &"" and _resolve_asset_archetype_id(asset_state) == &"" and not sprite_ready:
		_draw_procedural_actor(frame)
	if not _detached_death:
		_draw_health_bar()


func _create_asset_sprite() -> void:
	if _asset_sprite != null:
		return
	_asset_sprite = Sprite2D.new()
	_asset_sprite.name = "ReplacementAssetSprite"
	_asset_sprite.centered = true
	_asset_sprite.region_enabled = true
	_asset_sprite.visible = false
	_asset_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_asset_sprite.z_index = 1
	add_child(_asset_sprite)


func _sync_asset_sprite(frame: int) -> bool:
	if _asset_sprite == null:
		return false
	var asset_state: StringName = _resolve_asset_state(_presentation_state_id)
	if asset_state == &"":
		_clear_asset_sprite()
		return false
	var asset_archetype_id: StringName = _resolve_asset_archetype_id(asset_state)
	if asset_archetype_id == &"":
		_clear_asset_sprite()
		return false
	var frames: Array[Texture2D] = BoardingEnemyVisualAssetCatalog.get_frames(asset_archetype_id, asset_state)
	if frames.is_empty():
		_clear_asset_sprite()
		return false
	var texture: Texture2D = frames[_get_asset_frame_index(frame, frames.size(), asset_state)]
	if texture == null:
		_clear_asset_sprite()
		return false
	var source_rect: Rect2 = _get_asset_source_rect(texture)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		_clear_asset_sprite()
		return false
	var display_size := Vector2(atlas_asset_height * source_rect.size.x / source_rect.size.y, atlas_asset_height)
	var feet := Vector2(0.0, _body_radius + 4.0)
	_asset_sprite.texture = texture
	_asset_sprite.region_enabled = true
	_asset_sprite.region_rect = source_rect
	_asset_sprite.flip_h = is_asset_mirrored_for_tests()
	_asset_sprite.position = feet - Vector2(0.0, display_size.y * 0.5)
	_asset_sprite.scale = Vector2(display_size.x / source_rect.size.x, display_size.y / source_rect.size.y)
	_asset_sprite.visible = true
	return true


func _clear_asset_sprite() -> void:
	if _asset_sprite == null:
		return
	_asset_sprite.visible = false
	_asset_sprite.texture = null


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
	if BoardingEnemyVisualAssetCatalog.get_frame_count(_archetype_id, asset_state) > 0:
		return _archetype_id
	if BoardingEnemyVisualAssetCatalog.get_frame_count(FALLBACK_ASSET_ARCHETYPE_ID, asset_state) > 0:
		return FALLBACK_ASSET_ARCHETYPE_ID
	return &""


func _get_effective_asset_frame_count(asset_state: StringName) -> int:
	var asset_archetype_id: StringName = _resolve_asset_archetype_id(asset_state)
	if asset_archetype_id == &"":
		return 0
	return BoardingEnemyVisualAssetCatalog.get_frame_count(asset_archetype_id, asset_state)


func _append_candidate(candidates: Array[StringName], state_id: StringName) -> void:
	if state_id == &"" or state_id in candidates:
		return
	candidates.append(state_id)


func _get_asset_frame_index(logical_frame: int, asset_count: int, asset_state: StringName) -> int:
	if asset_count <= 1:
		return 0
	var logical_count: int = max(_get_frame_count(asset_state), 1)
	if logical_count <= 1:
		return 0
	var progress: float = float(clampi(logical_frame, 0, logical_count - 1)) / float(logical_count - 1)
	return clampi(roundi(progress * float(asset_count - 1)), 0, asset_count - 1)


func _get_asset_source_rect(texture: Texture2D) -> Rect2:
	if _asset_source_rect_cache.has(texture):
		return _asset_source_rect_cache[texture]
	var source_rect: Rect2 = TextureRegionLayout.get_alpha_bounds(texture, asset_alpha_crop_threshold)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		source_rect = Rect2(Vector2.ZERO, texture.get_size())
	_asset_source_rect_cache[texture] = source_rect
	return source_rect


func _draw_procedural_actor(frame: int) -> void:
	var phase: float = float(frame) * PI * 0.5
	var bob: float = 0.0
	var actor_rotation: float = 0.0
	match _presentation_state_id:
		&"idle":
			bob = sin(phase) * 1.0
		&"run":
			bob = -absf(sin(phase)) * 2.5
			actor_rotation = sin(phase) * 0.08
		&"climb":
			bob = -float(frame % 2) * 2.0
		&"jump":
			actor_rotation = sin(float(frame) / 5.0 * PI) * 0.18
		&"attack":
			actor_rotation = lerpf(-0.12, 0.18, float(frame) / 5.0)
		&"landing":
			actor_rotation = 0.12 - float(frame) * 0.06
		&"death":
			actor_rotation = float(frame) / 3.0 * 1.35
	var facing_scale: float = 1.0 if _animation.is_facing_right() else -1.0
	draw_set_transform(Vector2(0.0, bob), actor_rotation, Vector2(facing_scale, 1.0))
	_draw_fallback_silhouette(frame)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fallback_silhouette(frame: int) -> void:
	var body_color: Color = _body_color
	if _presentation_state_id == &"climb":
		body_color = body_color.lightened(0.18)
	elif _presentation_state_id == &"attack":
		body_color = body_color.darkened(0.12)
	elif _presentation_state_id == &"death":
		body_color.a = maxf(0.2, 1.0 - float(frame) * 0.22)
	match _archetype_id:
		&"runner":
			_draw_runner(body_color, frame)
		&"brute":
			_draw_brute(body_color, frame)
		&"rope_saboteur":
			_draw_rope_saboteur(body_color, frame)
		&"flyer":
			_draw_flyer(body_color, frame)
		_:
			_draw_basic_fallback(body_color, frame)
	_draw_eyes()


func _draw_basic_fallback(body_color: Color, frame: int) -> void:
	var stride: float = float(frame % 2) * 2.0
	draw_circle(Vector2(-2.0, 0.0), _body_radius, body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-_body_radius + 2.0, 1.0), Vector2(-_body_radius - 12.0, 6.0), Vector2(-_body_radius - 4.0, -3.0)]), body_color.darkened(0.12))
	draw_line(Vector2(-6.0, _body_radius - 1.0), Vector2(-8.0 - stride, _body_radius + 5.0), _accent_color, 3.0)
	draw_line(Vector2(5.0, _body_radius - 1.0), Vector2(8.0 + stride, _body_radius + 5.0), _accent_color, 3.0)
	draw_arc(Vector2(-2.0, 0.0), _body_radius, 0.0, TAU, 24, _accent_color, 2.0)


func _draw_runner(body_color: Color, frame: int) -> void:
	var stride: float = 5.0 if frame % 2 == 0 else -5.0
	draw_colored_polygon(PackedVector2Array([Vector2(-_body_radius - 10.0, 2.0), Vector2(-5.0, -_body_radius * 0.8), Vector2(_body_radius + 6.0, -4.0), Vector2(_body_radius, _body_radius * 0.65), Vector2(-5.0, _body_radius * 0.75)]), body_color)
	draw_line(Vector2(-4.0, 5.0), Vector2(-10.0 + stride, _body_radius + 8.0), _accent_color, 3.0)
	draw_line(Vector2(7.0, 4.0), Vector2(13.0 - stride, _body_radius + 7.0), _accent_color, 3.0)
	draw_line(Vector2(-_body_radius - 7.0, 2.0), Vector2(-_body_radius - 18.0, -2.0), body_color.darkened(0.15), 4.0)


func _draw_brute(body_color: Color, frame: int) -> void:
	var pulse: float = 1.0 + float(frame % 2) * 0.04
	var size := Vector2(_body_radius * 2.2, _body_radius * 1.8) * pulse
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, body_color, true)
	draw_rect(rect, _accent_color, false, 3.0)
	draw_line(Vector2(-size.x * 0.3, size.y * 0.5), Vector2(-size.x * 0.38, size.y * 0.75), _accent_color, 5.0)
	draw_line(Vector2(size.x * 0.3, size.y * 0.5), Vector2(size.x * 0.38, size.y * 0.75), _accent_color, 5.0)


func _draw_rope_saboteur(body_color: Color, frame: int) -> void:
	var abdomen_radius: float = _body_radius * (0.72 + float(frame % 2) * 0.08)
	draw_circle(Vector2(-4.0, 1.0), _body_radius * 0.65, body_color)
	draw_circle(Vector2(7.0, 2.0), abdomen_radius, _accent_color.darkened(0.1))
	for leg_index: int in range(3):
		var y: float = -5.0 + float(leg_index) * 5.0
		draw_line(Vector2(-2.0, y), Vector2(-12.0, y - 4.0), body_color.lightened(0.2), 2.0)
		draw_line(Vector2(3.0, y), Vector2(14.0, y + 4.0), body_color.lightened(0.2), 2.0)
	draw_arc(Vector2(7.0, 2.0), abdomen_radius, 0.0, TAU, 18, Color(1.0, 0.82, 0.2), 2.0)


func _draw_flyer(body_color: Color, frame: int) -> void:
	var flap: float = sin(float(frame) / 6.0 * TAU)
	var wing_y: float = -8.0 - flap * 8.0
	draw_circle(Vector2.ZERO, _body_radius, body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-_body_radius + 2.0, 0.0), Vector2(-_body_radius - 18.0, wing_y), Vector2(-_body_radius - 8.0, 10.0)]), _accent_color)
	draw_colored_polygon(PackedVector2Array([Vector2(_body_radius - 2.0, 0.0), Vector2(_body_radius + 18.0, wing_y), Vector2(_body_radius + 8.0, 10.0)]), _accent_color)
	draw_arc(Vector2.ZERO, _body_radius, 0.0, TAU, 24, _accent_color, 2.0)


func _draw_eyes() -> void:
	var eye_color := Color(0.05, 0.03, 0.03)
	draw_circle(Vector2(3.0, -3.0), 2.0, eye_color)
	draw_circle(Vector2(8.0, -2.0), 2.0, eye_color)


func _draw_health_bar() -> void:
	if _health == null or not is_instance_valid(_health):
		return
	var width: float = maxf(24.0, _body_radius * 2.0)
	var height: float = 4.0
	var top_y: float = -_body_radius - 12.0
	var asset_state: StringName = _resolve_asset_state(_presentation_state_id)
	if asset_state != &"":
		top_y = _body_radius + 4.0 - atlas_asset_height - 8.0
	var background := Rect2(Vector2(-width * 0.5, top_y), Vector2(width, height))
	draw_rect(background, Color(0.15, 0.08, 0.08), true)
	var ratio: float = float(_health.current_health) / float(maxi(1, _health.max_health))
	var fill := Rect2(background.position, Vector2(width * ratio, height))
	draw_rect(fill, _accent_color, true)


func _on_enemy_visual_state_changed(_enemy_id: int, state_id: StringName) -> void:
	_behavior_state_id = state_id


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	queue_redraw()
