class_name UpgradeCatalog
extends Resource

@export var definitions: Array[UpgradeDefinition] = []
@export var included_catalogs: Array[UpgradeCatalog] = []

func is_valid() -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for definition: UpgradeDefinition in get_all_definitions():
		if definition == null or not definition.is_valid():
			return false
		if seen.has(definition.card_id):
			return false
		seen[definition.card_id] = true
	return true

func get_all_definitions() -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = definitions.duplicate()
	for included: UpgradeCatalog in included_catalogs:
		if included == null or included == self:
			continue
		result.append_array(included.get_all_definitions())
	return result

func get_definition(card_id: StringName) -> UpgradeDefinition:
	for definition: UpgradeDefinition in get_all_definitions():
		if definition != null and definition.card_id == card_id:
			return definition
	return null

func get_available_definitions(runtime: UpgradeRuntime) -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	for definition: UpgradeDefinition in get_all_definitions():
		if is_available(definition, runtime):
			result.append(definition)
	return result

func is_available(definition: UpgradeDefinition, runtime: UpgradeRuntime) -> bool:
	if definition == null or runtime == null or not definition.is_valid():
		return false
	if runtime.get_repeat_count(definition.card_id) >= definition.repeat_limit:
		return false
	if runtime.is_specialization_closed(definition.card_id):
		return false
	for prerequisite_id: StringName in definition.prerequisite_card_ids:
		if not runtime.has_card(prerequisite_id):
			return false
	if definition.required_repeat_count > 0:
		if runtime.get_repeat_count(definition.required_repeat_card_id) < definition.required_repeat_count:
			return false
	if definition.required_specialization_id != &"":
		if runtime.get_specialization(definition.branch_id) != definition.required_specialization_id:
			return false
	if definition.required_specialized_branch_id != &"":
		if not runtime.has_specialization(definition.required_specialized_branch_id):
			return false
	if definition.required_completed_branch_id != &"":
		if not _has_completed_line(definition.required_completed_branch_id, runtime):
			return false
	return true

func _has_completed_line(branch_id: StringName, runtime: UpgradeRuntime) -> bool:
	for definition: UpgradeDefinition in get_all_definitions():
		if definition.branch_id != branch_id:
			continue
		if definition.card_type != UpgradeDefinition.CardType.ADVANCED:
			continue
		if runtime.has_card(definition.card_id):
			return true
	return false
