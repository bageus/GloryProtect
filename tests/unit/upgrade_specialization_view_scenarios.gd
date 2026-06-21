extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/common_repeatable_upgrade_catalog.tres"
)


func _init() -> void:
	var runtime := UpgradeRuntime.new()
	var builder := UpgradePresentationBuilder.new()
	builder.configure(CATALOG, runtime)

	var specialization_count: int = 0
	for definition: UpgradeDefinition in CATALOG.definitions:
		if definition.card_type != UpgradeDefinition.CardType.SPECIALIZATION:
			continue
		specialization_count += 1
		var view: UpgradeCardViewData = builder.build_card(
			definition,
			&"",
			true
		)
		assert(view.card_type_label == "Специализация")
		assert(view.branch_label == "Турели")
		assert(view.has_specialization_warning())
		assert(view.specialization_warning.contains("заблокирует"))

	assert(specialization_count == 3)
	print("Upgrade specialization view scenarios passed")
	quit()
