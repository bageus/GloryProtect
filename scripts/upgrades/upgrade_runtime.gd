class_name UpgradeRuntime
extends Node

signal card_recorded(card_id: StringName, repeat_count: int)
signal branch_progress_changed(branch_id: StringName, counted_cards: int)
signal branch_specialization_ready(branch_id: StringName)
signal specialization_selected(branch_id: StringName, specialization_id: StringName)
signal runtime_reset

const SPECIALIZATION_REQUIRED_COUNT: int = 2

var _repeat_counts: Dictionary[StringName, int] = {}
var _selected_cards: Array[StringName] = []
var _branch_progress: Dictionary[StringName, int] = {}
var _specializations: Dictionary[StringName, StringName] = {}
var _closed_specializations: Dictionary[StringName, bool] = {}
var _domain_flags: Dictionary[StringName, bool] = {}
var _domain_scalars: Dictionary[StringName, float] = {}


func reset_for_run() -> void:
	_repeat_counts.clear()
	_selected_cards.clear()
	_branch_progress.clear()
	_specializations.clear()
	_closed_specializations.clear()
	_domain_flags.clear()
	_domain_scalars.clear()
	runtime_reset.emit()


func record_card(definition: UpgradeDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	var current_count: int = get_repeat_count(definition.card_id)
	if current_count >= definition.repeat_limit:
		return false
	_repeat_counts[definition.card_id] = current_count + 1
	_selected_cards.append(definition.card_id)
	if _counts_for_specialization(definition.card_type):
		_record_branch_progress(definition.branch_id)
	if definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION:
		_specializations[definition.branch_id] = definition.card_id
		for specialization_id: StringName in definition.closes_specialization_ids:
			_closed_specializations[specialization_id] = true
		specialization_selected.emit(definition.branch_id, definition.card_id)
	card_recorded.emit(definition.card_id, current_count + 1)
	return true


func has_card(card_id: StringName) -> bool:
	return get_repeat_count(card_id) > 0


func get_repeat_count(card_id: StringName) -> int:
	return int(_repeat_counts.get(card_id, 0))


func get_selected_cards() -> Array[StringName]:
	return _selected_cards.duplicate()


func get_branch_progress(branch_id: StringName) -> int:
	return int(_branch_progress.get(branch_id, 0))


func is_branch_ready_for_specialization(branch_id: StringName) -> bool:
	if branch_id == &"" or has_specialization(branch_id):
		return false
	return get_branch_progress(branch_id) >= SPECIALIZATION_REQUIRED_COUNT


func get_ready_specialization_branches() -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_branch_id: Variant in _branch_progress.keys():
		var branch_id: StringName = raw_branch_id
		if is_branch_ready_for_specialization(branch_id):
			result.append(branch_id)
	result.sort()
	return result


func has_specialization(branch_id: StringName) -> bool:
	return get_specialization(branch_id) != &""


func get_specialization(branch_id: StringName) -> StringName:
	return _specializations.get(branch_id, &"")


func is_specialization_closed(specialization_id: StringName) -> bool:
	return bool(_closed_specializations.get(specialization_id, false))


func set_domain_flag(flag_id: StringName, value: bool) -> void:
	if flag_id == &"":
		return
	_domain_flags[flag_id] = value


func get_domain_flag(flag_id: StringName) -> bool:
	return bool(_domain_flags.get(flag_id, false))


func add_domain_scalar(scalar_id: StringName, amount: float) -> void:
	if scalar_id == &"" or is_zero_approx(amount):
		return
	_domain_scalars[scalar_id] = get_domain_scalar(scalar_id) + amount


func get_domain_scalar(scalar_id: StringName) -> float:
	return float(_domain_scalars.get(scalar_id, 0.0))


func _counts_for_specialization(card_type: int) -> bool:
	return card_type in [
		UpgradeDefinition.CardType.BASIC,
		UpgradeDefinition.CardType.ADVANCED,
		UpgradeDefinition.CardType.INDIVIDUAL,
	]


func _record_branch_progress(branch_id: StringName) -> void:
	if branch_id == &"":
		return
	var previous: int = get_branch_progress(branch_id)
	var current: int = previous + 1
	_branch_progress[branch_id] = current
	branch_progress_changed.emit(branch_id, current)
	if (
		previous < SPECIALIZATION_REQUIRED_COUNT
		and current >= SPECIALIZATION_REQUIRED_COUNT
		and not has_specialization(branch_id)
	):
		branch_specialization_ready.emit(branch_id)
