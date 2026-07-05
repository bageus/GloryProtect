class_name BoardingEnemyVisualTextureBank
extends RefCounted

const BASE_IDLE := [
	preload("res://visual/enemies/Enemy1/base_enemy/idle/asset_enemy_base_idle_01.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/idle/asset_enemy_base_idle_02.png"),
]
const BASE_RUN := [
	preload("res://visual/enemies/Enemy1/base_enemy/run/asset_enemy_base_run_01.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/run/asset_enemy_base_run_02.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/run/asset_enemy_base_run_03.png"),
]
const BASE_DIE := [
	preload("res://visual/enemies/Enemy1/base_enemy/die/asset_enemy_base_die_01.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/die/asset_enemy_base_die_02.png"),
]
const BASE_JUMP := [
	preload("res://visual/enemies/Enemy1/base_enemy/jump/asset_enemy_base_jump_01.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/jump/asset_enemy_base_jump_02.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/jump/asset_enemy_base_jump_03.png"),
]
const BASE_FELL := [preload("res://visual/enemies/Enemy1/base_enemy/fell/asset_enemy_base_fell_01.png")]
const BASE_CLIMB := [preload("res://visual/enemies/Enemy1/base_enemy/climb/asset_enemy_base_climb_01.png")]
const BASE_ATTACK := [
	preload("res://visual/enemies/Enemy1/base_enemy/attack_meal/asset_enemy_base_attack_01.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/attack_meal/asset_enemy_base_attack_02.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/attack_meal/asset_enemy_base_attack_03.png"),
]
const BASE_DISTANCE_ATTACK := [
	preload("res://visual/enemies/Enemy1/base_enemy/attack_distance/asset_enemy_base_attack_dist_01.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/attack_distance/asset_enemy_base_attack_dist_02.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/attack_distance/asset_enemy_base_attack_dist_03.png"),
	preload("res://visual/enemies/Enemy1/base_enemy/attack_distance/asset_enemy_base_attack_dist_04.png"),
]
const FLY_IDLE := [preload("res://visual/enemies/Enemy1/fly_enemy/idle/asset_enemy_fly_idle_01.png")]
const FLY_FLY := [
	preload("res://visual/enemies/Enemy1/fly_enemy/fly/asset_enemy_fly_01.png"),
	preload("res://visual/enemies/Enemy1/fly_enemy/fly/asset_enemy_fly_02.png"),
	preload("res://visual/enemies/Enemy1/fly_enemy/fly/asset_enemy_fly_03.png"),
	preload("res://visual/enemies/Enemy1/fly_enemy/fly/asset_enemy_fly_04.png"),
]
const FLY_FELL := [preload("res://visual/enemies/Enemy1/fly_enemy/fell/asset_enemy_fly_fell_01.png")]
const FLY_DIE := [
	preload("res://visual/enemies/Enemy1/fly_enemy/die/asset_enemy_fly_die_01.png"),
	preload("res://visual/enemies/Enemy1/fly_enemy/die/asset_enemy_fly_die_02.png"),
	preload("res://visual/enemies/Enemy1/fly_enemy/die/asset_enemy_fly_die_03.png"),
]
const FLY_ATTACK := [
	preload("res://visual/enemies/Enemy1/fly_enemy/attack_meal/asset_enemy_fly_attack_01.png"),
	preload("res://visual/enemies/Enemy1/fly_enemy/attack_meal/asset_enemy_fly_attack_02.png"),
	preload("res://visual/enemies/Enemy1/fly_enemy/attack_meal/asset_enemy_fly_attack_03.png"),
]
const FAST_IDLE := [
	preload("res://visual/enemies/Enemy1/fast_enemy/idle/asset_enemy_fast_idle_01.png"),
	preload("res://visual/enemies/Enemy1/fast_enemy/idle/asset_enemy_fast_idle_02.png"),
]
const FAST_JUMP := [
	preload("res://visual/enemies/Enemy1/fast_enemy/jump/asset_enemy_fast_jump_01.png"),
	preload("res://visual/enemies/Enemy1/fast_enemy/jump/asset_enemy_fast_jump_02.png"),
]
const FAST_RUN := [
	preload("res://visual/enemies/Enemy1/fast_enemy/run/asset_enemy_fast_run_01.png"),
	preload("res://visual/enemies/Enemy1/fast_enemy/run/asset_enemy_fast_run_02.png"),
	preload("res://visual/enemies/Enemy1/fast_enemy/run/asset_enemy_fast_run_03.png"),
]
const FAST_FELL := [preload("res://visual/enemies/Enemy1/fast_enemy/fell/asset_enemy_fast_fell_01.png")]
const FAST_DIE := [
	preload("res://visual/enemies/Enemy1/fast_enemy/die/asset_enemy_fast_die_01.png"),
	preload("res://visual/enemies/Enemy1/fast_enemy/die/asset_enemy_fast_die_02.png"),
]
const FAST_CLIMB := [
	preload("res://visual/enemies/Enemy1/fast_enemy/climb/asset_enemy_fast_climb_01.png"),
	preload("res://visual/enemies/Enemy1/fast_enemy/climb/asset_enemy_fast_climb_02.png"),
]
const FAST_ATTACK := [
	preload("res://visual/enemies/Enemy1/fast_enemy/attack_meal/asset_enemy_fast_attack_01.png"),
	preload("res://visual/enemies/Enemy1/fast_enemy/attack_meal/asset_enemy_fast_attack_02.png"),
	preload("res://visual/enemies/Enemy1/fast_enemy/attack_meal/asset_enemy_fast_attack_03.png"),
]
const HEAVY_IDLE := [
	preload("res://visual/enemies/Enemy1/heavy_enemy/idle/asset_enemy_heavy_idle_01.png"),
	preload("res://visual/enemies/Enemy1/heavy_enemy/idle/asset_enemy_heavy_idle_02.png"),
]
const HEAVY_RUN := [
	preload("res://visual/enemies/Enemy1/heavy_enemy/run/asset_enemy_heavy_run_01.png"),
	preload("res://visual/enemies/Enemy1/heavy_enemy/run/asset_enemy_heavy_run_02.png"),
	preload("res://visual/enemies/Enemy1/heavy_enemy/run/asset_enemy_heavy_run_03.png"),
	preload("res://visual/enemies/Enemy1/heavy_enemy/run/asset_enemy_heavy_run_04.png"),
]
const HEAVY_FELL := [preload("res://visual/enemies/Enemy1/heavy_enemy/fell/asset_enemy_heavy_fell_01.png")]
const HEAVY_DIE := [
	preload("res://visual/enemies/Enemy1/heavy_enemy/die/asset_enemy_heavy_die_01.png"),
	preload("res://visual/enemies/Enemy1/heavy_enemy/die/asset_enemy_heavy_die_02.png"),
]
const HEAVY_CLIMB := [
	preload("res://visual/enemies/Enemy1/heavy_enemy/climb/asset_enemy_heavy_climb_01.png"),
	preload("res://visual/enemies/Enemy1/heavy_enemy/climb/asset_enemy_heavy_climb_02.png"),
]
const HEAVY_ATTACK := [
	preload("res://visual/enemies/Enemy1/heavy_enemy/attack_meal/asset_enemy_heavy_attack_01.png"),
	preload("res://visual/enemies/Enemy1/heavy_enemy/attack_meal/asset_enemy_heavy_attack_02.png"),
	preload("res://visual/enemies/Enemy1/heavy_enemy/attack_meal/asset_enemy_heavy_attack_03.png"),
]
const BOMB_IDLE := [
	preload("res://visual/enemies/Enemy1/bomb_enemy/idle/asset_enemy_bomb_idle_01.png"),
	preload("res://visual/enemies/Enemy1/bomb_enemy/idle/asset_enemy_bomb_idle_02.png"),
]
const BOMB_RUN := [
	preload("res://visual/enemies/Enemy1/bomb_enemy/run/asset_enemy_bomb_run_01.png"),
	preload("res://visual/enemies/Enemy1/bomb_enemy/run/asset_enemy_bomb_run_02.png"),
	preload("res://visual/enemies/Enemy1/bomb_enemy/run/asset_enemy_bomb_run_03.png"),
	preload("res://visual/enemies/Enemy1/bomb_enemy/run/asset_enemy_bomb_run_04.png"),
]
const BOMB_DIE := [
	preload("res://visual/enemies/Enemy1/bomb_enemy/die/asset_enemy_bomb_die_01.png"),
	preload("res://visual/enemies/Enemy1/bomb_enemy/die/asset_enemy_bomb_die_02.png"),
	preload("res://visual/enemies/Enemy1/bomb_enemy/die/asset_enemy_bomb_die_03.png"),
]


