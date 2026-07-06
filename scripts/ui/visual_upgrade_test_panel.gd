class_name VisualUpgradeTestPanel
extends CanvasLayer

const VISUAL_TARGET_PREFIXES: PackedStringArray = [
	"anchor_",
	"anchorless_",
	"shield_",
	"turret_",
	"medic_",
	"melee_",
	"shooter_",
]

var _game: Node
var _upgrade_system: UpgradeSystem
var _tree: Tree
var _feedback: Label
var _selected: Dictionary[StringName, bool] = {}
var _ordered_ids: Array[StringName] = []
var _items: Dictionary[StringName, TreeItem] = {}
var _applying: bool = false


func configure(game: Node) -> void:
	_game = game
	_upgrade_system = game.get_node("UpgradeSystem") as UpgradeSystem
	_build_ui()
	_rebuild_tree()
	_apply_selected_upgrades()


func is_test_panel_ready_for_tests() -> bool:
	return _upgrade_system != null and _tree != null


func get_toggle_count_for_tests() -> int:
	return _ordered_ids.size()


func is_card_ui_suppressed_for_tests() -> bool:
	if _game == null:
		return false
	var panel: CanvasItem = _game.get_node_or_null(
		"CanvasLayer/UpgradeSelectionPanel"
	) as CanvasItem
	return panel == null or not panel.visible


func toggle_upgrade_for_tests(card_id: StringName, enabled: bool) -> bool:
	if not _ordered_ids.has(card_id):
		return false
	_set_selected(card_id, enabled)
	_apply_selected_upgrades()
	_sync_tree_checks()
	return bool(_selected.get(card_id, false)) == enabled


func _build_ui() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "VisualUpgradeTestRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.name = "UpgradeTreePanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -370.0
	panel.offset_right = -8.0
	panel.offset_top = 16.0
	panel.offset_bottom = -16.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ТЕСТ УЛУЧШЕНИЙ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	box.add_child(title)

	var note := Label.new()
	note.text = "Галочки сразу включают/выключают визуальные upgrade-состояния. Монеты и карточки не используются."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 1
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(330.0, 560.0)
	_tree.item_edited.connect(_on_tree_item_edited)
	box.add_child(_tree)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)

	var clear := Button.new()
	clear.text = "Снять всё"
	clear.pressed.connect(_clear_all)
	buttons.add_child(clear)

	var apply := Button.new()
	apply.text = "Применить"
	apply.pressed.connect(_apply_selected_upgrades)
	buttons.add_child(apply)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", 12)
	box.add_child(_feedback)


func _rebuild_tree() -> void:
	_items.clear()
	_ordered_ids.clear()
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var grouped: Dictionary[StringName, Array] = {}
	var definitions: Array[UpgradeDefinition] = _upgrade_system.get_all_card_definitions()
	definitions.sort_custom(func(a: UpgradeDefinition, b: UpgradeDefinition) -> bool:
		if String(a.branch_id) == String(b.branch_id):
			return String(a.card_id) < String(b.card_id)
		return String(a.branch_id) < String(b.branch_id)
	)
	for definition: UpgradeDefinition in definitions:
		if not _is_visual_test_definition(definition):
			continue
		if not grouped.has(definition.branch_id):
			grouped[definition.branch_id] = []
		grouped[definition.branch_id].append(definition)

	var branches: Array[StringName] = []
	for raw_branch: Variant in grouped.keys():
		branches.append(raw_branch as StringName)
	branches.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	for branch_id: StringName in branches:
		var branch_item: TreeItem = _tree.create_item(root)
		branch_item.set_text(0, _format_branch(branch_id))
		branch_item.set_selectable(0, false)
		for definition: UpgradeDefinition in grouped[branch_id]:
			var item: TreeItem = _tree.create_item(branch_item)
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_editable(0, true)
			item.set_text(0, definition.title)
			item.set_tooltip_text(0, String(definition.card_id))
			item.set_metadata(0, definition.card_id)
			_items[definition.card_id] = item
			_ordered_ids.append(definition.card_id)
		branch_item.collapsed = false
	_sync_tree_checks()


func _on_tree_item_edited() -> void:
	if _applying:
		return
	var item: TreeItem = _tree.get_edited()
	if item == null:
		return
	var card_id: StringName = item.get_metadata(0)
	_set_selected(card_id, item.is_checked(0))
	_apply_selected_upgrades()
	_sync_tree_checks()


func _set_selected(card_id: StringName, enabled: bool) -> void:
	if enabled:
		_selected[card_id] = true
	else:
		_selected.erase(card_id)


func _clear_all() -> void:
	_selected.clear()
	_apply_selected_upgrades()
	_sync_tree_checks()


func _apply_selected_upgrades() -> void:
	if _upgrade_system == null:
		return
	_applying = true
	_reset_visual_upgrade_state()
	var applied: int = 0
	var rejected := PackedStringArray()
	var still_selected: Dictionary[StringName, bool] = {}
	for card_id: StringName in _ordered_ids:
		if not bool(_selected.get(card_id, false)):
			continue
		var definition: UpgradeDefinition = _upgrade_system.catalog.get_definition(card_id)
		if definition == null or not _is_visual_test_definition(definition):
			continue
		if _upgrade_system._effect_applier.can_apply(definition):
			if _upgrade_system._effect_applier.apply_effect(definition):
				_upgrade_system._runtime.record_card(definition)
				still_selected[card_id] = true
				applied += 1
				continue
		rejected.append(definition.title)
	_selected = still_selected
	_applying = false
	_update_feedback(applied, rejected)


func _reset_visual_upgrade_state() -> void:
	_upgrade_system.reset_for_run()
	_call_reset("World/CombatAnchorSystem")
	_call_reset("World/ShieldCoreSystem")
	_call_reset("World/AnchorlessControlSystem")
	_call_reset("World/TurretSystem")
	var upgrade_panel: CanvasItem = _game.get_node_or_null(
		"CanvasLayer/UpgradeSelectionPanel"
	) as CanvasItem
	if upgrade_panel != null:
		upgrade_panel.visible = false


func _call_reset(path: NodePath) -> void:
	var node: Node = _game.get_node_or_null(path)
	if node != null and node.has_method("reset_upgrade_runtime"):
		node.call("reset_upgrade_runtime")


func _sync_tree_checks() -> void:
	if _tree == null:
		return
	_applying = true
	for card_id: StringName in _items.keys():
		var item: TreeItem = _items[card_id]
		if item != null:
			item.set_checked(0, bool(_selected.get(card_id, false)))
	_applying = false


func _update_feedback(applied: int, rejected: PackedStringArray) -> void:
	if _feedback == null:
		return
	var text := "Активно: %d" % applied
	if not rejected.is_empty():
		text += "\nНе применено: " + ", ".join(rejected)
	_feedback.text = text


func _is_visual_test_definition(definition: UpgradeDefinition) -> bool:
	if definition == null or not definition.is_valid() or definition.effect == null:
		return false
	var target := String(definition.effect.target_id)
	for prefix: String in VISUAL_TARGET_PREFIXES:
		if target.begins_with(prefix):
			return true
	return false


func _format_branch(branch_id: StringName) -> String:
	if branch_id == &"":
		return "Общее"
	return String(branch_id).replace("_", " ").capitalize()
