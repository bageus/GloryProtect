class_name TurretVisualController
extends Node2D

const TURRET_POST_TEXTURE: Texture2D = preload(
	"res://visual/objects/asset_object_turret_post.png"
)
const ALPHA_CROP_THRESHOLD: float = 0.08

@export_range(0.05, 0.5, 0.01) var turret_asset_scale: float = 0.24
@export var turret_surface_offset: Vector2 = Vector2.ZERO

var _visuals: Dictionary[int, TurretVisualRuntime] = {}
var _platform: PlatformController
var _grid: BuildableGrid
var _turrets: TurretSystem
var _input: TurretDebugInput
var _enemies: BoardingEnemyRegistry
var _balance: BuildableBalance
var _configured: bool = false
var _turret_source_rect: Rect2


func configure(
	platform: PlatformController,
	grid: BuildableGrid,
	turrets: TurretSystem,
	turret_input: TurretDebugInput,
	enemies: BoardingEnemyRegistry,
	balance: BuildableBalance
) -> void:
	_platform = platform
	_grid = grid
	_turrets = turrets
	_input = turret_input
	_enemies = enemies
	_balance = balance
	_configured = true


func _ready() -> void:
	assert(_configured, "TurretVisualController must be configured")
	assert(_balance != null, "TurretVisualController requires BuildableBalance")
	_turret_source_rect = _get_alpha_bounds(TURRET_POST_TEXTURE)
	_turrets.turret_registered.connect(_on_turret_registered)
	_turrets.turret_removed.connect(_on_turret_removed)
	_turrets.shot_started.connect(_on_shot_started)
	_turrets.shot_completed.connect(_on_shot_completed)
	_turrets.shot_cancelled.connect(_on_shot_cancelled)
	_grid.buildable_moved.connect(_on_buildable_moved)
	_input.selected_turret_changed.connect(_on_selected_turret_changed)
	_sync_visuals()
	queue_redraw()


func _process(delta: float) -> void:
	for runtime: TurretVisualRuntime in _visuals.values():
		runtime.tick(maxf(0.0, delta))
		_update_target_position(runtime)
	queue_redraw()


func _draw() -> void:
	var selected_id: int = _input.get_selected_turret_id()
	for buildable_id: int in _turrets.get_turret_ids():
		var snapshot: BuildableSnapshot = _grid.get_snapshot(buildable_id)
		if snapshot == null:
			continue
		var pivot: Vector2 = TurretGeometry.get_local_pivot(snapshot, _balance)
		var runtime: TurretVisualRuntime = _visuals.get(buildable_id)
		var operational: bool = _turrets.is_operational(buildable_id)
		var firing: bool = _turrets.is_firing(buildable_id)

		if buildable_id == selected_id:
			_draw_range(pivot, operational)

		var relocated_during_shot: bool = (
			firing
			and runtime != null
			and runtime.shot_origin_local.distance_to(pivot) > 1.0
		)
		if relocated_during_shot:
			_draw_turret_body(
				buildable_id,
				pivot,
				false,
				false,
				runtime,
				buildable_id == selected_id
			)
			_draw_turret_body(
				buildable_id,
				runtime.shot_origin_local,
				true,
				true,
				runtime,
				false
			)
		else:
			_draw_turret_body(
				buildable_id,
				pivot,
				operational,
				firing,
				runtime,
				buildable_id == selected_id
			)

		if runtime != null:
			_draw_shot_effects(runtime)


func _draw_range(pivot: Vector2, operational: bool) -> void:
	var range_color := Color(
		0.22,
		0.78,
		1.0,
		_balance.turret_radius_fill_alpha
	)
	var outline_color := Color(0.38, 0.88, 1.0, 0.68)
	if not operational:
		range_color = Color(
			0.5,
			0.55,
			0.62,
			_balance.turret_radius_fill_alpha
		)
		outline_color = Color(0.58, 0.62, 0.68, 0.5)
	draw_circle(pivot, _balance.turret_range, range_color)
	draw_arc(
		pivot,
		_balance.turret_range,
		0.0,
		TAU,
		96,
		outline_color,
		2.0
	)


