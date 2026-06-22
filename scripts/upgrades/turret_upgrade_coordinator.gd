class_name TurretUpgradeCoordinator
extends UpgradeSystem

@export_node_path("TurretUpgradeSystem") var turret_system_path: NodePath = NodePath(
	"../World/TurretSystem"
)

@onready var _turrets: TurretUpgradeSystem = get_node(turret_system_path)


func _ready() -> void:
	super._ready()
	_effect_applier.configure(
		_buildables,
		_runtime,
		_crew,
		_replacements,
		_turrets
	)


func get_all_card_definitions() -> Array[UpgradeDefinition]:
	return catalog.get_all_definitions()
