class_name CombatAnchorUpgradeCoordinator
extends MedicUpgradeCoordinator

@export_node_path("CombatAnchorSystem") var combat_anchor_system_path: NodePath = NodePath(
	"../World/CombatAnchorSystem"
)

@onready var _combat_anchors: CombatAnchorSystem = get_node(combat_anchor_system_path)


func _ready() -> void:
	super._ready()
	_effect_applier.configure(
		_buildables,
		_runtime,
		_crew,
		_replacements,
		_turrets,
		_medical,
		_combat_anchors
	)
