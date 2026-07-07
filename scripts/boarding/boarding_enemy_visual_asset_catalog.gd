class_name BoardingEnemyVisualAssetCatalog
extends RefCounted

const ROOT := "res://visual/enemies/Enemy1/"

static var _frame_cache: Dictionary = {}


static func get_frame_paths(
	archetype_id: StringName,
	state_id: StringName
) -> PackedStringArray:
	var state: StringName = _normalize_state(state_id)
	match archetype_id:
		&"basic":
			return _base_paths(state)
		&"flyer":
			return _fly_paths(state)
		&"runner":
			return _fast_paths(state)
		&"brute":
			return _heavy_paths(state)
		&"rope_saboteur", &"bomb_enemy":
			return _bomb_paths(state)
		_:
			return PackedStringArray()


static func get_frame_count(
	archetype_id: StringName,
	state_id: StringName
) -> int:
	return get_frame_paths(archetype_id, state_id).size()


static func get_frames(
	archetype_id: StringName,
	state_id: StringName
) -> Array[Texture2D]:
	var paths: PackedStringArray = get_frame_paths(archetype_id, state_id)
	var result: Array[Texture2D] = []
	for path: String in paths:
		var texture: Texture2D = _load_texture(path)
		if texture != null:
			result.append(texture)
	return result


static func source_faces_right() -> bool:
	return false


static func should_mirror_for_facing(facing_right: bool) -> bool:
	return facing_right != source_faces_right()


static func _load_texture(path: String) -> Texture2D:
	if _frame_cache.has(path):
		return _frame_cache[path]
	var texture: Texture2D = load(path) as Texture2D
	_frame_cache[path] = texture
	return texture


static func _normalize_state(state_id: StringName) -> StringName:
	match state_id:
		&"death":
			return &"die"
		&"fall":
			return &"fell"
		&"distance_attack":
			return &"attack_distance"
		_:
			return state_id


static func _base_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return _paths("base_enemy/idle/asset_enemy_base_idle_", 2)
		&"run":
			return _paths("base_enemy/run/asset_enemy_base_run_", 3)
		&"die":
			return _paths("base_enemy/die/asset_enemy_base_die_", 2)
		&"jump":
			return _paths("base_enemy/jump/asset_enemy_base_jump_", 3)
		&"fell":
			return _paths("base_enemy/fell/asset_enemy_base_fell_", 1)
		&"climb":
			return _paths("base_enemy/climb/asset_enemy_base_climb_", 1)
		&"attack":
			return _paths("base_enemy/attack_meal/asset_enemy_base_attack_", 3)
		&"attack_distance":
			return _paths("base_enemy/attack_distance/asset_enemy_base_attack_dist_", 4)
		_:
			return PackedStringArray()


static func _fly_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return _paths("fly_enemy/idle/asset_enemy_fly_idle_", 1)
		&"flying", &"run":
			return _paths("fly_enemy/fly/asset_enemy_fly_", 4)
		&"fell":
			return _paths("fly_enemy/fell/asset_enemy_fly_fell_", 1)
		&"die":
			return _paths("fly_enemy/die/asset_enemy_fly_die_", 3)
		&"attack":
			return _paths("fly_enemy/attack_meal/asset_enemy_fly_attack_", 3)
		_:
			return PackedStringArray()


static func _fast_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return _paths("fast_enemy/idle/asset_enemy_fast_idle_", 2)
		&"jump":
			return _paths("fast_enemy/jump/asset_enemy_fast_jump_", 2)
		&"run":
			return _paths("fast_enemy/run/asset_enemy_fast_run_", 3)
		&"fell":
			return _paths("fast_enemy/fell/asset_enemy_fast_fell_", 1)
		&"die":
			return _paths("fast_enemy/die/asset_enemy_fast_die_", 2)
		&"climb":
			return _paths("fast_enemy/climb/asset_enemy_fast_climb_", 2)
		&"attack":
			return _paths("fast_enemy/attack_meal/asset_enemy_fast_attack_", 3)
		_:
			return PackedStringArray()


static func _heavy_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return _paths("heavy_enemy/idle/asset_enemy_heavy_idle_", 2)
		&"run":
			return _paths("heavy_enemy/run/asset_enemy_heavy_run_", 4)
		&"fell":
			return _paths("heavy_enemy/fell/asset_enemy_heavy_fell_", 1)
		&"die":
			return _paths("heavy_enemy/die/asset_enemy_heavy_die_", 2)
		&"climb":
			return _paths("heavy_enemy/climb/asset_enemy_heavy_climb_", 2)
		&"attack":
			return _paths("heavy_enemy/attack_meal/asset_enemy_heavy_attack_", 3)
		_:
			return PackedStringArray()


static func _bomb_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return _paths("bomb_enemy/idle/asset_enemy_bomb_idle_", 2)
		&"run":
			return _paths("bomb_enemy/run/asset_enemy_bomb_run_", 4)
		&"die", &"attack":
			return _paths("bomb_enemy/die/asset_enemy_bomb_die_", 3)
		_:
			return PackedStringArray()


static func _paths(relative_prefix: String, count: int) -> PackedStringArray:
	var result := PackedStringArray()
	for index: int in range(1, count + 1):
		result.append(ROOT + relative_prefix + "%02d" % index + ".png")
	return result
