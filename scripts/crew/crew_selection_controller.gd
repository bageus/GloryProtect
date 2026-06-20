class_name CrewSelectionController
extends Node

signal selected_defender_changed(defender_id: int)

@export_node_path("GameFlowController") var game_flow_path: NodePath
@export_node_path("CrewManager") var crew_manager_path: NodePath
@export_node_path("CrewRoleManager") var role_manager_path: NodePath

var selected_defender_id: int = 0

@onready var _game_flow: GameFlowController = get_node(game_flow_path)
@onready var _crew: CrewManager = get_node(crew_manager_path)
@onready var _roles: CrewRoleManager = get_node(role_manager_path)


func _ready() -> void:
	_crew.defender_spawned.connect(_on_defender_spawned)
	_crew.defender_replaced.connect(_on_defender_replaced)
	call_deferred("_apply_selection_visuals")


func _unhandled_input(event: InputEvent) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	if event is InputEventKey:
		_handle_keyboard(event as InputEventKey)
	elif event is InputEventMouseButton:
		_handle_world_click(event as InputEventMouseButton)


func select_defender(defender_id: int) -> bool:
	if _crew.get_defender(defender_id) == null:
		return false
	selected_defender_id = defender_id
	_apply_selection_visuals()
	selected_defender_changed.emit(selected_defender_id)
	return true


func get_selected_defender_id() -> int:
	return selected_defender_id


func get_selected_defender() -> Defender:
	return _crew.get_defender(selected_defender_id)


func get_crew_manager() -> CrewManager:
	return _crew


func _handle_keyboard(key_event: InputEventKey) -> void:
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_5:
			select_defender(0)
		KEY_6:
			select_defender(1)
		KEY_7:
			select_defender(2)
		KEY_D:
			_roles.request_assignment(
				selected_defender_id,
				CrewRole.Id.DRIVER
			)
		KEY_Z:
			_roles.request_assignment(
				selected_defender_id,
				CrewRole.Id.LEFT_ANCHOR
			)
		KEY_X:
			_roles.request_assignment(
				selected_defender_id,
				CrewRole.Id.RIGHT_ANCHOR
			)
		KEY_C:
			_roles.request_assignment(
				selected_defender_id,
				CrewRole.Id.FREE_FIGHTER
			)
		_:
			return
	get_viewport().set_input_as_handled()


func _handle_world_click(mouse_event: InputEventMouseButton) -> void:
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var world_position: Vector2 = (
		get_viewport().get_canvas_transform().affine_inverse()
		* mouse_event.position
	)
	var nearest: Defender = null
	var nearest_distance_squared: float = INF
	for defender: Defender in _crew.get_living_defenders():
		var hit_radius: float = defender.visual.body_radius + 12.0
		var distance_squared: float = defender.global_position.distance_squared_to(
			world_position
		)
		if distance_squared > hit_radius * hit_radius:
			continue
		if distance_squared < nearest_distance_squared:
			nearest = defender
			nearest_distance_squared = distance_squared
	if nearest == null:
		return
	if select_defender(nearest.defender_id):
		get_viewport().set_input_as_handled()


func _apply_selection_visuals() -> void:
	for defender: Defender in _crew.get_all_defenders():
		defender.visual.set_selected(
			defender.defender_id == selected_defender_id
		)


func _on_defender_spawned(_defender_id: int, _defender: Defender) -> void:
	call_deferred("_apply_selection_visuals")


func _on_defender_replaced(_defender_id: int, _defender: Defender) -> void:
	call_deferred("_apply_selection_visuals")
