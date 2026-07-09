class_name ShieldCoreUpgradeCoordinator
extends CombatAnchorUpgradeCoordinator

@export_node_path("ShieldCoreSystem") var shield_core_system_path: NodePath = NodePath(
	"../World/ShieldCoreSystem"
)
@export_node_path("AnchorlessControlSystem") var anchorless_control_system_path: NodePath = NodePath(
	"../World/AnchorlessControlSystem"
)

@onready var _shield_core: ShieldCoreSystem = get_node(shield_core_system_path)
@onready var _anchorless: AnchorlessControlSystem = get_node(anchorless_control_system_path)


func _ready() -> void:
	_effect_applier = AnchorlessUpgradeEffectApplier.new()
	super._ready()
	var adapter := _effect_applier as AnchorlessUpgradeEffectApplier
	adapter.configure(
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
	var recharge: ShieldCoreRechargeController = get_node(
		"../World/ShieldRechargeController"
	)
	recharge.set_anchorless_control(_anchorless)