func _draw_turret_body(
	buildable_id: int,
	pivot: Vector2,
	operational: bool,
	firing: bool,
	runtime: TurretVisualRuntime,
	selected: bool
) -> void:
	var alpha: float = _balance.turret_inactive_alpha
	if operational:
		alpha = 1.0

	var asset_size: Vector2 = _turret_source_rect.size * turret_asset_scale
	var bottom_center := Vector2(
		pivot.x + turret_surface_offset.x,
		_balance.turret_bottom_y + turret_surface_offset.y
	)
	var asset_rect := Rect2(
		bottom_center - Vector2(asset_size.x * 0.5, asset_size.y),
		asset_size
	)
	draw_texture_rect_region(
		TURRET_POST_TEXTURE,
		asset_rect,
		_turret_source_rect,
		Color(1.0, 1.0, 1.0, alpha)
	)

	var aim_direction: Vector2 = _get_aim_direction(pivot, runtime)
	var recoil: float = _get_recoil(runtime)
	var barrel_length: float = maxf(
		8.0,
		_balance.turret_barrel_length - recoil
	)
	var muzzle: Vector2 = pivot + aim_direction * barrel_length

	if firing:
		_draw_charge(buildable_id, pivot, muzzle)
	else:
		_draw_cooldown(buildable_id, pivot)

	var indicator_color := Color(0.25, 0.95, 0.75, alpha)
	if not operational:
		indicator_color = Color(1.0, 0.35, 0.25, alpha)
	draw_circle(
		asset_rect.position + Vector2(asset_rect.size.x * 0.5, 8.0),
		3.5,
		indicator_color
	)

	if selected:
		draw_rect(
			asset_rect.grow(4.0),
			Color(1.0, 0.84, 0.3),
			false,
			3.0
		)


func _draw_charge(buildable_id: int, pivot: Vector2, muzzle: Vector2) -> void:
	var progress: float = _turrets.get_shot_progress(buildable_id)
	var charge_radius: float = 4.0 + progress * 8.0
	draw_circle(
		muzzle,
		charge_radius,
		Color(0.25, 0.9, 1.0, 0.18 + progress * 0.5)
	)
	draw_arc(
		pivot,
		_balance.turret_width * 0.36,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		24,
		Color(0.4, 0.95, 1.0),
		3.0
	)


func _draw_cooldown(buildable_id: int, pivot: Vector2) -> void:
	var remaining: float = _turrets.get_cooldown_remaining(buildable_id)
	if remaining <= 0.0 or _balance.turret_shot_cooldown <= 0.0:
		return
	var progress: float = clampf(
		1.0 - remaining / _balance.turret_shot_cooldown,
		0.0,
		1.0
	)
	draw_arc(
		pivot,
		_balance.turret_width * 0.36,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		24,
		Color(0.7, 0.78, 0.86, 0.8),
		2.0
	)


func _draw_shot_effects(runtime: TurretVisualRuntime) -> void:
	if not runtime.is_effect_active():
		return
	var aim_direction: Vector2 = _get_aim_direction(
		runtime.shot_origin_local,
		runtime
	)
	var muzzle: Vector2 = (
		runtime.shot_origin_local
		+ aim_direction * _balance.turret_barrel_length
	)
	var target_local: Vector2 = to_local(runtime.last_target_world)

	if runtime.tracer_remaining > 0.0:
		var tracer_alpha: float = clampf(
			runtime.tracer_remaining / _balance.turret_tracer_duration,
			0.0,
			1.0
		)
		draw_line(
			muzzle,
			target_local,
			Color(0.62, 0.96, 1.0, tracer_alpha),
			3.0
		)
		draw_circle(
			target_local,
			4.0 * tracer_alpha,
			Color(0.8, 1.0, 1.0, tracer_alpha)
		)

	if runtime.flash_remaining > 0.0:
		var flash_alpha: float = clampf(
			runtime.flash_remaining / _balance.turret_flash_duration,
			0.0,
			1.0
		)
		draw_circle(
			muzzle,
			10.0 * flash_alpha,
			Color(0.7, 1.0, 1.0, flash_alpha)
		)
		var normal: Vector2 = aim_direction.rotated(PI * 0.5)
		draw_line(
			muzzle - normal * 8.0 * flash_alpha,
			muzzle + normal * 8.0 * flash_alpha,
			Color(0.9, 1.0, 1.0, flash_alpha),
			2.0
		)


