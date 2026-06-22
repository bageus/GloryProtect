class_name CrewManager
extends Node2D

signal crew_initialized
signal defender_spawned(defender_id: int, defender: Defender)
signal defender_died(defender_id: int)
signal defender_replaced(defender_id: int, defender: Defender)
signal crew_size_changed(previous_size: int, current_size: int)
signal movement_speed_multiplier_changed(multiplier: float)
signal melee_upgrades_changed

@export var defender_scene: PackedScene
@export var balance: CrewBalance

var _defenders: Dictionary[int, Defender] = {}
var _movement_speed_multiplier: float = 1.0
var _melee_upgrades := MeleeDefenderUpgradeRuntime.new()


func _ready() -> void:
	assert(defender_scene != null, "CrewManager requires defender scene")
	assert(balance != null, "CrewManager requires CrewBalance")
	assert(
		balance.starting_defender_count <= balance.maximum_defender_count,
		"Starting crew cannot exceed maximum crew size"
	)
	_spawn_starting_crew()
	call_deferred("_emit_crew_initialized")


func get_defender(defender_id: int) -> Defender:
	return _defenders.get(defender_id)


func get_all_defenders() -> Array[Defender]:
	var result: Array[Defender] = []
	var ids: Array[int] = _defenders.keys()
	ids.sort()
	for defender_id: int in ids:
		result.append(_defenders[defender_id])
	return result


func get_total_count() -> int:
	return _defenders.size()


func can_add_defender() -> bool:
	return get_total_count() < balance.maximum_defender_count


func add_defender(spawn_local_x: float = NAN) -> Defender:
	if not can_add_defender():
		return null
	var defender_id: int = 0
	while _defenders.has(defender_id):
		defender_id += 1
	if defender_id >= balance.maximum_defender_count:
		return null
	var resolved_x: float = (
		balance.replacement_door_local_x
		if is_nan(spawn_local_x)
		else spawn_local_x
	)
	var previous_size: int = get_total_count()
	var defender: Defender = _spawn_defender(defender_id, resolved_x)
	crew_size_changed.emit(previous_size, get_total_count())
	return defender


func apply_melee_scalar(target_id: StringName, value: float) -> bool:
	if not _melee_upgrades.apply_scalar(target_id, value):
		return false
	_refresh_melee_upgrades()
	return true


func apply_melee_flag(target_id: StringName) -> bool:
	if not _melee_upgrades.apply_flag(target_id):
		return false
	_refresh_melee_upgrades()
	return true


func get_melee_upgrades() -> MeleeDefenderUpgradeRuntime:
	return _melee_upgrades


func multiply_movement_speed(multiplier: float) -> bool:
	if multiplier <= 0.0:
		return false
	_movement_speed_multiplier *= multiplier
	for defender: Defender in get_all_defenders():
		defender.set_base_movement_speed(get_current_movement_speed())
	movement_speed_multiplier_changed.emit(_movement_speed_multiplier)
	return true


func get_movement_speed_multiplier() -> float:
	return _movement_speed_multiplier


func get_current_movement_speed() -> float:
	return balance.defender_move_speed * _movement_speed_multiplier


func reset_run_modifiers() -> void:
	_movement_speed_multiplier = 1.0
	_melee_upgrades.reset()
	for defender: Defender in get_all_defenders():
		defender.reset_melee_upgrades_for_new_life(_melee_upgrades)
		defender.set_base_movement_speed(get_current_movement_speed())
	movement_speed_multiplier_changed.emit(_movement_speed_multiplier)
	melee_upgrades_changed.emit()


func get_living_defenders() -> Array[Defender]:
	var result: Array[Defender] = []
	for defender: Defender in get_all_defenders():
		if defender.health.is_alive():
			result.append(defender)
	return result


func get_living_count() -> int:
	return get_living_defenders().size()


func get_nearest_living_defender(world_position: Vector2) -> Defender:
	var nearest: Defender = null
	var nearest_distance: float = INF
	for defender: Defender in get_living_defenders():
		var distance: float = world_position.distance_squared_to(
			defender.global_position
		)
		if distance < nearest_distance:
			nearest = defender
			nearest_distance = distance
	return nearest


func replace_defender(defender_id: int, spawn_local_x: float) -> Defender:
	if defender_id < 0 or defender_id >= balance.maximum_defender_count:
		return null

	var previous: Defender = _defenders.get(defender_id)
	if previous != null:
		_defenders.erase(defender_id)
		if is_instance_valid(previous):
			previous.name = "RetiredDefender%d" % (defender_id + 1)
			if previous.get_parent() == self:
				remove_child(previous)
			previous.queue_free()

	var replacement: Defender = _spawn_defender(defender_id, spawn_local_x)
	defender_replaced.emit(defender_id, replacement)
	return replacement


func _spawn_starting_crew() -> void:
	for defender_id: int in range(balance.starting_defender_count):
		_spawn_defender(defender_id, balance.replacement_door_local_x)


func _spawn_defender(defender_id: int, spawn_local_x: float) -> Defender:
	var defender: Defender = defender_scene.instantiate() as Defender
	assert(defender != null, "Defender scene root must use Defender script")
	defender.configure(
		defender_id,
		balance,
		_get_defender_color(defender_id),
		_melee_upgrades
	)
	defender.name = "Defender%d" % (defender_id + 1)
	add_child(defender)
	defender.set_base_movement_speed(get_current_movement_speed())
	defender.teleport_to(spawn_local_x)
	defender.died.connect(_on_defender_died)
	_defenders[defender_id] = defender
	defender_spawned.emit(defender_id, defender)
	return defender


func _refresh_melee_upgrades() -> void:
	for defender: Defender in get_all_defenders():
		defender.apply_melee_upgrades(_melee_upgrades)
		defender.set_base_movement_speed(get_current_movement_speed())
	melee_upgrades_changed.emit()


func _get_defender_color(defender_id: int) -> Color:
	var colors: Array[Color] = [
		Color(0.35, 0.84, 1.0),
		Color(1.0, 0.68, 0.32),
		Color(0.58, 0.92, 0.48),
		Color(0.86, 0.5, 1.0),
	]
	return colors[defender_id % colors.size()]


func _emit_crew_initialized() -> void:
	crew_initialized.emit()


func _on_defender_died(defender_id: int) -> void:
	defender_died.emit(defender_id)
