extends SceneTree

const CATALOG := preload("res://resources/enemies/boarding_enemy_catalog.tres")


func _init() -> void:
	assert(CATALOG is BoardingEnemyCatalog)
	var catalog: BoardingEnemyCatalog = CATALOG as BoardingEnemyCatalog
	assert(catalog.validate())

	var basic: BoardingEnemyArchetype = catalog.get_archetype(&"basic")
	var runner: BoardingEnemyArchetype = catalog.get_archetype(&"runner")
	var brute: BoardingEnemyArchetype = catalog.get_archetype(&"brute")
	assert(basic != null and runner != null and brute != null)
	assert(basic.max_health == 1)
	assert(runner.ground_move_speed > basic.ground_move_speed)
	assert(brute.max_health == 3)
	assert(brute.body_radius > basic.body_radius)

	assert(basic.get_weight(0.0) > 0.0)
	assert(is_zero_approx(runner.get_weight(0.14)))
	assert(runner.get_weight(0.5) > 0.0)
	assert(is_zero_approx(brute.get_weight(0.44)))
	assert(brute.get_weight(1.0) > 0.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 19473
	for _index: int in range(100):
		assert(catalog.choose_archetype(rng, 0.0).archetype_id == &"basic")

	var counts: Dictionary[StringName, int] = {
		&"basic": 0,
		&"runner": 0,
		&"brute": 0,
	}
	rng.seed = 92741
	for _index: int in range(1000):
		var chosen: BoardingEnemyArchetype = catalog.choose_archetype(rng, 1.0)
		assert(chosen != null)
		counts[chosen.archetype_id] += 1
	assert(counts[&"basic"] > 0)
	assert(counts[&"runner"] > 0)
	assert(counts[&"brute"] > 0)

	print("Boarding enemy catalog scenarios passed")
	quit()
