class_name CombatAnchorHostSystem
extends AnchorSystem

signal anchor_detaching(anchor_id: int)


func _unhandled_input(event: InputEvent) -> void:
	if not _game_flow.is_world_simulation_active():
		return
	var anchor_id: int = _get_pressed_anchor_id(event)
	if anchor_id >= 0:
		toggle_anchor(anchor_id)
	elif event.is_action_pressed(&"gp_anchor_remove_all"):
		request_remove_all()
	else:
		return
	get_viewport().set_input_as_handled()


func _get_pressed_anchor_id(event: InputEvent) -> int:
	var actions: Array[StringName] = [
		&"gp_anchor_1",
		&"gp_anchor_2",
		&"gp_anchor_3",
		&"gp_anchor_4",
	]
	for anchor_id: int in range(actions.size()):
		if event.is_action_pressed(actions[anchor_id]):
			return anchor_id
	return -1


func _connect_component_signals() -> void:
	super._connect_component_signals()
	_commands.anchor_detaching.connect(_on_anchor_detaching)


func _create_visual_controller() -> void:
	var combat_visual := AnchorVisualControllerFasteningScaled.new()
	combat_visual.name = "AnchorVisualController"
	_visual = combat_visual
	add_child(_visual)
	var combat_anchors := get_node_or_null(
		"../CombatAnchorSystem"
	) as CombatAnchorSystem
	combat_visual.configure_combat(
		_store,
		_geometry,
		balance,
		Callable(self, "is_operator_assigned"),
		Callable(_game_flow, "is_world_simulation_active"),
		self,
		combat_anchors
	)


func set_combat_anchor_modifiers(
	overload_bonus_seconds: float,
	install_speed_bonus_ratio: float,
	second_anchor_speed_multiplier: float,
	instant_remove_all_enabled: bool,
	overload_wind_threshold: int = 2,
	second_winch_pair_enabled: bool = false
) -> void:
	_overload.set_duration_bonus(overload_bonus_seconds)
	_overload.set_wind_strength_threshold(overload_wind_threshold)
	_operations.set_install_speed_modifiers(
		install_speed_bonus_ratio,
		second_anchor_speed_multiplier
	)
	_commands.set_instant_remove_all_enabled(instant_remove_all_enabled)
	_commands.set_second_winch_pair_enabled(second_winch_pair_enabled)


func reset_combat_anchor_modifiers() -> void:
	set_combat_anchor_modifiers(0.0, 0.0, 1.0, false, 2, false)


func get_effective_overload_duration() -> float:
	return _overload.get_effective_duration()


func get_overload_wind_threshold() -> int:
	return _overload.get_wind_strength_threshold()


func get_effective_install_duration(anchor_id: int) -> float:
	return _operations.get_effective_install_duration(anchor_id)


func is_instant_remove_all_enabled() -> bool:
	return _commands.is_instant_remove_all_enabled()


func is_second_winch_pair_enabled() -> bool:
	return _commands.is_second_winch_pair_enabled()


func get_platform_attachment_world(anchor_id: int) -> Vector2:
	return _geometry.get_platform_attachment_world(anchor_id)


func get_winch_vertical_offset() -> float:
	return 0.0


func _on_anchor_detaching(anchor_id: int) -> void:
	anchor_detaching.emit(anchor_id)


func _on_anchor_removed(anchor_id: int) -> void:
	# Manual and emergency removal use the same rewarded path as a broken rope.
	# Boarded enemies are not counted as climbing and therefore survive.
	_enemy_registry.kill_climbing_on_anchor(anchor_id, &"anchor_path_closed")
	super._on_anchor_removed(anchor_id)