static func get_frame_count(archetype_id: StringName, state_id: StringName) -> int:
	return get_frames(archetype_id, state_id).size()


static func get_frames(archetype_id: StringName, state_id: StringName) -> Array[Texture2D]:
	var state: StringName = normalize_state(state_id)
	match archetype_id:
		&"basic": return _base_frames(state)
		&"flyer": return _fly_frames(state)
		&"runner": return _fast_frames(state)
		&"brute": return _heavy_frames(state)
		&"rope_saboteur", &"bomb_enemy": return _bomb_frames(state)
		_: return []


static func normalize_state(state_id: StringName) -> StringName:
	match state_id:
		&"death": return &"die"
		&"landing": return &"fell"
		&"distance_attack": return &"attack_distance"
		_: return state_id


static func _base_frames(state: StringName) -> Array[Texture2D]:
	match state:
		&"idle": return _as_textures(BASE_IDLE)
		&"run": return _as_textures(BASE_RUN)
		&"die": return _as_textures(BASE_DIE)
		&"jump": return _as_textures(BASE_JUMP)
		&"fell": return _as_textures(BASE_FELL)
		&"climb": return _as_textures(BASE_CLIMB)
		&"attack": return _as_textures(BASE_ATTACK)
		&"attack_distance": return _as_textures(BASE_DISTANCE_ATTACK)
		_: return []


