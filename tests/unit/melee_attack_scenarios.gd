extends SceneTree


func _init() -> void:
	_test_dead_locked_target_wastes_attack()
	_test_living_locked_target_receives_damage()
	print("Melee attack scenarios passed")
	quit()


func _test_dead_locked_target_wastes_attack() -> void:
	var attacker := MeleeAttackComponent.new()
	attacker.configure(1, 0.4, 0.6)
	var original_target := HealthComponent.new()
	original_target.configure(1)
	var other_target := HealthComponent.new()
	other_target.configure(3)

	assert(attacker.try_start(original_target))
	original_target.set_health(0)
	attacker.tick(0.4)

	assert(other_target.current_health == 3)
	assert(not attacker.is_attacking())


func _test_living_locked_target_receives_damage() -> void:
	var attacker := MeleeAttackComponent.new()
	attacker.configure(1, 0.4, 0.6)
	var target := HealthComponent.new()
	target.configure(3)

	assert(attacker.try_start(target))
	attacker.tick(0.4)
	assert(target.current_health == 2)
