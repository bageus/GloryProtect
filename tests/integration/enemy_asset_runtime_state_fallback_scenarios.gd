extends SceneTree

const ENEMY_SCENE := preload("res://scenes/boarding/boarding_enemy.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_visual_asset_fallback(
		&"basic",
		"res://resources/enemies/boarding_basic.tres"
	)
	await _assert_visual_asset_fallback(
		&"rope_saboteur",
		"res://resources/enemies/boarding_rope_saboteur.tres"
	)
	await _assert_unknown_archetype_uses_base_png_fallback()
	print("Enemy asset runtime state fallback scenarios passed")
	quit()


func _assert_visual_asset_fallback(
	expected_archetype_id: StringName,
	resource_path: String
) -> void:
	var enemy: BoardingEnemy = ENEMY_SCENE.instantiate() as BoardingEnemy
	root.add_child(enemy)
	await process_frame
	var visual: BoardingEnemyVisual = enemy.visual
	var archetype: BoardingEnemyArchetype = load(resource_path)
	visual.configure(archetype)
	await process_frame
	assert(visual.get_archetype_id() == expected_archetype_id)
	assert(visual.has_current_replacement_asset_for_tests())
	assert(visual.get_current_asset_state_for_tests() != &"")
	assert(visual.has_replacement_asset_for_tests(visual.get_current_asset_state_for_tests()))
	assert(visual.is_using_asset_sprite_for_tests())
	assert(visual.get_node_or_null("ReplacementAssetSprite") == null)
	assert(not visual.should_draw_procedural_for_tests())
	assert(visual.get_asset_state_for_tests(&"unmapped_runtime_state") == &"idle")
	assert(visual.get_asset_state_for_tests(&"waiting") == &"idle")
	assert(visual.get_asset_state_for_tests(&"running_to_rope") == &"run")
	assert(visual.get_asset_state_for_tests(&"arming") == &"attack")
	assert(visual.get_current_asset_source_rect_for_tests().size.x > 0.0)
	assert(visual.get_current_asset_source_rect_for_tests().size.y > 0.0)
	enemy.queue_free()
	await process_frame


func _assert_unknown_archetype_uses_base_png_fallback() -> void:
	var enemy: BoardingEnemy = ENEMY_SCENE.instantiate() as BoardingEnemy
	root.add_child(enemy)
	await process_frame
	var visual: BoardingEnemyVisual = enemy.visual
	var archetype := BoardingEnemyArchetype.new()
	archetype.archetype_id = &"legacy_runtime_blob"
	archetype.display_name = "Legacy Runtime Blob"
	archetype.body_radius = 12.0
	archetype.body_color = Color(0.92, 0.24, 0.2)
	archetype.accent_color = Color(1.0, 0.72, 0.62)
	visual.configure(archetype)
	await process_frame
	assert(visual.get_archetype_id() == &"legacy_runtime_blob")
	assert(visual.has_current_replacement_asset_for_tests())
	assert(visual.get_current_asset_state_for_tests() != &"")
	assert(visual.get_current_asset_archetype_id_for_tests() == &"basic")
	assert(visual.is_using_asset_sprite_for_tests())
	assert(visual.get_node_or_null("ReplacementAssetSprite") == null)
	assert(not visual.should_draw_procedural_for_tests())
	assert(visual.get_asset_state_for_tests(&"unmapped_runtime_state") == &"idle")
	assert(visual.get_asset_state_for_tests(&"running_to_rope") == &"run")
	enemy.queue_free()
	await process_frame
