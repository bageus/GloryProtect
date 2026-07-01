class_name EffectiveRangeShooterCombatController
extends ShooterCombatController


func configure(
	defender: Defender,
	game_flow: GameFlowController,
	roles: CrewRoleManager,
	enemies: BoardingEnemyRegistry,
	crew: CrewManager,
	ranged: RangedAttackComponent
) -> void:
	super.configure(defender, game_flow, roles, enemies, crew, ranged)
	if not crew.shooter_upgrades_changed.is_connected(
		_on_shooter_upgrades_changed
	):
		crew.shooter_upgrades_changed.connect(_on_shooter_upgrades_changed)
	_sync_effective_range()


func reset_for_run() -> void:
	super.reset_for_run()
	_sync_effective_range()


func get_effective_range() -> float:
	if base_profile == null:
		return 0.0
	if _crew == null:
		return base_profile.maximum_range
	return _crew.get_shooter_upgrades().get_range(
		base_profile.maximum_range
	)


func _sync_effective_range() -> void:
	if _ranged == null or _ranged.profile == null:
		return
	_ranged.profile.maximum_range = get_effective_range()


func _on_shooter_upgrades_changed() -> void:
	_sync_effective_range()
