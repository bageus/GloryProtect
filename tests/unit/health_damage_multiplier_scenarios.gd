extends SceneTree


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var health := HealthComponent.new()
	root.add_child(health)
	health.configure(6)
	health.set_incoming_damage_multiplier(1.5)
	health.apply_damage(2, &"test")
	assert(health.current_health == 3)
	health.set_incoming_damage_multiplier(1.0)
	health.apply_damage(1, &"test")
	assert(health.current_health == 2)
	health.configure(6)
	assert(is_equal_approx(health.get_incoming_damage_multiplier(), 1.0))
	print("Health damage multiplier scenarios passed")
	quit()
