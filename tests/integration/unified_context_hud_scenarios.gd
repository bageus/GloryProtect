extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame

	var game_flow: GameFlowController = game.get_node("GameFlowController")
	var inventory: BuildableInventory = game.get_node("BuildableInventory")
	var grid: BuildableGrid = game.get_node("World/BuildableGrid")
	var placement: BuildablePlacementController = game.get_node(
		"BuildablePlacementController"
	)
	var panel: UnifiedContextCrewCommandPanel = game.get_node(
		"CanvasLayer/PrototypeHUD/CrewCommandPanel"
	)
	var legacy_panel: PanelContainer = game.get_node(
		"CanvasLayer/BuildablePlacementPanel"
	)

	game_flow.state = GameFlowController.RunState.RUNNING
	assert(inventory.unlock(BuildableType.Id.TURRET) == 1)
	await process_frame

	var first_cell: int = grid.balance.turret_cell_indices[0]
	assert(placement.select_empty_cell(first_cell))
	await process_frame
	assert(panel.is_context_visible())
	assert(not legacy_panel.visible)
	var cell_buttons: PackedStringArray = panel.get_context_button_texts()
	assert(cell_buttons.has("Турель 0/1"))
	assert(not "\n".join(cell_buttons).contains("Выберите объект для клетки"))

	panel.open_defender_command_context(0)
	await process_frame
	assert(panel.is_context_visible())
	assert(not placement.has_cell_context())
	var defender_buttons: PackedStringArray = panel.get_context_button_texts()
	assert(defender_buttons.has("Свободная боевая ячейка"))
	assert(not defender_buttons.has("Турель 0/1"))

	var second_cell: int = grid.balance.turret_cell_indices[1]
	assert(placement.select_empty_cell(second_cell))
	await process_frame
	var second_cell_buttons: PackedStringArray = panel.get_context_button_texts()
	assert(second_cell_buttons.has("Турель 0/1"))
	assert(not second_cell_buttons.has("Свободная боевая ячейка"))

	var turret_id: int = grid.place(BuildableType.Id.TURRET, first_cell)
	assert(turret_id >= 0)
	assert(placement.select_buildable(turret_id))
	await process_frame
	var buildable_buttons: PackedStringArray = panel.get_context_button_texts()
	assert(buildable_buttons.has("Перенести"))
	assert(buildable_buttons.has("Демонтировать"))
	assert(not legacy_panel.visible)

	print("Unified context HUD scenarios passed")
	quit()
