class_name CrewManager
extends Node2D

signal crew_initialized
signal defender_spawned(defender_id: int, defender: Defender)
signal defender_died(defender_id: int)

@export var defender_scene: PackedScene
@export var balance: CrewBalance

var _defenders: Dictionary[int, Defender] = {}


func _ready() -> void:
	assert(defender_scene != null, "CrewManager requires defender scene")
	assert(balance != null, "CrewManager requires CrewBalance")
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
		var distance: float = world_position.distance_squared_to(defender.global_position)
		if distance < nearest_distance:
			nearest = defender
			nearest_distance = distance
	return nearest


func _spawn_starting_crew() -> void:
	for defender_id: int in range(balance.starting_defender_count):
		_spawn_defender(defender_id)


func _spawn_defender(defender_id: int) -> Defender:
	var defender: Defender = defender_scene.instantiate() as Defender
	assert(defender != null, "Defender scene root must use Defender script")
	defender.configure(defender_id, balance, _get_defender_color(defender_id))
	defender.name = "Defender%d" % (defender_id + 1)
	add_child(defender)
	defender.died.connect(_on_defender_died)
	_defenders[defender_id] = defender
	defender_spawned.emit(defender_id, defender)
	return defender


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
