class_name AnchorlessUpgradeCoordinator
extends ShieldCoreUpgradeCoordinator

@export_node_path("AnchorlessControlSystem") var anchorless_system_path: NodePath = NodePath(
	"../World/AnchorlessControlSystem"
)

@onready var _anchorless: AnchorlessControlSystem = get_node(anchorless_system_path)


func _ready() -> void:
	_effect_applier = AnchorlessUpgradeEffectApplier.new()
	super._ready()
	_effect_applier.configure(
		_buildables,
		_runtime,
		_crew,
		_replacements,
		_turrets,
		_medical,
		_combat_anchors,
		_shield_core,
		_anchorless
	)
