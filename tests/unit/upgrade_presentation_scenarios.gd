extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/common_repeatable_upgrade_catalog.tres"
)


func _init() -> void:
	var runtime := UpgradeRuntime.new()
	var builder := UpgradePresentationBuilder.new()
	builder.configure(CATALOG, runtime)

	var add_defender: UpgradeDefinition = CATALOG.get_definition(
		&"common_add_defender"
	)
	var add_view: UpgradeCardViewData = builder.build_card(add_defender)
	assert(add_view.card_id == &"common_add_defender")
	assert(add_view.branch_label == "Общий пул")
	assert(add_view.card_type_label == "Общая")
	assert(add_view.effect_summary.contains("+1"))
	assert(add_view.requirements_summary == "Нет дополнительных требований")
	assert(add_view.repeat_progress == "0/5")
	assert(add_view.is_selectable())

	assert(runtime.record_card(add_defender))
	assert(runtime.record_card(add_defender))
	add_view = builder.build_card(add_defender)
	assert(add_view.repeat_progress == "2/5")

	var powered_movement: UpgradeDefinition = CATALOG.get_definition(
		&"common_move_speed_power"
	)
	var movement_view: UpgradeCardViewData = builder.build_card(
		powered_movement,
		&"missing_prerequisite"
	)
	assert(movement_view.requirements_summary.contains("○"))
	assert(movement_view.requirements_summary.contains(
		"Улучшенная скорость перемещения защитников"
	))
	assert(not movement_view.is_selectable())
	assert(movement_view.unavailable_reason_text.contains("предыдущая"))

	assert(
		builder.get_reason_text(&"repeat_limit_reached")
		== "Достигнут лимит повторений"
	)
	print("Upgrade presentation scenarios passed")
	quit()
