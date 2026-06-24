class_name AnchorlessUpgradeCoordinator
extends ShieldCoreUpgradeCoordinator

@export_node_path("AnchorlessControlSystem") var anchorless_system_path: NodePath

@onready var anchorless_system: AnchorlessControlSystem = get_node(anchorless_system_path)


func _ready() -> void:
	_effect_applier = AnchorlessUpgradeEffectApplier.new()
	super._ready()
	var adapter := _effect_applier as AnchorlessUpgradeEffectApplier
	adapter.set_anchorless_system(anchorless_system)
