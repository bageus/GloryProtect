class_name UpgradeDefinition
extends Resource

enum CardType {
	UNLOCK,
	BASIC,
	ADVANCED,
	INDIVIDUAL,
	SPECIALIZATION,
	SPECIALIZATION_EXTRA,
	GENERAL,
}

@export var card_id: StringName
@export var branch_id: StringName
@export var title: String
@export_multiline var description: String
@export var card_type: CardType = CardType.BASIC
@export var prerequisite_card_ids: Array[StringName] = []
@export var required_specialization_id: StringName
@export var closes_specialization_ids: Array[StringName] = []
@export_range(1, 99, 1) var repeat_limit: int = 1
@export var effect: UpgradeEffectDefinition


func is_valid() -> bool:
	if card_id == &"" or title.is_empty():
		return false
	if repeat_limit <= 0:
		return false
	if card_type != CardType.GENERAL and branch_id == &"":
		return false
	if card_type == CardType.SPECIALIZATION and required_specialization_id != &"":
		return false
	return effect == null or effect.is_valid()
