class_name UpgradeCatalog
extends Resource

@export var definitions: Array[UpgradeDefinition] = []


func is_valid() -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for definition: UpgradeDefinition in definitions:
		if definition == null or not definition.is_valid():
			return false
		if seen.has(definition.card_id):
			return false
		seen[definition.card_id] = true
	return true


func get_definition(card_id: StringName) -> UpgradeDefinition:
	for definition: UpgradeDefinition in definitions:
		if definition != null and definition.card_id == card_id:
			return definition
	return null


func get_available_definitions(runtime: UpgradeRuntime) -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	for definition: UpgradeDefinition in definitions:
		if is_available(definition, runtime):
			result.append(definition)
	return result


func is_available(
	definition: UpgradeDefinition,
	runtime: UpgradeRuntime
) -> bool:
	if definition == null or runtime == null or not definition.is_valid():
		return false
	if runtime.get_repeat_count(definition.card_id) >= definition.repeat_limit:
		return false
	if runtime.is_specialization_closed(definition.card_id):
		return false
	for prerequisite_id: StringName in definition.prerequisite_card_ids:
		if not runtime.has_card(prerequisite_id):
			return false
	if definition.required_specialization_id != &":":
		if definition.required_specialization_id != &"":
			var selected: StringName = runtime.get_specialization(definition.branch_id)
			if selected != definition.required_specialization_id:
				return false
	return true
