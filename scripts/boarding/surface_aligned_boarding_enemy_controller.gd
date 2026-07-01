class_name SurfaceAlignedBoardingEnemyController
extends BoardingEnemyController

var _ground_visual_contact_y: float = 0.0
var _platform_visual_contact_y: float = 0.0


func configure(
	enemy: BoardingEnemy,
	archetype: BoardingEnemyArchetype,
	balance: BoardingBalance,
	game_flow: GameFlowController,
	platform: PlatformController,
	paths: AnchorPathRegistry,
	crew: CrewManager,
	orbs: GroundOrbRegistry,
	movement_resolver: BoardingMovementResolver,
	jump_planner: BoardingJumpPlanner,
	melee: MeleeAttackComponent
) -> void:
	_ground_visual_contact_y = balance.ground_vertical_offset
	_platform_visual_contact_y = (
		-platform.get_platform_height() * 0.5
		- balance.platform_local_y
	)
	super.configure(
		enemy,
		archetype,
		balance,
		game_flow,
		platform,
		paths,
		crew,
		orbs,
		movement_resolver,
		jump_planner,
		melee
	)


func get_ground_visual_contact_y() -> float:
	return _ground_visual_contact_y


func get_platform_visual_contact_y() -> float:
	return _platform_visual_contact_y


func _set_ground_height() -> void:
	super._set_ground_height()
	_align_visual_contact(_ground_visual_contact_y)


func _update_climbing(delta: float) -> void:
	super._update_climbing(delta)
	if state != State.CLIMBING:
		return
	_align_visual_contact(
		lerpf(
			_ground_visual_contact_y,
			_platform_visual_contact_y,
			_clampf(_climb_progress, 0.0, 1.0)
		)
	)


func _update_world_position_from_platform(
	vertical_offset: float = 0.0
) -> void:
	super._update_world_position_from_platform(vertical_offset)
	_align_visual_contact(_platform_visual_contact_y)


func _align_visual_contact(local_y: float) -> void:
	var aligned_enemy := _enemy as SurfaceAlignedBoardingEnemy
	if aligned_enemy != null:
		aligned_enemy.set_visual_surface_contact(local_y)
