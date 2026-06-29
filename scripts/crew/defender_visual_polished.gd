class_name DefenderVisualPolished
extends DefenderVisual

const MEDIC_FALLBACK_TEXTURE: Texture2D = preload(
	"res://visual/defenders/ChatGPT Image Jun 24, 2026, 12_29_17 AM.png"
)

@export_range(0.0, 80.0, 1.0) var driver_health_bar_raise: float = 34.0
@export_range(1.0, 30.0, 0.5) var heal_frame_rate: float = 6.0

var _animation: CharacterAnimationController = CharacterAnimationController.new()
var _ranged: RangedAttackComponent
var _durability: DefenderDurabilityComponent
var _medic_source_rect: Rect2
var _presentation_state_id: StringName = &"idle"


func _ready() -> void:
	super._ready()
	_ranged = get_node("../RangedAttackComponent") as RangedAttackComponent
	_durability = get_node(
		"../DefenderDurabilityComponent"
	) as DefenderDurabilityComponent
	_medic_source_rect = _get_cached_alpha_bounds(MEDIC_FALLBACK_TEXTURE)
	if _ranged != null:
		_ranged.attack_started.connect(_on_ranged_attack_started)
		_ranged.attack_finished.connect(_on_ranged_attack_finished)
	if _durability != null:
		_durability.armor_changed.connect(_on_armor_changed)
	_animation.play(&"idle", WARRIOR_IDLE_TEXTURES.size(), idle_frame_rate)
	_sync_base_animation_fields()


func _process(delta: float) -> void:
	if _state == AnimationState.HIDDEN:
		return
	if _state == AnimationState.DYING:
		_update_death_presentation(delta)
		queue_redraw()
		return

	var next_state: StringName = _resolve_presentation_state()
	match next_state:
		&"attack":
			_update_attack_presentation()
		&"run":
			_update_run_presentation(delta)
		&"heal":
			_update_heal_presentation(delta)
		_:
			_update_idle_presentation(delta)
	_sync_base_animation_fields()
	queue_redraw()


func play_death() -> void:
	if _state == AnimationState.DYING or _state == AnimationState.HIDDEN:
		return
	_state = AnimationState.DYING
	_presentation_state_id = &"death"
	_animation.set_facing_right(_facing_right)
	_animation.play(
		&"death",
		WARRIOR_DIE_RIGHT_TEXTURES.size(),
		death_frame_rate,
		false,
		true
	)
	_sync_base_animation_fields()
	visible = true
	if _defender != null:
		_defender.visible = true
	queue_redraw()


func get_presentation_state_id() -> StringName:
	return _presentation_state_id


func get_health_bar_raise() -> float:
	return driver_health_bar_raise if _is_live_driver() else 0.0


func get_current_armor_segments() -> int:
	return _durability.get_current_armor() if _durability != null else 0


func get_max_armor_segments() -> int:
	return _durability.get_max_armor() if _durability != null else 0


func has_visible_armor_segments() -> bool:
	return _durability != null and _durability.get_current_armor() > 0


func _draw() -> void:
	var bob_offset: float = 0.0
	if _presentation_state_id == &"heal":
		bob_offset = -float(_animation.get_frame_index() % 2)
	elif _presentation_state_id == &"run" and _role_id == CrewRole.Id.MEDIC:
		bob_offset = -float(_animation.get_frame_index() % 2) * 1.5
	draw_set_transform(Vector2(0.0, bob_offset))
	super._draw()
	draw_set_transform(Vector2.ZERO)


func _draw_health_segments(asset_rect: Rect2) -> void:
	var adjusted_rect := asset_rect
	adjusted_rect.position.y -= get_health_bar_raise()
	super._draw_health_segments(adjusted_rect)
	_draw_armor_segments(adjusted_rect)


func _draw_armor_segments(asset_rect: Rect2) -> void:
	if not has_visible_armor_segments():
		return
	var current_armor: int = _durability.get_current_armor()
	var segment_width: float = 8.0
	var segment_height: float = 4.0
	var gap: float = 2.0
	var total_width: float = (
		float(current_armor) * segment_width
		+ float(current_armor - 1) * gap
	)
	var start_x: float = asset_rect.get_center().x - total_width * 0.5
	var health_y: float = asset_rect.position.y - 8.0
	var armor_y: float = health_y - segment_height - 3.0
	for index: int in range(current_armor):
		var rect := Rect2(
			Vector2(
				start_x + float(index) * (segment_width + gap),
				armor_y
			),
			Vector2(segment_width, segment_height)
		)
		draw_rect(rect, Color(0.28, 0.7, 1.0), true)
		draw_rect(rect, Color(0.72, 0.88, 1.0), false, 1.0)


