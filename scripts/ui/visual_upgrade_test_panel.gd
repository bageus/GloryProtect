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

const COLUMN_UPGRADE: int = 0

var _game: Node
var _game_flow: GameFlowController
var _upgrade_system: UpgradeSystem
var _tree: Tree
var _feedback: Label
var _selected: Dictionary[StringName, bool] = {}
var _ordered_ids: Array[StringName] = []
var _items: Dictionary[StringName, TreeItem] = {}
var _definitions: Dictionary[StringName, UpgradeDefinition] = {}
var _parent_ids: Dictionary[StringName, StringName] = {}
var _children: Dictionary[StringName, Array] = {}
var _item_depths: Dictionary[StringName, int] = {}
var _dimmed_ids: Dictionary[StringName, bool] = {}
var _applying: bool = false


func configure(game: Node) -> void:
	_game = game
	_game_flow = game.get_node("GameFlowController") as GameFlowController
	_upgrade_system = game.get_node("UpgradeSystem") as UpgradeSystem
	_build_ui()
	_rebuild_tree()
	_apply_selected_upgrades()
	_suppress_card_panel()


func _process(_delta: float) -> void:
	_suppress_card_panel()


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


func get_item_depth_for_tests(card_id: StringName) -> int:
	return int(_item_depths.get(card_id, -1))


func get_item_description_for_tests(card_id: StringName) -> String:
	var item: TreeItem = _items.get(card_id, null)
	return "" if item == null else item.get_tooltip_text(COLUMN_UPGRADE)


func get_item_visible_text_for_tests(card_id: StringName) -> String:
	var item: TreeItem = _items.get(card_id, null)
	return "" if item == null else item.get_text(COLUMN_UPGRADE)


func get_parent_card_id_for_tests(card_id: StringName) -> StringName:
	return _parent_ids.get(card_id, &"") as StringName


func is_item_dimmed_for_tests(card_id: StringName) -> bool:
	return bool(_dimmed_ids.get(card_id, false))


func is_upgrade_selected_for_tests(card_id: StringName) -> bool:
	return bool(_selected.get(card_id, false))


func toggle_upgrade_for_tests(card_id: StringName, enabled: bool) -> bool:
	if not _ordered_ids.has(card_id):
		return false
	if enabled and not _are_requirements_selected(_definitions.get(card_id, null)):
		_sync_tree_checks()
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
	panel.offset_left = -380.0
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
	note.text = "Карточки отключены. Улучшения включаются только в этой палитре. Описание показывается при наведении на название."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 1
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(340.0, 560.0)
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
	_definitions.clear()
	_parent_ids.clear()
	_children.clear()
	_item_depths.clear()
	_dimmed_ids.clear()
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var grouped: Dictionary[StringName, Array] = _get_grouped_visual_definitions()
	var branches: Array[StringName] = []
	for raw_branch: Variant in grouped.keys():
		branches.append(raw_branch as StringName)
	branches.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	for branch_id: StringName in branches:
		var branch_definitions: Array = grouped[branch_id]
		_build_dependency_maps(branch_definitions)
		var branch_item: TreeItem = _tree.create_item(root)
		branch_item.set_text(COLUMN_UPGRADE, _format_branch(branch_id))
		branch_item.set_selectable(COLUMN_UPGRADE, false)
		branch_item.collapsed = false
		for definition: UpgradeDefinition in _get_branch_roots(branch_definitions):
			_append_definition_item(branch_item, definition, 0)
	_sync_tree_checks()


func _get_grouped_visual_definitions() -> Dictionary[StringName, Array]:
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
		_definitions[definition.card_id] = definition
		_children[definition.card_id] = []
		if not grouped.has(definition.branch_id):
			grouped[definition.branch_id] = []
		grouped[definition.branch_id].append(definition)
	return grouped


func _build_dependency_maps(definitions: Array) -> void:
	var by_id: Dictionary = {}
	for definition: UpgradeDefinition in definitions:
		by_id[definition.card_id] = definition
	for definition: UpgradeDefinition in definitions:
		var parent_id: StringName = _get_parent_card_id(definition, by_id)
		_parent_ids[definition.card_id] = parent_id
		if parent_id == &"":
			continue
		var child_list: Array = _children[parent_id]
		child_list.append(definition)
		_children[parent_id] = child_list
	for definition: UpgradeDefinition in definitions:
		var child_list: Array = _children.get(definition.card_id, [])
		child_list.sort_custom(func(a: UpgradeDefinition, b: UpgradeDefinition) -> bool:
			return String(a.card_id) < String(b.card_id)
		)
		_children[definition.card_id] = child_list


