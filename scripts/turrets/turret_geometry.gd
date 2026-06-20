class_name TurretGeometry
extends RefCounted


static func get_local_pivot(
	snapshot: BuildableSnapshot,
	balance: BuildableBalance
) -> Vector2:
	return Vector2(
		snapshot.local_x,
		balance.turret_bottom_y - balance.turret_height * 0.58
	)


static func get_world_pivot(
	platform: PlatformController,
	snapshot: BuildableSnapshot,
	balance: BuildableBalance
) -> Vector2:
	return platform.to_global(get_local_pivot(snapshot, balance))


static func get_default_aim_direction() -> Vector2:
	return Vector2.RIGHT
