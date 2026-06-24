extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var runtime := ShieldCoreUpgradeRuntime.new()
	assert(runtime.apply_scalar(
		ShieldCoreUpgradeRuntime.CAPACITY_BONUS_RATIO,
		0.1
	))
	assert(runtime.apply_scalar(
		ShieldCoreUpgradeRuntime.CAPACITY_BONUS_RATIO,
		0.1
	))
	assert(is_equal_approx(runtime.capacity_bonus_ratio, 0.2))
	assert(runtime.apply_scalar(
		ShieldCoreUpgradeRuntime.RECHARGE_BONUS_RATIO,
		0.1
	))
	assert(runtime.apply_scalar(
		ShieldCoreUpgradeRuntime.CONTACT_WIDTH_BONUS_RATIO,
		0.1
	))
	assert(is_equal_approx(runtime.recharge_bonus_ratio, 0.1))
	assert(is_equal_approx(runtime.contact_width_bonus_ratio, 0.1))

	assert(runtime.apply_flag(ShieldCoreUpgradeRuntime.FOCUSED))
	assert(runtime.has_focused_specialization())
	assert(not runtime.apply_flag(ShieldCoreUpgradeRuntime.DISTRIBUTED))
	assert(not runtime.apply_flag(ShieldCoreUpgradeRuntime.SURGE))

	runtime.reset()
	assert(is_zero_approx(runtime.capacity_bonus_ratio))
	assert(is_zero_approx(runtime.recharge_bonus_ratio))
	assert(is_zero_approx(runtime.contact_width_bonus_ratio))
	assert(runtime.specialization_id == &"")
	assert(runtime.apply_flag(ShieldCoreUpgradeRuntime.DISTRIBUTED))
	assert(runtime.has_distributed_specialization())

	var balance := ShieldCoreBalance.new()
	assert(balance.is_valid())
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var rows := balance.get_surge_row_count(rng)
	assert(rows >= 1 and rows <= 2)

	print("Shield core runtime scenarios passed")
	quit()