func _get_branch_roots(definitions: Array) -> Array[UpgradeDefinition]:
	var roots: Array[UpgradeDefinition] = []
	for definition: UpgradeDefinition in definitions:
		if _parent_ids.get(definition.card_id, &"") == &"":
			roots.append(definition)
	roots.sort_custom(func(a: UpgradeDefinition, b: UpgradeDefinition) -> bool:
		return String(a.card_id) < String(b.card_id)
	)
	return roots


func _append_definition_item(
	parent_item: TreeItem,
	definition: UpgradeDefinition,
	depth: int
) -> void:
	var item: TreeItem = _tree.create_item(parent_item)
	item.set_cell_mode(COLUMN_UPGRADE, TreeItem.CELL_MODE_CHECK)
	item.set_editable(COLUMN_UPGRADE, true)
	item.set_text(COLUMN_UPGRADE, definition.title)
	item.set_tooltip_text(COLUMN_UPGRADE, _get_hover_description(definition))
	item.set_metadata(COLUMN_UPGRADE, definition.card_id)
	_items[definition.card_id] = item
	_ordered_ids.append(definition.card_id)
	_item_depths[definition.card_id] = depth
	for child_definition: UpgradeDefinition in _children.get(definition.card_id, []):
		_append_definition_item(item, child_definition, depth + 1)


func _on_tree_item_edited() -> void:
	if _applying:
		return
	var item: TreeItem = _tree.get_edited()
	if item == null:
		return
	var card_id: StringName = item.get_metadata(COLUMN_UPGRADE)
	var enabled: bool = item.is_checked(COLUMN_UPGRADE)
	if enabled and not _are_requirements_selected(_definitions.get(card_id, null)):
		item.set_checked(COLUMN_UPGRADE, false)
		_sync_tree_checks()
		return
	_set_selected(card_id, enabled)
	_apply_selected_upgrades()
	_sync_tree_checks()


func _set_selected(card_id: StringName, enabled: bool) -> void:
	if enabled:
		_selected[card_id] = true
	else:
		_selected.erase(card_id)
		_remove_descendant_selection(card_id)


func _remove_descendant_selection(card_id: StringName) -> void:
	for child_definition: UpgradeDefinition in _children.get(card_id, []):
		_selected.erase(child_definition.card_id)
		_remove_descendant_selection(child_definition.card_id)


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
		if not _are_requirements_recorded(definition):
			rejected.append(definition.title)
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
	_suppress_card_panel()


func _reset_visual_upgrade_state() -> void:
	_upgrade_system.reset_for_run()
	_call_reset("World/CombatAnchorSystem")
	_call_reset("World/ShieldCoreSystem")
	_call_reset("World/AnchorlessControlSystem")
	_call_reset("World/TurretSystem")
	_suppress_card_panel()


func _call_reset(path: NodePath) -> void:
	var node: Node = _game.get_node_or_null(path)
	if node != null and node.has_method("reset_upgrade_runtime"):
		node.call("reset_upgrade_runtime")


func _suppress_card_panel() -> void:
	if _game_flow != null and _game_flow.state == GameFlowController.RunState.CARD_SELECTION:
		_game_flow.finish_card_selection()
	var upgrade_panel: CanvasItem = _game.get_node_or_null(
		"CanvasLayer/UpgradeSelectionPanel"
	) as CanvasItem
	if upgrade_panel == null:
		return
	upgrade_panel.visible = false
	upgrade_panel.set_process(false)
	upgrade_panel.set_process_input(false)
	upgrade_panel.set_process_unhandled_input(false)


func _sync_tree_checks() -> void:
	if _tree == null:
		return
	_applying = true
	for card_id: StringName in _items.keys():
		var item: TreeItem = _items[card_id]
		var definition: UpgradeDefinition = _definitions.get(card_id, null)
		if item == null or definition == null:
			continue
		var selected: bool = bool(_selected.get(card_id, false))
		var available: bool = _are_requirements_selected(definition)
		item.set_checked(COLUMN_UPGRADE, selected)
		item.set_editable(COLUMN_UPGRADE, available)
		_dimmed_ids[card_id] = not available
		_apply_item_visual_state(item, available, selected)
	_applying = false


