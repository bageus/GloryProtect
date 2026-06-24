class_name UpgradeSpecializationEventGenerator
extends RefCounted

var _catalog: UpgradeCatalog
var _runtime: UpgradeRuntime
var _rng := RandomNumberGenerator.new()

func configure(
	catalog: UpgradeCatalog,
	runtime: UpgradeRuntime,
	random_seed: int = 0
) -> void:
	assert(catalog != null and catalog.is_valid())
	assert(runtime != null)
	_catalog = catalog
	_runtime = runtime
	set_seed(random_seed)

func set_seed(random_seed: int) -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed

func has_ready_event() -> bool:
	return not get_ready_event_branches().is_empty()

func get_ready_event_branches() -> Array[StringName]:
	var result: Array[StringName] = []
	for branch_id: StringName in _runtime.get_ready_specialization_branches():
		if get_specialization_cards(branch_id).size() == 3:
			result.append(branch_id)
	return result

func choose_ready_branch() -> StringName:
	var branches: Array[StringName] = get_ready_event_branches()
	if branches.is_empty():
		return &""
	return branches[_rng.randi_range(0, branches.size() - 1)]

func generate_event_offer(branch_id: StringName = &"") -> Array[UpgradeDefinition]:
	var selected_branch: StringName = branch_id
	if selected_branch == &"":
		selected_branch = choose_ready_branch()
	if selected_branch == &"":
		return []
	if not _runtime.is_branch_ready_for_specialization(selected_branch):
		return []
	return get_specialization_cards(selected_branch)

func get_specialization_cards(branch_id: StringName) -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	if branch_id == &"" or _runtime.has_specialization(branch_id):
		return result
	for definition: UpgradeDefinition in _catalog.get_all_definitions():
		if definition == null:
			continue
		if definition.branch_id != branch_id:
			continue
		if definition.card_type != UpgradeDefinition.CardType.SPECIALIZATION:
			continue
		if _runtime.get_repeat_count(definition.card_id) >= definition.repeat_limit:
			continue
		if _runtime.is_specialization_closed(definition.card_id):
			continue
		var prerequisites_met: bool = true
		for prerequisite_id: StringName in definition.prerequisite_card_ids:
			if not _runtime.has_card(prerequisite_id):
				prerequisites_met = false
				break
		if prerequisites_met:
			result.append(definition)
	result.sort_custom(func(first: UpgradeDefinition, second: UpgradeDefinition) -> bool:
		return first.card_id < second.card_id
	)
	return result
