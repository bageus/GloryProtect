class_name AnchorSystem
extends Node2D

signal anchor_state_changed(anchor_id: int, state: int)
signal anchor_attached(anchor_id: int)
signal anchor_removed(anchor_id: int)
signal anchor_overload_started(anchor_id: int)
signal anchor_broken(anchor_id: int)
signal anchor_recovery_started(
	anchor_id: int,
	source: StringName,
	removed_enemy_count: int
)
signal rope_durability_changed(
	anchor_id: int,
	current_durability: float,
	maximum_durability: float
)
signal rope_destroyed(anchor_id: int, source: StringName)
signal command_rejected(anchor_id: int, reason: StringName)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export_node_path("GroundOrbRegistry") var orb_registry_path: NodePath
@export_node_path("BoardingEnemyRegistry") var enemy_registry_path := NodePath("../BoardingEnemyRegistry")
@export var balance: AnchorBalance
@export var left_operator_assigned: bool = true
@export var right_operator_assigned: bool = true

var _store: AnchorRuntimeStore = AnchorRuntimeStore.new()
var _geometry: AnchorGeometry = AnchorGeometry.new()
var _operations: AnchorOperationQueue = AnchorOperationQueue.new()
var _constraints: AnchorConstraintProvider = AnchorConstraintProvider.new()
var _overload: AnchorOverloadController = AnchorOverloadController.new()
var _commands: AnchorCommandController = AnchorCommandController.new()
var _rope_durability: AnchorRopeDurability = AnchorRopeDurability.new()
var _recovery: AnchorBreakRecoveryController = AnchorBreakRecoveryController.new()
var _visual: AnchorVisualController

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _platform: PlatformController = get_node(platform_path)
@onready var _orb_registry: GroundOrbRegistry = get_node(orb_registry_path)
@onready var _enemy_registry: BoardingEnemyRegistry = get_node(enemy_registry_path)


func _ready() -> void:
	assert(balance != null, "AnchorSystem requires AnchorBalance")
	process_physics_priority = -20
	_configure_components()
	_connect_component_signals()
	_create_visual_controller()


func _physics_process(delta: float) -> void:
	if not _game_flow.is_world_simulation_active():
		return

	_operations.tick(delta)
	_overload.tick(delta)
	_constraints.update_full_fix_state()


func _unhandled_input(event: InputEvent) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_1:
			toggle_anchor(0)
		KEY_2:
			toggle_anchor(1)
		KEY_3:
			toggle_anchor(2)
		KEY_4:
			toggle_anchor(3)
		KEY_R:
			request_remove_all()
		_:
			return
	get_viewport().set_input_as_handled()


func toggle_anchor(anchor_id: int) -> void:
	_commands.toggle(anchor_id)


func request_remove_all() -> void:
	_commands.request_remove_all()


func apply_rope_damage(
	anchor_id: int,
	amount: float,
	source: StringName = &"unknown"
) -> bool:
	return _rope_durability.apply_damage(anchor_id, amount, source)


func get_rope_snapshot(anchor_id: int) -> AnchorRopeSnapshot:
	return _rope_durability.get_snapshot(anchor_id)


func get_all_rope_snapshots() -> Array[AnchorRopeSnapshot]:
	return _rope_durability.get_all_snapshots()


func get_anchor_state(anchor_id: int) -> int:
	if not _store.is_valid(anchor_id):
		return -1
	return _store.get_anchor(anchor_id).state


func is_in_installation_zone() -> bool:
	return _geometry.is_in_installation_zone()


func get_installation_orb_id() -> int:
	return _geometry.get_current_installation_orb_id()


func is_fully_fixed() -> bool:
	return _constraints.is_fully_fixed()


func get_fixed_platform_x() -> float:
	return _constraints.get_fixed_platform_x()


func get_minimum_platform_x() -> float:
	return _constraints.get_minimum_platform_x()


func get_maximum_platform_x() -> float:
	return _constraints.get_maximum_platform_x()


func get_state_summary() -> String:
	return _store.get_state_summary()


func get_active_path_count() -> int:
	var count: int = 0
	for anchor: AnchorRuntime in _store.get_all():
		if anchor.is_holding():
			count += 1
	return count


func is_path_available(anchor_id: int) -> bool:
	return (
		_store.is_valid(anchor_id)
		and _store.get_anchor(anchor_id).is_holding()
	)


