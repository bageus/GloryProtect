extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const PANEL_SCENE := preload("res://scenes/ui/upgrade_selection_panel.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var upgrades: UpgradeSystem = game.get_node("UpgradeSystem")
	assert(upgrades != null)
	assert(upgrades.catalog.get_definition(&"turret_post") != null)
	assert(upgrades.catalog.get_definition(&"medic_station") != null)
	assert(upgrades.catalog.get_definition(&"shooter_unlock") != null)

	var panel: UpgradeSelectionPanel = PANEL_SCENE.instantiate() as UpgradeSelectionPanel
	panel.upgrade_system_path = NodePath("../UpgradeSystem")
	game.add_child(panel)
	await process_frame
	panel.show_diagnostics_for_tests()
	var tree: String = panel.get_diagnostics_text_for_tests()
	assert(tree.contains("ДЕРЕВО УЛУЧШЕНИЙ ТЕСТОВОГО РЕЖИМА"))
	assert(tree.contains("[Турели]"))
	assert(tree.contains("Пост турели"))
	assert(tree.contains("Усиленная атака турели"))
	assert(tree.contains("после Пост турели"))
	assert(tree.contains("[Лекарь]"))
	assert(tree.contains("Пост лекаря"))
	assert(tree.contains("Улучшенное лечение"))
	assert(tree.contains("[Дальний бой]"))
	assert(tree.contains("Стрелок"))
	assert(tree.contains("Улучшенный выстрел арбалета"))
	assert(tree.contains("после Стрелок"))

	var contact_preview: String = (
		panel.get_dependency_preview_text_for_tests(&"shield_contact_basic")
	)
	assert(contact_preview.contains("   └─ ○ Мега-контакт"))
	var mega_contact_preview: String = (
		panel.get_dependency_preview_text_for_tests(&"shield_contact_advanced")
	)
	assert(mega_contact_preview.contains("Требуется выше: Расширенный контакт"))

	print("Upgrade tree diagnostics scenarios passed")
	quit()
