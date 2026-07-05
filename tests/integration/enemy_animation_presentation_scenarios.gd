extends SceneTree

const ENEMY_SCENE := preload("res://scenes/boarding/boarding_enemy.tscn")
const BASIC: BoardingEnemyArchetype = preload(
	"res://resources/enemies/boarding_basic.tres"
)
const RUNNER: BoardingEnemyArchetype = preload(
	"res://resources/enemies/boarding_runner.tres"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var enemy := ENEMY_SCENE.instantiate() as BoardingEnemy
	host.add_child(enemy)
	await process_frame

	var visual: BoardingEnemyVisual = enemy.visual
	visual.set_process(false)
	visual.configure(BASIC)

	enemy.controller.state = BoardingEnemyController.State.RUNNING_TO_ANCHOR
	enemy.global_position.x = 20.0
	visual._process(0.2)
	assert(visual.get_presentation_state_id() == &"run")
	assert(visual.is_facing_right())
	assert(visual.get_animation_frame() > 0)

	enemy.global_position.x = -20.0
	visual._process(0.2)
	assert(not visual.is_facing_right())

	enemy.controller.stop()
	enemy.global_position.x = -60.0
	visual._process(0.2)
	assert(visual.get_presentation_state_id() == &"run")
	assert(not visual.is_facing_right())
	assert(visual.get_animation_frame() > 0)

	enemy.controller.state = BoardingEnemyController.State.CLIMBING
	visual._process(0.2)
	assert(visual.get_presentation_state_id() == &"climb")

	enemy.controller.state = BoardingEnemyController.State.JUMPING
	visual._process(0.2)
	assert(visual.get_presentation_state_id() == &"jump")

	var target := Node2D.new()
	var target_health := HealthComponent.new()
	target.add_child(target_health)
	host.add_child(target)
	target_health.configure(10)
	enemy.melee.configure(1, 0.5, 1.0, enemy)
	assert(enemy.melee.try_start(target_health))
	enemy.melee.tick(0.25)
	enemy.controller.state = BoardingEnemyController.State.FIGHTING
	visual._process(0.0)
	assert(visual.get_presentation_state_id() == &"attack")
	assert(visual.get_animation_frame() in [2, 3])
	assert(target_health.current_health == 10)
	enemy.melee.tick(0.25)
	assert(target_health.current_health == 9)

	visual.configure(RUNNER)
	assert(visual.get("_archetype_id") == &"runner")

	var detached_visual: BoardingEnemyVisual = visual
	enemy.kill(&"presentation_test")
	assert(detached_visual.is_detached_death())
	assert(detached_visual.get_presentation_state_id() == &"death")
	assert(detached_visual.get_parent() == host)
	await process_frame
	assert(not is_instance_valid(enemy))
	assert(is_instance_valid(detached_visual))
	detached_visual._process(1.0)
	await process_frame
	assert(not is_instance_valid(detached_visual))

	print("Enemy animation presentation scenarios passed")
	quit()
