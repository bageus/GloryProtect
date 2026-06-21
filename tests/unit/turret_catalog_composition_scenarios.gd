extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/turret_branch_upgrade_catalog.tres"
)


func _init() -> void:
	var coordinator := TurretUpgradeCoordinator.new()
	coordinator.catalog = CATALOG
	var public_definitions: Array[UpgradeDefinition] = (
		coordinator.get_all_card_definitions()
	)
	assert(CATALOG.is_valid())
	assert(public_definitions.size() == CATALOG.get_all_definitions().size())
	assert(_contains_card(public_definitions, &"turret_heavy_explosive_fifth"))
	assert(_contains_card(public_definitions, &"turret_electric_orb_fifth"))
	print("Turret catalog composition scenarios passed")
	quit()


func _contains_card(
	definitions: Array[UpgradeDefinition],
	card_id: StringName
) -> bool:
	for definition: UpgradeDefinition in definitions:
		if definition.card_id == card_id:
			return true
	return false
