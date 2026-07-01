class_name SurfaceAlignedBoardingEnemy
extends BoardingEnemy


func set_visual_surface_contact(local_y: float) -> void:
	if visual == null:
		return
	visual.position.y = local_y - get_visual_foot_baseline()


func get_visual_surface_contact_local_y() -> float:
	if visual == null:
		return 0.0
	return visual.position.y + get_visual_foot_baseline()


func get_visual_foot_baseline() -> float:
	if archetype == null:
		return 0.0
	var radius: float = archetype.body_radius
	match archetype.archetype_id:
		&"basic":
			return radius + 4.0
		&"runner":
			return radius + 8.0
		&"brute":
			return radius * 1.8 * 1.04 * 0.75
		&"rope_saboteur":
			return maxf(9.0, 2.0 + radius * 0.8)
		&"flyer":
			return 0.0
		_:
			return radius + 5.0


func attach_special_behavior(
	component: EnemyBehaviorComponent,
	game_flow: GameFlowController
) -> void:
	super.attach_special_behavior(component, game_flow)
	if (
		visual != null
		and component.target_domain != EnemyBehaviorComponent.TargetDomain.GROUND
	):
		visual.position.y = 0.0
