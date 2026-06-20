extends SceneTree


func _init() -> void:
	var balance := BuildableBalance.new()
	balance.turret_height = 48.0
	balance.turret_bottom_y = -28.0
	balance.turret_flash_duration = 0.1
	balance.turret_tracer_duration = 0.14

	var buildable := BuildableRuntime.new(
		7,
		BuildableType.Id.TURRET,
		4
	)
	var snapshot := BuildableSnapshot.new(buildable, 96.0)
	var pivot: Vector2 = TurretGeometry.get_local_pivot(snapshot, balance)
	assert(is_equal_approx(pivot.x, 96.0))
	assert(is_equal_approx(pivot.y, -55.84))
	assert(TurretGeometry.get_default_aim_direction() == Vector2.RIGHT)

	var visual := TurretVisualRuntime.new(buildable.buildable_id)
	visual.begin_target(
		12,
		pivot,
		Vector2(180.0, 240.0)
	)
	assert(visual.target_enemy_id == 12)
	assert(visual.shot_origin_local == pivot)
	visual.update_target(Vector2(190.0, 230.0))
	assert(visual.last_target_world == Vector2(190.0, 230.0))

	visual.resolve_shot(
		balance.turret_tracer_duration,
		balance.turret_flash_duration
	)
	assert(visual.target_enemy_id == -1)
	assert(visual.is_effect_active())
	visual.tick(0.05)
	assert(visual.tracer_remaining > 0.0)
	assert(visual.flash_remaining > 0.0)
	visual.tick(0.2)
	assert(not visual.is_effect_active())

	visual.begin_target(13, pivot, Vector2(200.0, 220.0))
	visual.resolve_shot(0.14, 0.1)
	visual.cancel_target()
	assert(visual.target_enemy_id == -1)
	assert(not visual.is_effect_active())

	print("Turret visual runtime scenarios passed")
	quit()
