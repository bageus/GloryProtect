extends SceneTree

var _landed_count: int = 0
var _started_count: int = 0
var _finished_count: int = 0
var _melee: MeleeAttackComponent


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var target := HealthComponent.new()
	_melee = MeleeAttackComponent.new()
	root.add_child(target)
	root.add_child(_melee)
	target.configure(3)
	_melee.configure(1, 0.1, 0.2)
	_melee.attack_started.connect(_on_attack_started)
	_melee.attack_landed.connect(_on_attack_landed)
	_melee.attack_finished.connect(_on_attack_finished)

	assert(_melee.try_start(target))
	assert(_started_count == 1)
	_melee.tick(0.1)
	assert(_landed_count == 1)
	assert(_started_count == 2)
	assert(_finished_count == 0)
	assert(target.current_health == 2)
	assert(_melee.is_attacking())

	_melee.tick(0.1)
	assert(_landed_count == 2)
	assert(_finished_count == 1)
	assert(target.current_health == 1)
	assert(_melee.is_busy())
	assert(not _melee.is_attacking())

	_melee.tick(0.2)
	assert(not _melee.is_busy())
	print("Melee attack follow-up scenarios passed")
	quit()


func _on_attack_started(_target: HealthComponent) -> void:
	_started_count += 1


func _on_attack_landed(
	_target: HealthComponent,
	_damage: int
) -> void:
	_landed_count += 1
	if _landed_count == 1:
		assert(_melee.queue_follow_up_same_target())


func _on_attack_finished() -> void:
	_finished_count += 1