func _get_current_texture() -> Texture2D:
	if _state == AnimationState.DYING:
		return super._get_current_texture()
	if _role_id == CrewRole.Id.DRIVER:
		return null
	if _role_id == CrewRole.Id.MEDIC:
		return MEDIC_FALLBACK_TEXTURE
	return super._get_current_texture()


func _get_current_source_rect() -> Rect2:
	if _state == AnimationState.DYING:
		return super._get_current_source_rect()
	if _role_id == CrewRole.Id.DRIVER:
		return Rect2(Vector2.ZERO, Vector2(asset_max_width, asset_height))
	if _role_id == CrewRole.Id.MEDIC:
		return _medic_source_rect
	return super._get_current_source_rect()


func _resolve_presentation_state() -> StringName:
	if _is_domain_attack_in_windup():
		return &"attack"
	if _is_medic_healing():
		return &"heal"
	if (
		_movement != null
		and _movement.is_moving()
		and not _movement.is_paused()
	):
		return &"run"
	return &"idle"


func _update_attack_presentation() -> void:
	_presentation_state_id = &"attack"
	_state = AnimationState.ATTACK
	_animation.set_facing_right(_facing_right)
	_animation.play(
		&"attack",
		WARRIOR_ATTACK_RIGHT_TEXTURES.size(),
		attack_frame_rate,
		false
	)
	_animation.set_normalized_progress(_get_domain_attack_progress())


func _update_run_presentation(delta: float) -> void:
	_presentation_state_id = &"run"
	_state = AnimationState.RUN
	if _movement != null and _defender != null:
		_animation.face_delta(_movement.get_target_x() - _defender.position.x)
	_animation.play(&"run", WARRIOR_RUN_RIGHT_TEXTURES.size(), run_frame_rate)
	_animation.tick(delta)


func _update_heal_presentation(delta: float) -> void:
	_presentation_state_id = &"heal"
	_state = AnimationState.IDLE
	_animation.play(&"heal", 4, heal_frame_rate)
	_animation.tick(delta)


func _update_idle_presentation(delta: float) -> void:
	_presentation_state_id = &"idle"
	_state = AnimationState.IDLE
	_animation.play(&"idle", WARRIOR_IDLE_TEXTURES.size(), idle_frame_rate)
	_animation.tick(delta)


func _update_death_presentation(delta: float) -> void:
	_presentation_state_id = &"death"
	_animation.play(
		&"death",
		WARRIOR_DIE_RIGHT_TEXTURES.size(),
		death_frame_rate,
		false
	)
	_animation.tick(delta)
	_sync_base_animation_fields()
	if _animation.is_finished():
		_finish_death_animation()


func _is_domain_attack_in_windup() -> bool:
	return (
		_melee != null
		and _melee.get_phase() == MeleeAttackComponent.Phase.WINDUP
	) or (
		_ranged != null
		and _ranged.get_phase() == RangedAttackComponent.Phase.WINDUP
	)


func _get_domain_attack_progress() -> float:
	if _melee != null and _melee.get_phase() == MeleeAttackComponent.Phase.WINDUP:
		return _melee.get_windup_progress()
	if _ranged != null and _ranged.get_phase() == RangedAttackComponent.Phase.WINDUP:
		return _ranged.get_windup_progress()
	return 0.0


func _is_medic_healing() -> bool:
	return (
		_defender != null
		and _role_id == CrewRole.Id.MEDIC
		and _defender.is_medic_healing_action_active()
	)


func _sync_base_animation_fields() -> void:
	_frame_index = _animation.get_frame_index()
	_facing_right = _animation.is_facing_right()
	_frame_elapsed = 0.0


func _on_ranged_attack_started(target: HealthComponent) -> void:
	if _state == AnimationState.DYING or _state == AnimationState.HIDDEN:
		return
	var target_actor: Node2D = target.get_parent() as Node2D
	if target_actor != null and _defender != null:
		_facing_right = target_actor.global_position.x >= _defender.global_position.x
	_animation.set_facing_right(_facing_right)
	_animation.play(
		&"attack",
		WARRIOR_ATTACK_RIGHT_TEXTURES.size(),
		attack_frame_rate,
		false,
		true
	)


func _on_ranged_attack_finished() -> void:
	if _state == AnimationState.ATTACK:
		_presentation_state_id = &"idle"


func _on_armor_changed(_current_armor: int, _max_armor: int) -> void:
	queue_redraw()


func _is_live_driver() -> bool:
	if _role_manager != null and _defender != null:
		var assignment: CrewAssignmentRuntime = _role_manager.get_assignment(
			_defender.defender_id
		)
		if assignment != null:
			return (
				assignment.current_role == CrewRole.Id.DRIVER
				and assignment.state == CrewAssignmentRuntime.State.ACTIVE
			)
	return _role_id == CrewRole.Id.DRIVER
