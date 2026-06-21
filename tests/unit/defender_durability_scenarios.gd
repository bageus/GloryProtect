extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_armor_absorbs_before_health()
	_test_healing_does_not_restore_armor()
	_test_lethal_guard_resolves_before_death()
	_test_later_armor_upgrade_preserves_damage()
	print("Defender durability scenarios passed")
	quit()


func _test_armor_absorbs_before_health() -> void:
	var durability := DefenderDurabilityComponent.new()
	var health := HealthComponent.new()
	root.add_child(durability)
	root.add_child(health)
	health.configure(3)
	durability.configure(2, false)
	health.set_durability_component(durability)
	health.apply_damage(1)
	assert(durability.get_current_armor() == 1)
	assert(health.current_health == 3)
	health.apply_damage(2)
	assert(durability.get_current_armor() == 0)
	assert(health.current_health == 2)
	durability.queue_free()
	health.queue_free()


func _test_healing_does_not_restore_armor() -> void:
	var durability := DefenderDurabilityComponent.new()
	var health := HealthComponent.new()
	root.add_child(durability)
	root.add_child(health)
	health.configure(3)
	durability.configure(1, false)
	health.set_durability_component(durability)
	health.apply_damage(2)
	assert(durability.get_current_armor() == 0)
	assert(health.current_health == 2)
	health.heal(1)
	assert(health.current_health == 3)
	assert(durability.get_current_armor() == 0)
	durability.queue_free()
	health.queue_free()


func _test_lethal_guard_resolves_before_death() -> void:
	var durability := DefenderDurabilityComponent.new()
	var health := HealthComponent.new()
	root.add_child(durability)
	root.add_child(health)
	health.configure(3)
	durability.configure(0, true)
	health.set_durability_component(durability)
	health.apply_damage(3)
	assert(health.current_health == 1)
	assert(not durability.has_lethal_guard())
	health.apply_damage(1)
	assert(health.current_health == 0)
	durability.queue_free()
	health.queue_free()


func _test_later_armor_upgrade_preserves_damage() -> void:
	var durability := DefenderDurabilityComponent.new()
	root.add_child(durability)
	durability.configure(2, false)
	assert(durability.resolve_incoming_damage(1, 3) == 0)
	assert(durability.get_current_armor() == 1)
	durability.set_max_armor(4)
	assert(durability.get_max_armor() == 4)
	assert(durability.get_current_armor() == 3)
	durability.queue_free()
