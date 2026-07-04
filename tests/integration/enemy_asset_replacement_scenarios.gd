extends SceneTree

const ENEMY_SCENE := preload("res://scenes/boarding/boarding_enemy.tscn")
const ARCHETYPES := {
	&"basic": "res://resources/enemies/boarding_basic.tres",
	&"flyer": "res://resources/enemies/boarding_flyer.tres",
	&"runner": "res://resources/enemies/boarding_runner.tres",
	&"brute": "res://resources/enemies/boarding_brute.tres",
	&"rope_saboteur": "res://resources/enemies/boarding_rope_saboteur.tres",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_catalog_counts()
	for archetype_id: StringName in ARCHETYPES.keys():
		await _assert_visual_for_archetype(archetype_id)
	print("Enemy asset replacement scenarios passed")
	quit()


func _assert_catalog_counts() -> void:
	_assert_count(&"basic", &"idle", 2)
	_assert_count(&"basic", &"run", 3)
	_assert_count(&"basic", &"death", 2)
	_assert_count(&"basic", &"jump", 3)
	_assert_count(&"basic", &"landing", 1)
	_assert_count(&"basic", &"climb", 1)
	_assert_count(&"basic", &"attack", 3)
	_assert_count(&"basic", &"distance_attack", 4)
	_assert_count(&"flyer", &"idle", 1)
	_assert_count(&"flyer", &"flying", 4)
	_assert_count(&"flyer", &"landing", 1)
	_assert_count(&"flyer", &"death", 3)
	_assert_count(&"flyer", &"attack", 3)
	_assert_count(&"runner", &"idle", 2)
	_assert_count(&"runner", &"jump", 2)
	_assert_count(&"runner", &"run", 3)
	_assert_count(&"runner", &"landing", 1)
	_assert_count(&"runner", &"death", 2)
	_assert_count(&"runner", &"climb", 2)
	_assert_count(&"runner", &"attack", 3)
	_assert_count(&"brute", &"idle", 2)
	_assert_count(&"brute", &"run", 4)
	_assert_count(&"brute", &"landing", 1)
	_assert_count(&"brute", &"death", 2)
	_assert_count(&"brute", &"climb", 2)
	_assert_count(&"brute", &"attack", 3)
	_assert_count(&"rope_saboteur", &"idle", 2)
	_assert_count(&"rope_saboteur", &"run", 4)
	_assert_count(&"rope_saboteur", &"death", 3)
	_assert_count(&"rope_saboteur", &"attack", 3)
	_assert_count(&"bomb_enemy", &"idle", 2)
	_assert_count(&"bomb_enemy", &"run", 4)
	_assert_count(&"bomb_enemy", &"death", 3)
	_assert_count(&"bomb_enemy", &"attack", 3)

	var base_attack_paths: PackedStringArray = (
		BoardingEnemyVisualAssetCatalog.get_frame_paths(
			&"basic",
			&"distance_attack"
		)
	)
	assert(base_attack_paths[0].ends_with(
		"attack_distance/asset_enemy_base_attack_dist_01.png"
	))
	var bomb_attack_paths: PackedStringArray = (
		BoardingEnemyVisualAssetCatalog.get_frame_paths(
			&"rope_saboteur",
			&"attack"
		)
	)
	assert(bomb_attack_paths[0].ends_with(
		"bomb_enemy/die/asset_enemy_bomb_die_01.png"
	))
	assert(not BoardingEnemyVisualAssetCatalog.source_faces_right())


func _assert_visual_for_archetype(archetype_id: StringName) -> void:
	var enemy: BoardingEnemy = ENEMY_SCENE.instantiate() as BoardingEnemy
	root.add_child(enemy)
	await process_frame
	var visual: BoardingEnemyVisual = enemy.visual
	var archetype: BoardingEnemyArchetype = load(ARCHETYPES[archetype_id])
	visual.configure(archetype)
	await process_frame

	assert(visual.get_archetype_id() == archetype_id)
	assert(visual.has_replacement_asset_for_tests(&"idle"))
	assert(visual.get_asset_frame_count_for_tests(&"idle") > 0)
	assert(visual.get_asset_frame_paths_for_tests(&"idle")[0].begins_with(
		"res://visual/enemies/Enemy1/"
	))
	visual.debug_set_facing_right_for_tests(false)
	assert(not visual.is_asset_mirrored_for_tests())
	visual.debug_set_facing_right_for_tests(true)
	assert(visual.is_asset_mirrored_for_tests())
	if archetype_id == &"rope_saboteur":
		_assert_behavior_state_route(visual, &"waiting", &"idle")
		_assert_behavior_state_route(visual, &"running_to_rope", &"run")
		_assert_behavior_state_route(visual, &"arming", &"attack")
		_assert_behavior_state_route(visual, &"dead", &"death")
	if archetype_id == &"flyer":
		_assert_behavior_state_route(visual, &"flying", &"flying")
		_assert_behavior_state_route(visual, &"landing", &"landing")
		_assert_behavior_state_route(visual, &"attacking", &"attack")

	enemy.queue_free()
	await process_frame


func _assert_behavior_state_route(
	visual: BoardingEnemyVisual,
	behavior_state: StringName,
	expected_presentation_state: StringName
) -> void:
	var presentation_state: StringName = (
		visual.get_behavior_presentation_state_for_tests(behavior_state)
	)
	assert(presentation_state == expected_presentation_state)
	assert(visual.has_replacement_asset_for_tests(presentation_state))


func _assert_count(
	archetype_id: StringName,
	state_id: StringName,
	expected: int
) -> void:
	assert(BoardingEnemyVisualAssetCatalog.get_frame_count(
		archetype_id,
		state_id
	) == expected)
	var frames: Array[Texture2D] = BoardingEnemyVisualAssetCatalog.get_frames(
		archetype_id,
		state_id
	)
	assert(frames.size() == expected)
	for frame: Texture2D in frames:
		assert(frame != null)
