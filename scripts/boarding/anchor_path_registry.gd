class_name AnchorPathRegistry
extends Node

signal path_opened(anchor_id: int)
signal path_closed(anchor_id: int)

@export_node_path("AnchorSystem") var anchor_system_path: NodePath
@export var balance: BoardingBalance

var _known_open_paths: Dictionary[int, bool] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _anchors: AnchorSystem = get_node(anchor_system_path)


func _ready() -> void:
	assert(balance != null, "AnchorPathRegistry requires BoardingBalance")
	_rng.randomize()
	_anchors.anchor_attached.connect(_on_anchor_attached)
	_anchors.anchor_removed.connect(_on_anchor_closed)
	_anchors.anchor_broken.connect(_on_anchor_closed)
	_sync_open_paths()


func get_available_count() -> int:
	return _anchors.get_active_path_count()


func has_available_paths() -> bool:
	return get_available_count() > 0


func is_path_available(anchor_id: int) -> bool:
	return _anchors.is_path_available(anchor_id)


func get_anchor_path(anchor_id: int) -> AnchorPathSnapshot:
	return _anchors.get_path_snapshot(anchor_id)


func get_available_paths() -> Array[AnchorPathSnapshot]:
	return _anchors.get_active_path_snapshots()


func choose_nearest_path(
	world_x: float,
	excluded_anchor_ids: Array[int] = []
) -> AnchorPathSnapshot:
	var paths: Array[AnchorPathSnapshot] = get_available_paths()
	if paths.is_empty():
		return null

	var nearest_distance: float = INF
	var candidates: Array[AnchorPathSnapshot] = []
	for path: AnchorPathSnapshot in paths:
		if excluded_anchor_ids.has(path.anchor_id):
			continue
		var distance: float = absf(path.ground_point.x - world_x)
		if distance + balance.path_tie_epsilon < nearest_distance:
			nearest_distance = distance
			candidates.clear()
			candidates.append(path)
		elif absf(distance - nearest_distance) <= balance.path_tie_epsilon:
			candidates.append(path)

	if candidates.is_empty():
		return null
	if candidates.size() == 1:
		return candidates[0]
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _sync_open_paths() -> void:
	_known_open_paths.clear()
	for path: AnchorPathSnapshot in get_available_paths():
		_known_open_paths[path.anchor_id] = true


func _on_anchor_attached(anchor_id: int) -> void:
	_known_open_paths[anchor_id] = true
	path_opened.emit(anchor_id)


func _on_anchor_closed(anchor_id: int) -> void:
	if not _known_open_paths.has(anchor_id):
		return
	_known_open_paths.erase(anchor_id)
	path_closed.emit(anchor_id)