func _apply_item_visual_state(item: TreeItem, available: bool, selected: bool) -> void:
	if selected:
		item.set_custom_color(COLUMN_UPGRADE, Color(0.92, 1.0, 0.88, 1.0))
		return
	if available:
		item.set_custom_color(COLUMN_UPGRADE, Color(0.92, 0.94, 0.98, 1.0))
		return
	item.set_custom_color(COLUMN_UPGRADE, Color(0.55, 0.57, 0.62, 0.78))


func _update_feedback(applied: int, rejected: PackedStringArray) -> void:
	if _feedback == null:
		return
	var text := "Активно: %d" % applied
	if not rejected.is_empty():
		text += "\nНе применено: " + ", ".join(rejected)
	_feedback.text = text


func _are_requirements_selected(definition: UpgradeDefinition) -> bool:
	if definition == null:
		return false
	for prerequisite_id: StringName in definition.prerequisite_card_ids:
		if not bool(_selected.get(prerequisite_id, false)):
			return false
	if definition.required_repeat_card_id != &"":
		if not bool(_selected.get(definition.required_repeat_card_id, false)):
			return false
	if definition.required_specialization_id != &"":
		if not bool(_selected.get(definition.required_specialization_id, false)):
			return false
	return true


func _are_requirements_recorded(definition: UpgradeDefinition) -> bool:
	if definition == null:
		return false
	for prerequisite_id: StringName in definition.prerequisite_card_ids:
		if not _upgrade_system.get_runtime().has_card(prerequisite_id):
			return false
	if definition.required_repeat_card_id != &"":
		if _upgrade_system.get_runtime().get_repeat_count(
			definition.required_repeat_card_id
		) < definition.required_repeat_count:
			return false
	if definition.required_specialization_id != &"":
		if not _upgrade_system.get_runtime().has_card(definition.required_specialization_id):
			return false
	return true


func _is_visual_test_definition(definition: UpgradeDefinition) -> bool:
	if definition == null or not definition.is_valid() or definition.effect == null:
		return false
	var target := String(definition.effect.target_id)
	for prefix: String in VISUAL_TARGET_PREFIXES:
		if target.begins_with(prefix):
			return true
	return false


func _get_parent_card_id(definition: UpgradeDefinition, by_id: Dictionary) -> StringName:
	for prerequisite_id: StringName in definition.prerequisite_card_ids:
		if by_id.has(prerequisite_id):
			return prerequisite_id
	if definition.required_repeat_card_id != &"" and by_id.has(definition.required_repeat_card_id):
		return definition.required_repeat_card_id
	if definition.required_specialization_id != &"" and by_id.has(definition.required_specialization_id):
		return definition.required_specialization_id
	return &""


func _get_hover_description(definition: UpgradeDefinition) -> String:
	var lines := PackedStringArray([definition.title])
	var requirement_text: String = _get_requirement_text(definition)
	if not requirement_text.is_empty():
		lines.append(requirement_text)
	var child_titles := _get_direct_child_titles(definition.card_id)
	if not child_titles.is_empty():
		lines.append("Открывает: %s" % ", ".join(child_titles))
	var short_description: String = definition.description.strip_edges()
	if not short_description.is_empty():
		lines.append(short_description)
	return "\n".join(lines)


func _get_requirement_text(definition: UpgradeDefinition) -> String:
	var requirements := PackedStringArray()
	if not definition.prerequisite_card_ids.is_empty():
		requirements.append(_join_card_titles(definition.prerequisite_card_ids))
	if definition.required_repeat_card_id != &"":
		requirements.append("%s ×%d" % [
			_get_card_title(definition.required_repeat_card_id),
			definition.required_repeat_count,
		])
	if definition.required_specialization_id != &"":
		requirements.append(_get_card_title(definition.required_specialization_id))
	if requirements.is_empty():
		return ""
	return "Требуется: %s" % ", ".join(requirements)


func _get_direct_child_titles(card_id: StringName) -> PackedStringArray:
	var titles := PackedStringArray()
	for child_definition: UpgradeDefinition in _children.get(card_id, []):
		titles.append(child_definition.title)
	return titles


func _join_card_titles(card_ids: Array[StringName]) -> String:
	var titles := PackedStringArray()
	for card_id: StringName in card_ids:
		titles.append(_get_card_title(card_id))
	return ", ".join(titles)


func _get_card_title(card_id: StringName) -> String:
	var definition: UpgradeDefinition = _upgrade_system.catalog.get_definition(card_id)
	return definition.title if definition != null else String(card_id)


func _format_branch(branch_id: StringName) -> String:
	if branch_id == &"":
		return "Общее"
	return String(branch_id).replace("_", " ").capitalize()
