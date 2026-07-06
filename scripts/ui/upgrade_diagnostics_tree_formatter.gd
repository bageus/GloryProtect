class_name UpgradeDiagnosticsTreeFormatter
extends RefCounted


static func build(upgrades: UpgradeSystem) -> String:
	var lines := PackedStringArray([
		"ДЕРЕВО УЛУЧШЕНИЙ ТЕСТОВОГО РЕЖИМА",
		"✓ взято  ● доступно  ○ закрыто",
		"Базовые открытия показаны корнями веток: турель, пост лекаря, стрелок и т.д.",
	])
	var branch_ids: Array[StringName] = []
	var by_branch: Dictionary = {}
	for definition: UpgradeDefinition in upgrades.get_all_card_definitions():
		if definition == null:
			continue
		var branch_id: StringName = definition.branch_id
		if not by_branch.has(branch_id):
			by_branch[branch_id] = []
			branch_ids.append(branch_id)
		var branch_definitions: Array = by_branch[branch_id]
		branch_definitions.append(definition)
		by_branch[branch_id] = branch_definitions
	for branch_id: StringName in branch_ids:
		_append_branch_tree(lines, branch_id, by_branch[branch_id], upgrades)
	return "\n".join(lines)


static func _append_branch_tree(
	lines: PackedStringArray,
	branch_id: StringName,
	definitions: Array,
	upgrades: UpgradeSystem
) -> void:
	lines.append("")
	lines.append("[%s]" % UpgradeCardFormatter.get_branch_name(branch_id))
	var by_id: Dictionary = {}
	var children: Dictionary = {}
	for definition: UpgradeDefinition in definitions:
		by_id[definition.card_id] = definition
		children[definition.card_id] = []
	var roots: Array[UpgradeDefinition] = []
	for definition: UpgradeDefinition in definitions:
		var parent_id: StringName = _get_tree_parent_card_id(definition, by_id)
		if parent_id == &"":
			roots.append(definition)
		else:
			var child_list: Array = children[parent_id]
			child_list.append(definition)
			children[parent_id] = child_list
	if roots.is_empty():
		roots = definitions.duplicate()
	for index: int in range(roots.size()):
		_append_definition_tree(
			lines,
			roots[index],
			children,
			upgrades,
			"",
			index == roots.size() - 1,
			{}
		)


static func _append_definition_tree(
	lines: PackedStringArray,
	definition: UpgradeDefinition,
	children: Dictionary,
	upgrades: UpgradeSystem,
	indent: String,
	is_last: bool,
	visited: Dictionary
) -> void:
	if definition == null or visited.has(definition.card_id):
		return
	visited[definition.card_id] = true
	var reason: StringName = upgrades.get_card_unavailability_reason(definition.card_id)
	lines.append("%s%s%s %s [%s] — %s%s" % [
		indent,
		"└─ " if is_last else "├─ ",
		_get_status_symbol(definition, reason, upgrades),
		definition.title,
		UpgradeCardFormatter.get_type_name(definition.card_type),
		UpgradeCardFormatter.get_diagnostic_text(reason),
		_get_compact_requirement_text(definition, upgrades),
	])
	var child_list: Array = children.get(definition.card_id, [])
	var next_indent: String = indent + ("   " if is_last else "│  ")
	for index: int in range(child_list.size()):
		_append_definition_tree(
			lines,
			child_list[index],
			children,
			upgrades,
			next_indent,
			index == child_list.size() - 1,
			visited
		)


static func _get_tree_parent_card_id(
	definition: UpgradeDefinition,
	by_id: Dictionary
) -> StringName:
	for prerequisite_id: StringName in definition.prerequisite_card_ids:
		if by_id.has(prerequisite_id):
			return prerequisite_id
	if definition.required_repeat_card_id != &"" and by_id.has(definition.required_repeat_card_id):
		return definition.required_repeat_card_id
	if definition.required_specialization_id != &"" and by_id.has(definition.required_specialization_id):
		return definition.required_specialization_id
	return &""


static func _get_status_symbol(
	definition: UpgradeDefinition,
	reason: StringName,
	upgrades: UpgradeSystem
) -> String:
	if upgrades.get_runtime().has_card(definition.card_id):
		return "✓"
	return "●" if reason == &"" else "○"


static func _get_compact_requirement_text(
	definition: UpgradeDefinition,
	upgrades: UpgradeSystem
) -> String:
	var requirements := PackedStringArray()
	if not definition.prerequisite_card_ids.is_empty():
		requirements.append("после %s" % _join_card_titles(definition.prerequisite_card_ids, upgrades))
	if definition.required_repeat_count > 0:
		requirements.append("нужно %s ×%d" % [
			_get_card_title(definition.required_repeat_card_id, upgrades),
			definition.required_repeat_count,
		])
	if definition.required_specialization_id != &"":
		requirements.append("спец. %s" % _get_card_title(definition.required_specialization_id, upgrades))
	if definition.required_specialized_branch_id != &"":
		requirements.append("нужна специализация ветки %s" % UpgradeCardFormatter.get_branch_name(definition.required_specialized_branch_id))
	if definition.required_completed_branch_id != &"":
		requirements.append("нужна завершённая линия %s" % UpgradeCardFormatter.get_branch_name(definition.required_completed_branch_id))
	if definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION:
		requirements.append("событие специализации после базовой линии")
	return "" if requirements.is_empty() else " | " + "; ".join(requirements)


static func _join_card_titles(card_ids: Array[StringName], upgrades: UpgradeSystem) -> String:
	var titles := PackedStringArray()
	for card_id: StringName in card_ids:
		titles.append(_get_card_title(card_id, upgrades))
	return ", ".join(titles)


static func _get_card_title(card_id: StringName, upgrades: UpgradeSystem) -> String:
	var definition: UpgradeDefinition = upgrades.catalog.get_definition(card_id)
	return definition.title if definition != null else String(card_id)
