class_name EnemyBehaviorContext
extends RefCounted

var boarding_balance: BoardingBalance
var platform: PlatformController
var paths: AnchorPathRegistry
var orbs: GroundOrbRegistry
var movement_resolver: BoardingMovementResolver
var anchors: AnchorSystem


func _init(
	new_boarding_balance: BoardingBalance,
	new_platform: PlatformController,
	new_paths: AnchorPathRegistry,
	new_orbs: GroundOrbRegistry,
	new_movement_resolver: BoardingMovementResolver,
	new_anchors: AnchorSystem
) -> void:
	assert(new_boarding_balance != null)
	assert(new_platform != null)
	assert(new_paths != null)
	assert(new_orbs != null)
	assert(new_movement_resolver != null)
	assert(new_anchors != null)
	boarding_balance = new_boarding_balance
	platform = new_platform
	paths = new_paths
	orbs = new_orbs
	movement_resolver = new_movement_resolver
	anchors = new_anchors
