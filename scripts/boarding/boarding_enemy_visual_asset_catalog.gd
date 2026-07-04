class_name BoardingEnemyVisualAssetCatalog
extends RefCounted

static var _cache: Dictionary = {}


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
	var state: StringName = _normalize_state(state_id)
	var key := String(archetype_id) + ":" + String(state)
	if _cache.has(key):
		return _cache[key]
	var result: Array[Texture2D] = []
	for path: String in get_frame_paths(archetype_id, state):
		var texture: Texture2D = load(path) as Texture2D
		if texture != null:
			result.append(texture)
	_cache[key] = result
	return result


static func source_faces_right() -> bool:
	return false


static func should_mirror_for_facing(facing_right: bool) -> bool:
	return facing_right != source_faces_right()


static func _normalize_state(state_id: StringName) -> StringName:
	match state_id:
		&"death":
			return &"die"
		&"landing":
			return &"fell"
		&"distance_attack":
			return &"attack_distance"
		_:
			return state_id


static func _base_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/base_enemy/idle/asset_enemy_base_idle_01.png",
				"res://visual/enemies/Enemy1/base_enemy/idle/asset_enemy_base_idle_02.png",
			])
		&"run":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/base_enemy/run/asset_enemy_base_run_01.png",
				"res://visual/enemies/Enemy1/base_enemy/run/asset_enemy_base_run_02.png",
				"res://visual/enemies/Enemy1/base_enemy/run/asset_enemy_base_run_03.png",
			])
		&"die":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/base_enemy/die/asset_enemy_base_die_01.png",
				"res://visual/enemies/Enemy1/base_enemy/die/asset_enemy_base_die_02.png",
			])
		&"jump":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/base_enemy/jump/asset_enemy_base_jump_01.png",
				"res://visual/enemies/Enemy1/base_enemy/jump/asset_enemy_base_jump_02.png",
				"res://visual/enemies/Enemy1/base_enemy/jump/asset_enemy_base_jump_03.png",
			])
		&"fell":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/base_enemy/fell/asset_enemy_base_fell_01.png",
			])
		&"climb":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/base_enemy/climb/asset_enemy_base_climb_01.png",
			])
		&"attack":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/base_enemy/attack_meal/asset_enemy_base_attack_01.png",
				"res://visual/enemies/Enemy1/base_enemy/attack_meal/asset_enemy_base_attack_02.png",
				"res://visual/enemies/Enemy1/base_enemy/attack_meal/asset_enemy_base_attack_03.png",
			])
		&"attack_distance":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/base_enemy/attack_distance/asset_enemy_base_attack_dist_01.png",
				"res://visual/enemies/Enemy1/base_enemy/attack_distance/asset_enemy_base_attack_dist_02.png",
				"res://visual/enemies/Enemy1/base_enemy/attack_distance/asset_enemy_base_attack_dist_03.png",
				"res://visual/enemies/Enemy1/base_enemy/attack_distance/asset_enemy_base_attack_dist_04.png",
			])
		_:
			return PackedStringArray()


static func _fly_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/fly_enemy/idle/asset_enemy_fly_idle_01.png",
			])
		&"flying", &"run":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/fly_enemy/fly/asset_enemy_fly_01.png",
				"res://visual/enemies/Enemy1/fly_enemy/fly/asset_enemy_fly_02.png",
				"res://visual/enemies/Enemy1/fly_enemy/fly/asset_enemy_fly_03.png",
				"res://visual/enemies/Enemy1/fly_enemy/fly/asset_enemy_fly_04.png",
			])
		&"fell":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/fly_enemy/fell/asset_enemy_fly_fell_01.png",
			])
		&"die":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/fly_enemy/die/asset_enemy_fly_die_01.png",
				"res://visual/enemies/Enemy1/fly_enemy/die/asset_enemy_fly_die_02.png",
				"res://visual/enemies/Enemy1/fly_enemy/die/asset_enemy_fly_die_03.png",
			])
		&"attack":
			return PackedStringArray([
				"res://visual/enemies/Enemy1/fly_enemy/attack_meal/asset_enemy_fly_attack_01.png",
				"res://visual/enemies/Enemy1/fly_enemy/attack_meal/asset_enemy_fly_attack_02.png",
				"res://visual/enemies/Enemy1/fly_enemy/attack_meal/asset_enemy_fly_attack_03.png",
			])
		_:
			return PackedStringArray()


static func _fast_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return _numbered("fast_enemy/idle/asset_enemy_fast_idle_", 2)
		&"jump":
			return _numbered("fast_enemy/jump/asset_enemy_fast_jump_", 2)
		&"run":
			return _numbered("fast_enemy/run/asset_enemy_fast_run_", 3)
		&"fell":
			return _numbered("fast_enemy/fell/asset_enemy_fast_fell_", 1)
		&"die":
			return _numbered("fast_enemy/die/asset_enemy_fast_die_", 2)
		&"climb":
			return _numbered("fast_enemy/climb/asset_enemy_fast_climb_", 2)
		&"attack":
			return _numbered("fast_enemy/attack_meal/asset_enemy_fast_attack_", 3)
		_:
			return PackedStringArray()


static func _heavy_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return _numbered("heavy_enemy/idle/asset_enemy_heavy_idle_", 2)
		&"run":
			return _numbered("heavy_enemy/run/asset_enemy_heavy_run_", 4)
		&"fell":
			return _numbered("heavy_enemy/fell/asset_enemy_heavy_fell_", 1)
		&"die":
			return _numbered("heavy_enemy/die/asset_enemy_heavy_die_", 2)
		&"climb":
			return _numbered("heavy_enemy/climb/asset_enemy_heavy_climb_", 2)
		&"attack":
			return _numbered("heavy_enemy/attack_meal/asset_enemy_heavy_attack_", 3)
		_:
			return PackedStringArray()


static func _bomb_paths(state: StringName) -> PackedStringArray:
	match state:
		&"idle":
			return _numbered("bomb_enemy/idle/asset_enemy_bomb_idle_", 2)
		&"run":
			return _numbered("bomb_enemy/run/asset_enemy_bomb_run_", 4)
		&"die", &"attack":
			return _numbered("bomb_enemy/die/asset_enemy_bomb_die_", 3)
		_:
			return PackedStringArray()


static func _numbered(relative_prefix: String, count: int) -> PackedStringArray:
	var result := PackedStringArray()
	for index: int in range(1, count + 1):
		result.append(
			"res://visual/enemies/Enemy1/"
			+ relative_prefix
			+ "%02d" % index
			+ ".png"
		)
	return result
