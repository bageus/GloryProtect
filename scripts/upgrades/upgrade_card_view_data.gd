class_name UpgradeCardViewData
extends RefCounted

var card_id: StringName = &""
var title: String = ""
var description: String = ""
var branch_id: StringName = &""
var branch_label: String = ""
var card_type: int = UpgradeDefinition.CardType.BASIC
var card_type_label: String = ""
var effect_summary: String = ""
var requirements_summary: String = ""
var repeat_progress: String = ""
var specialization_warning: String = ""
var unavailable_reason_id: StringName = &""
var unavailable_reason_text: String = ""


func is_selectable() -> bool:
	return unavailable_reason_id == &""


func has_repeat_progress() -> bool:
	return not repeat_progress.is_empty()


func has_specialization_warning() -> bool:
	return not specialization_warning.is_empty()
