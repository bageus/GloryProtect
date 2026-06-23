class_name DefenderVisual
extends Node2D

const REGULAR_TEXTURE: Texture2D = preload(
	"res://visual/defenders/ChatGPT Image Jun 24, 2026, 12_14_07 AM.png"
)
const DRIVER_TEXTURE: Texture2D = preload(
	"res://visual/defenders/ChatGPT Image Jun 24, 2026, 12_28_49 AM.png"
)
const MEDIC_TEXTURE: Texture2D = preload(
	"res://visual/defenders/ChatGPT Image Jun 24, 2026, 12_29_17 AM.png"
)

@export_node_path("HealthComponent") var health_path: NodePath
@export_node_path("StatusEffectComponent") var status_effects_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath = NodePath(
	"../../CrewRoleManager"
)
@export_range(4.0, 40.0, 1.0) var body_radius: float = 14.0
@export var body_color: Color = Color(0.45, 0.8, 1.0)
@export_group("Defender Assets")
@export_range(32.0, 128.0, 1.0) var asset_height: float = 72.0
@export_range(32.0, 128.0, 1.0) var asset_max_width: float = 72.0
@export_range(0.0, 1.0, 0.01) var alpha_crop_threshold: float = 0.08
@export var asset_offset: Vector2 = Vector2.ZERO

var _selected: bool = false
var _poisoned: bool = false
var _poison_stacks: int = 0
var _role_id: int = CrewRole.Id.FREE_FIGHTER
var _regular_source_rect: Rect2
var _driver_source_rect: Rect2
var _medic_source_rect: Rect2
var _defender: Defender
var _role_manager: CrewRoleManager

@onready var _health: HealthComponent = get_node(health_path)
@onready var _status_effects: StatusEffectComponent = get_node(status_effects_path)


func _ready() -> void:
	_regular_source_rect = TextureRegionLayout.get_alpha_bounds(
		REGULAR_TEXTURE,
		alpha_crop_threshold
	)
	_driver_source_rect = TextureRegionLayout.get_alpha_bounds(
		DRIVER_TEXTURE,
		alpha_crop_threshold
	)
	_medic_source_rect = TextureRegionLayout.get_alpha_bounds(
		MEDIC_TEXTURE,
		alpha_crop_threshold
	)
	_defender = get_parent() as Defender
	_role_manager = get_node_or_null(role_manager_path) as CrewRoleManager
	if _role_manager != null:
		_role_manager.assignment_changed.connect(_on_assignment_changed)
		_sync_role_from_manager()
	_health.health_changed.connect(_on_health_changed)
	_status_effects.poison_changed.connect(_on_poison_changed)
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


func _draw() -> void:
	var source_rect: Rect2 = _get_current_source_rect()
	var asset_size: Vector2 = _fit_asset_size(source_rect.size)
	var feet := Vector2(0.0, body_radius) + asset_offset

	if _selected:
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

	var tint := Color.WHITE
	if _poisoned:
		tint = Color(0.72, 1.0, 0.62, 1.0)
	var asset_rect := Rect2(
		feet - Vector2(asset_size.x * 0.5, asset_size.y),
		asset_size
	)
	draw_texture_rect_region(
		_get_current_texture(),
		asset_rect,
		source_rect,
		tint
	)

	if _poisoned:
		_draw_poison_indicator(asset_rect)
	_draw_health_segments(asset_rect)


func _get_current_texture() -> Texture2D:
	match _role_id:
		CrewRole.Id.DRIVER:
			return DRIVER_TEXTURE
		CrewRole.Id.MEDIC:
			return MEDIC_TEXTURE
		_:
			return REGULAR_TEXTURE


func _get_current_source_rect() -> Rect2:
	match _role_id:
		CrewRole.Id.DRIVER:
			return _driver_source_rect
		CrewRole.Id.MEDIC:
			return _medic_source_rect
		_:
			return _regular_source_rect


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
	var start_x := -total_width * 0.5
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
	_state: int
) -> void:
	if _defender == null or defender_id != _defender.defender_id:
		return
	set_role(current_role)


func _on_health_changed(_current_health: int, _max_health: int) -> void:
	queue_redraw()


func _on_poison_changed(active: bool, stacks: int, _remaining: float) -> void:
	_poisoned = active
	_poison_stacks = stacks
	queue_redraw()
