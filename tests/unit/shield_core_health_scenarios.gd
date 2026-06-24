extends SceneTree

var _destroyed_count: int = 0


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var shield := ShieldCoreShieldSystem.new()
	shield.balance = ShieldBalance.new()
	root.add_child(shield)
	await process_frame
	shield.section_destroyed.connect(_on_section_destroyed)

	assert(is_equal_approx(shield.get_display_health_percent(0), 100.0))
	shield.set_capacity_multiplier(1.2)
	assert(is_equal_approx(shield.get_effective_max_health(), 120.0))
	assert(is_equal_approx(shield.get_display_health_percent(0), 100.0))
	shield.apply_damage(0, 10.0)
	assert(is_equal_approx(shield.get_health(0), 110.0))
	assert(is_equal_approx(
		shield.get_display_health_percent(0),
		100.0 * 110.0 / 120.0
	))
	assert(shield.get_display_health_percent(0) <= 100.0)

	shield.configure_emergency_reserve(true, 1.0, 5.0)
	shield.set_health(0, 5.0)
	shield.apply_damage(0, 10.0)
	assert(shield.has_emergency_reserve_been_used())
	assert(is_equal_approx(shield.get_display_health_percent(0), 1.0))
	assert(shield.is_section_held(0))
	assert(_destroyed_count == 0)

	shield.apply_damage(0, 100.0)
	shield.restore(0, 100.0)
	assert(is_equal_approx(shield.get_display_health_percent(0), 1.0))
	shield.tick_emergency_reserve(4.9)
	assert(shield.is_section_held(0))
	shield.tick_emergency_reserve(0.2)
	assert(not shield.is_section_held(0))
	shield.apply_damage(0, 100.0)
	assert(is_zero_approx(shield.get_health(0)))
	assert(_destroyed_count == 1)

	shield.configure_emergency_reserve(false, 1.0, 5.0)
	assert(not shield.has_emergency_reserve_been_used())

	print("Shield core health scenarios passed")
	quit()


func _on_section_destroyed(_section_id: int) -> void:
	_destroyed_count += 1
