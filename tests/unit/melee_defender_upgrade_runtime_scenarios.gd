extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_base_lines()
	_test_heavy_specialization()
	_test_duelist_specialization()
	_test_assault_specialization()
	_test_reset()
	print("Melee defender upgrade runtime scenarios passed")
	quit()


func _test_base_lines() -> void:
	var upgrades := MeleeDefenderUpgradeRuntime.new()
	assert(upgrades.get_damage(1) == 1)
	assert(upgrades.apply_scalar(&"melee_damage_bonus", 1.0))
	assert(upgrades.apply_scalar(&"melee_damage_bonus", 1.0))
	assert(upgrades.get_damage(1) == 3)
	assert(upgrades.apply_scalar(&"melee_cooldown_multiplier", 0.85))
	assert(upgrades.apply_scalar(&"melee_cooldown_multiplier", 0.85))
	assert(is_equal_approx(upgrades.get_cooldown(0.7), 0.7 * 0.85 * 0.85))
	assert(upgrades.apply_scalar(&"melee_health_bonus", 1.0))
	assert(upgrades.apply_scalar(&"melee_health_bonus", 1.0))
	assert(upgrades.get_max_health(3) == 5)
	assert(upgrades.apply_scalar(&"melee_armor_bonus", 1.0))
	assert(upgrades.armor_bonus == 1)


func _test_heavy_specialization() -> void:
	var upgrades := MeleeDefenderUpgradeRuntime.new()
	assert(upgrades.apply_flag(&"melee_specialization_heavy"))
	assert(upgrades.specialization_id == MeleeDefenderUpgradeRuntime.HEAVY)
	assert(upgrades.get_max_health(3) == 4)
	assert(upgrades.heavy_blocks_jump)
	assert(upgrades.apply_flag(&"melee_heavy_shield"))
	assert(upgrades.armor_bonus == 2)
	assert(upgrades.apply_flag(&"melee_heavy_shield_bash"))
	assert(upgrades.heavy_shield_bash)


func _test_duelist_specialization() -> void:
	var upgrades := MeleeDefenderUpgradeRuntime.new()
	assert(upgrades.apply_flag(&"melee_specialization_duelist"))
	assert(upgrades.specialization_id == MeleeDefenderUpgradeRuntime.DUELIST)
	assert(is_equal_approx(upgrades.get_cooldown(0.8), 0.6))
	assert(upgrades.apply_flag(&"melee_duelist_isolated_damage"))
	assert(upgrades.apply_flag(&"melee_duelist_double_attack"))
	assert(upgrades.apply_flag(&"melee_duelist_counterattack"))
	assert(upgrades.duelist_isolated_damage)
	assert(upgrades.duelist_double_attack)
	assert(upgrades.duelist_counterattack)


func _test_assault_specialization() -> void:
	var upgrades := MeleeDefenderUpgradeRuntime.new()
	assert(upgrades.apply_flag(&"melee_specialization_assault"))
	assert(upgrades.specialization_id == MeleeDefenderUpgradeRuntime.ASSAULT)
	assert(upgrades.assault_splash)
	assert(upgrades.apply_flag(&"melee_assault_back_attack"))
	assert(upgrades.apply_flag(&"melee_assault_lethal_guard"))
	assert(upgrades.assault_back_attack)
	assert(upgrades.assault_lethal_guard)


func _test_reset() -> void:
	var upgrades := MeleeDefenderUpgradeRuntime.new()
	upgrades.apply_scalar(&"melee_damage_bonus", 2.0)
	upgrades.apply_flag(&"melee_specialization_heavy")
	upgrades.apply_flag(&"melee_heavy_shield")
	upgrades.reset()
	assert(upgrades.get_damage(1) == 1)
	assert(upgrades.get_max_health(3) == 3)
	assert(upgrades.armor_bonus == 0)
	assert(upgrades.specialization_id == &"")