static func _fly_frames(state: StringName) -> Array[Texture2D]:
	match state:
		&"idle": return _as_textures(FLY_IDLE)
		&"flying", &"run": return _as_textures(FLY_FLY)
		&"fell": return _as_textures(FLY_FELL)
		&"die": return _as_textures(FLY_DIE)
		&"attack": return _as_textures(FLY_ATTACK)
		_: return []


static func _fast_frames(state: StringName) -> Array[Texture2D]:
	match state:
		&"idle": return _as_textures(FAST_IDLE)
		&"jump": return _as_textures(FAST_JUMP)
		&"run": return _as_textures(FAST_RUN)
		&"fell": return _as_textures(FAST_FELL)
		&"die": return _as_textures(FAST_DIE)
		&"climb": return _as_textures(FAST_CLIMB)
		&"attack": return _as_textures(FAST_ATTACK)
		_: return []


static func _heavy_frames(state: StringName) -> Array[Texture2D]:
	match state:
		&"idle": return _as_textures(HEAVY_IDLE)
		&"run": return _as_textures(HEAVY_RUN)
		&"fell": return _as_textures(HEAVY_FELL)
		&"die": return _as_textures(HEAVY_DIE)
		&"climb": return _as_textures(HEAVY_CLIMB)
		&"attack": return _as_textures(HEAVY_ATTACK)
		_: return []


static func _bomb_frames(state: StringName) -> Array[Texture2D]:
	match state:
		&"idle": return _as_textures(BOMB_IDLE)
		&"run": return _as_textures(BOMB_RUN)
		&"die", &"attack": return _as_textures(BOMB_DIE)
		_: return []


static func _as_textures(items: Array) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for item: Texture2D in items:
		result.append(item)
	return result
