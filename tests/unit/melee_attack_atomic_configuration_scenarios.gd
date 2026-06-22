extends SceneTree


func _init() -> void:
	var attack := MeleeAttackComponent.new()
	var target := HealthComponent.new()
	target.configure(10)
	attack.configure(1, 0.4, 0.7)

	assert(attack.try_start(target))
	attack.configure(3, 0.4, 0.2)
	attack.tick(0.4)
	assert(target.current_health == 9)
	assert(is_equal_approx(float(attack.get("_remaining_time")), 0.7))

	attack.tick(0.7)
	assert(attack.can_start())
	assert(attack.try_start(target))
	attack.tick(0.4)
	assert(target.current_health == 6)
	assert(is_equal_approx(float(attack.get("_remaining_time")), 0.2))

	attack.free()
	target.free()
	print("Melee attack atomic configuration scenarios passed")
	quit()
