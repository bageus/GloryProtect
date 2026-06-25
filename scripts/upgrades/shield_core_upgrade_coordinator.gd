class_name ShieldCoreUpgradeCoordinator
extends CombatAnchorUpgradeCoordinator

@export_node_path("ShieldCoreSystem") var shield_core_system_path: NodePath = NodePath(
	"../World/ShieldCoreSystem"
)

@onready var _shield_core: ShieldCoreSystem = get_node(shield_core_system_path)
var _anchorless: AnchorlessControlSystem


func _ready() -> void:
	_anchorless = _ensure_anchorless_system()
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


func _ensure_anchorless_system() -> AnchorlessControlSystem:
	var world: Node = get_node("../World")
	var existing := world.get_node_or_null(
		"AnchorlessControlSystem"
	) as AnchorlessControlSystem
	if existing != null:
		return existing
	var system := AnchorlessControlSystem.new()
	system.name = "AnchorlessControlSystem"
	system.game_flow_path = NodePath("../../GameFlowController")
	system.platform_path = NodePath("../Platform")
	system.wind_system_path = NodePath("../../WindSystem")
	system.contact_system_path = NodePath("../OrbContactSystem")
	system.orb_registry_path = NodePath("../GroundOrbRegistry")
	system.shield_system_path = NodePath("../../ShieldSystem")
	system.anchor_system_path = NodePath("../AnchorSystem")
	system.enemy_registry_path = NodePath("../BoardingEnemyRegistry")
	world.add_child(system)
	return system
