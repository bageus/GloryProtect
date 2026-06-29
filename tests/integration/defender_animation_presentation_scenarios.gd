extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")
const SHOOTER_PROFILE: RangedAttackProfile = preload(
	"res://resources/crew/shooter_attack_profile.tres"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate() as Node2D
	var flow: GameFlowController = game.get_node("GameFlowController")
	flow.start_delay_seconds = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	flow.state = GameFlowController.RunState.RUNNING
	_disable_spawners(game)

	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var roles: CrewRoleManager = game.get_node("World/Platform/CrewRoleManager")
	roles.request_assignment(0, CrewRole.Id.FREE_FIGHTER)
	await _wait_for_role(roles, 0, CrewRole.Id.FREE_FIGHTER)

	var defender: Defender = crew.get_defender(0)
	var visual := defender.visual as DefenderVisualPolished
	assert(visual != null)
	defender.combat.set_physics_process(false)
	defender.shooter_combat.set_physics_process(false)
	defender.ranged.set_physics_process(false)
	visual.set_process(false)

	defender.movement.stop()
	visual._process(0.2)
	assert(visual.get_presentation_state_id() == &"idle")

	defender.teleport_to(0.0)
	defender.move_to(120.0)
	visual._process(0.2)
	assert(visual.get_presentation_state_id() == &"run")
	assert(visual.is_facing_right())
	assert(visual.get_animation_frame() > 0)

	defender.teleport_to(0.0)
	defender.move_to(-120.0)
	visual._process(0.2)
	assert(not visual.is_facing_right())
	defender.movement.stop()

	var target := Node2D.new()
	var target_health := HealthComponent.new()
	target.add_child(target_health)
	root.add_child(target)
	target.global_position = defender.global_position + Vector2(24.0, 0.0)
	target_health.configure(10)

	defender.melee.configure(1, 0.5, 1.0, defender)
	assert(defender.melee.try_start(target_health))
	defender.melee.tick(0.25)
	visual._process(0.0)
	assert(visual.get_presentation_state_id() == &"attack")
	assert(visual.is_facing_right())
	assert(visual.get_animation_frame() in [2, 3])
	assert(target_health.current_health == 10)
	defender.melee.tick(0.25)
	assert(target_health.current_health == 9)
	defender.melee.cancel()

	var ranged_profile := SHOOTER_PROFILE.duplicate(true) as RangedAttackProfile
	defender.ranged.configure(ranged_profile, defender, flow)
	target.global_position = defender.global_position + Vector2(-40.0, 0.0)
	assert(defender.ranged.try_start(target_health))
	defender.ranged.tick(ranged_profile.windup_duration * 0.5)
	visual._process(0.0)
	assert(visual.get_presentation_state_id() == &"attack")
	assert(not visual.is_facing_right())
	assert(visual.get_animation_frame() in [2, 3])
	defender.ranged.cancel()

	visual.set_role(CrewRole.Id.MEDIC)
	defender.set_medic_role_modifiers(true, false, 0, 1.0)
	defender.set_medic_healing_action_active(true)
	visual._process(0.2)
	assert(visual.get_presentation_state_id() == &"heal")
	assert(visual.get_animation_frame() > 0)

	defender.set_medic_healing_action_active(false)
	visual.play_death()
	visual._process(0.2)
	assert(visual.get_presentation_state_id() == &"death")
	assert(visual.get_animation_frame() > 0)

	target.queue_free()
	print("Defender animation presentation scenarios passed")
	quit()


func _wait_for_role(
	roles: CrewRoleManager,
	defender_id: int,
	role_id: int
) -> void:
	for _frame: int in range(360):
		var assignment: CrewAssignmentRuntime = roles.get_assignment(defender_id)
		if (
			assignment != null
			and assignment.current_role == role_id
			and assignment.state == CrewAssignmentRuntime.State.ACTIVE
		):
			return
		await physics_frame
	assert(false, "Defender did not reach requested role")


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var node: Node = game.get_node(path)
		node.set_process(false)
		node.set_physics_process(false)
