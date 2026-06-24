class_name ShieldCoreUpgradeCoordinator
extends CombatAnchorUpgradeCoordinator

@export_node_path("ShieldCoreSystem") var shield_core_system_path: NodePath = NodePath(
	"../World/ShieldCoreSystem"
)

@onready var _shield_core: ShieldCoreSystem = get_node(shield_core_system_path)


func _ready() -> void:
	super._ready()
	_effect_applier.configure(
		_buildables,
		_runtime,
		_crew,
		_replacements,
		_turrets,
		_medical,
		_combat_anchors,
		_shield_core
	)
