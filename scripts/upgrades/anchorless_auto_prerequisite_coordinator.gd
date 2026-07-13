class_name AnchorlessAutoPrerequisiteCoordinator
extends ShieldCoreUpgradeCoordinator

const AUTO_STEERING_CARD_ID: StringName = &"anchorless_auto_steering"
const AUTO_STEERING_PREREQUISITES: Array[StringName] = [
	&"anchorless_steering_force_basic",
	&"anchorless_wind_reduction_basic",
	&"anchorless_release_drag_basic",
]


func _ready() -> void:
	_configure_automatic_steering_prerequisites()
	super._ready()


func get_automatic_steering_prerequisites_for_tests() -> Array[StringName]:
	var definition: UpgradeDefinition = catalog.get_definition(
		AUTO_STEERING_CARD_ID
	)
	return [] if definition == null else definition.prerequisite_card_ids.duplicate()


func _configure_automatic_steering_prerequisites() -> void:
	if catalog == null:
		return
	var definition: UpgradeDefinition = catalog.get_definition(
		AUTO_STEERING_CARD_ID
	)
	if definition == null:
		return
	definition.required_completed_branch_id = &""
	definition.prerequisite_card_ids = AUTO_STEERING_PREREQUISITES.duplicate()
