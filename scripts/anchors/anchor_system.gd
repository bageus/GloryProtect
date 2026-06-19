class_name AnchorSystem
extends Node2D

signal anchor_state_changed(anchor_id: int, state: int)
signal anchor_attached(anchor_id: int)
signal anchor_removed(anchor_id: int)
signal anchor_overload_started(anchor_id: int)
signal anchor_broken(anchor_id: int)
signal command_rejected(anchor_id: int, reason: StringName)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("WindSystem") var wind_system_path: NodePath
@export_node_path("PlatformController") var platform_path: NodePath
@export var balance: AnchorBalance
@export var orb_x: float = 0.0
@export var ground_y: float = 510.0
@export var left_operator_assigned: bool = true
@export var right_operator_assigned: bool = true

var _store := AnchorRuntimeStore.new()
var _geometry := AnchorGeometry.new()
var _operations := AnchorOperationQueue.new()
var _constraints := AnchorConstraintProvider.new()
var _overload := AnchorOverloadController.new()
var _visual: AnchorVisualController

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _wind: WindSystem = get_node(wind_system_path)
@onready var _platform: PlatformController = get_node(platform_path)


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

	var key_event := event as InputEventKey
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
	if not _store.is_valid(anchor_id):
		return

	var anchor := _store.get_anchor(anchor_id)
	match anchor.state:
		AnchorRuntime.State.STOWED:
			_request_install(anchor)
		AnchorRuntime.State.ATTACHED, AnchorRuntime.State.OVERLOADED:
			_request_remove(anchor)
		_:
			command_rejected.emit(anchor_id, &"anchor_busy")


func request_remove_all() -> void:
	for side in [AnchorRuntime.Side.LEFT, AnchorRuntime.Side.RIGHT]:
		if _operations.request_remove_all(side):
			_remove_all_on_side(side)


func is_in_installation_zone() -> bool:
	return _geometry.is_in_installation_zone()


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


func set_operator_assigned(side: int, is_assigned: bool) -> void:
	if side == AnchorRuntime.Side.LEFT:
		left_operator_assigned = is_assigned
	else:
		right_operator_assigned = is_assigned

	if not is_assigned:
		_operations.cancel_queued(side)


func is_operator_assigned(side: int) -> bool:
	return left_operator_assigned if side == AnchorRuntime.Side.LEFT else right_operator_assigned


func _configure_components() -> void:
	_store.initialize()
	_geometry.configure(_platform, balance, orb_x, ground_y)
	_operations.configure(_store, _geometry, balance, _platform)
	_constraints.configure(_store, _geometry, balance, _platform, _wind)
	_overload.configure(_store, _constraints, balance, _wind)
	_constraints.update_full_fix_state()


func _connect_component_signals() -> void:
	_store.anchor_state_changed.connect(_on_anchor_state_changed)
	_operations.installation_finished.connect(_on_installation_finished)
	_overload.overload_started.connect(_on_overload_started)
	_overload.anchor_broken.connect(_on_anchor_broken)


func _create_visual_controller() -> void:
	_visual = AnchorVisualController.new()
	_visual.name = "AnchorVisualController"
	add_child(_visual)
	_visual.configure(
		_store,
		_geometry,
		balance,
		is_in_installation_zone,
		is_operator_assigned
	)


func _request_install(anchor: AnchorRuntime) -> void:
	if not is_in_installation_zone():
		command_rejected.emit(anchor.anchor_id, &"outside_installation_zone")
		return
	if not is_operator_assigned(anchor.side):
		command_rejected.emit(anchor.anchor_id, &"operator_missing")
		return
	_operations.request_install(anchor.anchor_id)


func _request_remove(anchor: AnchorRuntime) -> void:
	if not is_operator_assigned(anchor.side):
		command_rejected.emit(anchor.anchor_id, &"operator_missing")
		return

	# Timed removal will be added with physical operator animations.
	_store.set_stowed(anchor.anchor_id)
	anchor_removed.emit(anchor.anchor_id)


func _remove_all_on_side(side: int) -> void:
	for anchor in _store.get_holding_on_side(side):
		_store.set_stowed(anchor.anchor_id)
		anchor_removed.emit(anchor.anchor_id)


func _on_anchor_state_changed(anchor_id: int, state: int) -> void:
	anchor_state_changed.emit(anchor_id, state)


func _on_installation_finished(side: int, anchor_id: int, attached: bool) -> void:
	if attached:
		anchor_attached.emit(anchor_id)
	else:
		anchor_broken.emit(anchor_id)

	if _operations.consume_remove_all_pending(side):
		_operations.cancel_queued(side)
		_remove_all_on_side(side)
		return

	var can_start_next := is_in_installation_zone() and is_operator_assigned(side)
	_operations.start_next_if_allowed(side, can_start_next)


func _on_overload_started(anchor_id: int) -> void:
	anchor_overload_started.emit(anchor_id)


func _on_anchor_broken(anchor_id: int) -> void:
	anchor_broken.emit(anchor_id)
