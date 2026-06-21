class_name MedicUpgradeCoordinator
extends TurretUpgradeCoordinator

@export_node_path("MedicalStationSystem") var medical_system_path: NodePath = NodePath(
	"../World/MedicalStationSystem"
)

@onready var _medical: MedicalStationSystem = get_node(medical_system_path)


func _ready() -> void:
	super._ready()
	_effect_applier.configure(
		_buildables,
		_runtime,
		_crew,
		_replacements,
		_turrets,
		_medical
	)
