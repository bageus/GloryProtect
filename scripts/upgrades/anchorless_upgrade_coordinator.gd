class_name AnchorlessUpgradeCoordinator
extends MedicUpgradeCoordinator

@export_node_path("AnchorlessControlSystem") var anchorless_system_path: NodePath = NodePath(
	"../World/AnchorlessControlSystem"
)

@onready var _anchorless: AnchorlessControlSystem = get_node(anchorless_system_path)


func _ready() -> void:
	super._ready()
	_effect_applier.configure(
		_buildables,
		_runtime,
		_crew,
		_replacements,
		_turrets,
		_medical,
		_anchorless
	)
