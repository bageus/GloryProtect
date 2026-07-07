extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: UpgradeCatalog = load(
		"res://resources/upgrades/combat_anchor_upgrade_catalog.tres"
	)
	var basic: UpgradeDefinition = catalog.get_definition(
		&"anchor_periodic_electric_basic"
	)
	var advanced: UpgradeDefinition = catalog.get_definition(
		&"anchor_periodic_electric_advanced"
	)
	assert(basic != null)
	assert(advanced != null)
	assert(basic.title == "Электрифицированный трос")
	assert(advanced.title == "Улучшенный электрифицированный трос")
	assert(basic.description.contains("трос"))
	assert(advanced.description.contains("трос"))
	assert(not basic.title.contains("якор"))
	assert(not advanced.title.contains("якор"))
	assert(advanced.prerequisite_card_ids.size() == 1)
	assert(advanced.prerequisite_card_ids[0] == basic.card_id)
	print("Anchor electric rope rename scenarios passed")
	quit()
