class_name UpgradeRuntime
extends Node

signal card_recorded(card_id: StringName, repeat_count: int)
signal specialization_selected(branch_id: StringName, specialization_id: StringName)
signal runtime_reset

var _repeat_counts: Dictionary[StringName, int] = {}
var _selected_cards: Array[StringName] = []
var _specializations: Dictionary[StringName, StringName] = {}
var _closed_specializations: Dictionary[StringName, bool] = {}
var _domain_flags: Dictionary[StringName, bool] = {}
var _domain_scalars: Dictionary[StringName, float] = {}


func reset_for_run() -> void:
	_repeat_counts.clear()
	_selected_cards.clear()
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