func _get_aim_direction(
	origin_local: Vector2,
	runtime: TurretVisualRuntime
) -> Vector2:
	if runtime == null or runtime.last_target_world == Vector2.ZERO:
		return TurretGeometry.get_default_aim_direction()
	var direction: Vector2 = to_local(runtime.last_target_world) - origin_local
	if direction.length_squared() <= 0.001:
		return TurretGeometry.get_default_aim_direction()
	return direction.normalized()


func _get_recoil(runtime: TurretVisualRuntime) -> float:
	if runtime == null or runtime.flash_remaining <= 0.0:
		return 0.0
	return _balance.turret_recoil_distance * clampf(
		runtime.flash_remaining / _balance.turret_flash_duration,
		0.0,
		1.0
	)


func _update_target_position(runtime: TurretVisualRuntime) -> void:
	if runtime.target_enemy_id < 0:
		return
	var enemy: BoardingEnemy = _enemies.get_enemy(runtime.target_enemy_id)
	if enemy != null and is_instance_valid(enemy):
		runtime.update_target(enemy.global_position)


func _sync_visuals() -> void:
	for buildable_id: int in _turrets.get_turret_ids():
		_ensure_visual(buildable_id)


func _ensure_visual(buildable_id: int) -> TurretVisualRuntime:
	var runtime: TurretVisualRuntime = _visuals.get(buildable_id)
	if runtime == null:
		runtime = TurretVisualRuntime.new(buildable_id)
		_visuals[buildable_id] = runtime
	return runtime


func _on_turret_registered(buildable_id: int) -> void:
	_ensure_visual(buildable_id)
	queue_redraw()


func _on_turret_removed(buildable_id: int) -> void:
	_visuals.erase(buildable_id)
	queue_redraw()


func _on_shot_started(
	buildable_id: int,
	_operator_id: int,
	enemy_id: int
) -> void:
	var snapshot: BuildableSnapshot = _grid.get_snapshot(buildable_id)
	var enemy: BoardingEnemy = _enemies.get_enemy(enemy_id)
	if snapshot == null or enemy == null:
		return
	_ensure_visual(buildable_id).begin_target(
		enemy_id,
		TurretGeometry.get_local_pivot(snapshot, _balance),
		enemy.global_position
	)
	queue_redraw()


func _on_shot_completed(
	buildable_id: int,
	_enemy_id: int,
	_hit: bool
) -> void:
	_ensure_visual(buildable_id).resolve_shot(
		_balance.turret_tracer_duration,
		_balance.turret_flash_duration
	)
	queue_redraw()


func _on_shot_cancelled(buildable_id: int, _enemy_id: int) -> void:
	_ensure_visual(buildable_id).cancel_target()
	queue_redraw()


func _on_buildable_moved(
	buildable_id: int,
	_previous_cell: int,
	_cell_index: int
) -> void:
	if _turrets.has_turret(buildable_id):
		queue_redraw()


func _on_selected_turret_changed(_buildable_id: int) -> void:
	queue_redraw()


func _get_alpha_bounds(texture: Texture2D) -> Rect2:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())

	var width: int = image.get_width()
	var height: int = image.get_height()
	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1

	for y: int in range(height):
		for x: int in range(width):
			if image.get_pixel(x, y).a <= ALPHA_CROP_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2.ZERO, texture.get_size())

	return Rect2(
		Vector2(float(min_x), float(min_y)),
		Vector2(
			float(max_x - min_x + 1),
			float(max_y - min_y + 1)
		)
	)