func get_path_snapshot(anchor_id: int) -> AnchorPathSnapshot:
	if not is_path_available(anchor_id):
		return null
	var anchor: AnchorRuntime = _store.get_anchor(anchor_id)
	return AnchorPathSnapshot.new(
		anchor.anchor_id,
		anchor.side,
		anchor.attached_orb_id,
		anchor.attached_ground_point,
		_geometry.get_platform_attachment_world(anchor.anchor_id)
	)


func get_active_path_snapshots() -> Array[AnchorPathSnapshot]:
	var paths: Array[AnchorPathSnapshot] = []
	for anchor: AnchorRuntime in _store.get_all():
		if not anchor.is_holding():
			continue
		paths.append(
			AnchorPathSnapshot.new(
				anchor.anchor_id,
				anchor.side,
				anchor.attached_orb_id,
				anchor.attached_ground_point,
				_geometry.get_platform_attachment_world(anchor.anchor_id)
			)
		)
	return paths


func set_operator_assigned(side: int, is_assigned: bool) -> void:
	if side == AnchorRuntime.Side.LEFT:
		left_operator_assigned = is_assigned
	else:
		right_operator_assigned = is_assigned
	_commands.operator_availability_changed(side, is_assigned)


func is_operator_assigned(side: int) -> bool:
	if side == AnchorRuntime.Side.LEFT:
		return left_operator_assigned
	return right_operator_assigned


func is_operator_busy(side: int) -> bool:
	return _operations.has_active_install(side)


func _configure_components() -> void:
	_store.initialize()
	_geometry.configure(_platform, balance, _orb_registry)
	_operations.configure(_store, _geometry, balance, _platform)
	_constraints.configure(_store, _geometry, balance, _platform, _wind)
	_overload.configure(_store, _constraints, balance, _wind)
	_commands.configure(
		_store,
		_geometry,
		_operations,
		Callable(self, "is_operator_assigned")
	)
	_rope_durability.configure(_store, balance)
	_recovery.configure(
		_store,
		_operations,
		_constraints,
		_enemy_registry
	)
	_constraints.update_full_fix_state()


func _connect_component_signals() -> void:
	_store.anchor_state_changed.connect(_on_anchor_state_changed)
	_operations.installation_finished.connect(_on_installation_finished)
	_overload.overload_started.connect(_on_overload_started)
	_overload.anchor_broken.connect(_on_anchor_broken)
	_commands.anchor_removed.connect(_on_anchor_removed)
	_commands.command_rejected.connect(_on_command_rejected)
	_rope_durability.durability_changed.connect(
		_on_rope_durability_changed
	)
	_rope_durability.rope_destroyed.connect(_on_rope_destroyed)
	_recovery.recovery_started.connect(_on_recovery_started)


func _create_visual_controller() -> void:
	_visual = AnchorVisualController.new()
	_visual.name = "AnchorVisualController"
	add_child(_visual)
	_visual.configure(
		_store,
		_geometry,
		balance,
		Callable(self, "is_operator_assigned"),
		Callable(_game_flow, "is_world_simulation_active")
	)


func _on_anchor_state_changed(anchor_id: int, state: int) -> void:
	anchor_state_changed.emit(anchor_id, state)


func _on_installation_finished(side: int, anchor_id: int, attached: bool) -> void:
	if attached:
		anchor_attached.emit(anchor_id)
	else:
		anchor_broken.emit(anchor_id)

	if _operations.consume_remove_all_pending(side):
		_operations.cancel_queued(side)
		_commands.remove_all_on_side(side)
		return

	_operations.start_next_if_allowed(side, is_operator_assigned(side))


func _on_overload_started(anchor_id: int) -> void:
	anchor_overload_started.emit(anchor_id)


func _on_anchor_broken(anchor_id: int) -> void:
	_recovery.recover(anchor_id, &"wind_overload")
	anchor_broken.emit(anchor_id)


func _on_anchor_removed(anchor_id: int) -> void:
	anchor_removed.emit(anchor_id)


func _on_rope_durability_changed(
	anchor_id: int,
	current_durability: float,
	maximum_durability: float
) -> void:
	rope_durability_changed.emit(
		anchor_id,
		current_durability,
		maximum_durability
	)


func _on_rope_destroyed(anchor_id: int, source: StringName) -> void:
	_recovery.recover(anchor_id, source)
	rope_destroyed.emit(anchor_id, source)
	anchor_broken.emit(anchor_id)


func _on_recovery_started(
	anchor_id: int,
	source: StringName,
	removed_enemy_count: int
) -> void:
	anchor_recovery_started.emit(
		anchor_id,
		source,
		removed_enemy_count
	)


func _on_command_rejected(anchor_id: int, reason: StringName) -> void:
	command_rejected.emit(anchor_id, reason)
