class_name BoardingEnemyCatalog
extends Resource

@export var archetypes: Array[BoardingEnemyArchetype] = []


func get_archetype(archetype_id: StringName) -> BoardingEnemyArchetype:
	for archetype: BoardingEnemyArchetype in archetypes:
		if archetype != null and archetype.archetype_id == archetype_id:
			return archetype
	return null


func get_default_archetype(
	allowed_spawn_requirements: Array[int] = []
) -> BoardingEnemyArchetype:
	for archetype: BoardingEnemyArchetype in archetypes:
		if (
			archetype != null
			and archetype.is_valid()
			and _is_requirement_allowed(
				archetype,
				allowed_spawn_requirements
			)
		):
			return archetype
	return null


func choose_archetype(
	rng: RandomNumberGenerator,
	normalized_difficulty: float,
	allowed_spawn_requirements: Array[int] = []
) -> BoardingEnemyArchetype:
	var total_weight: float = 0.0
	for archetype: BoardingEnemyArchetype in archetypes:
		if not _is_selectable(archetype, allowed_spawn_requirements):
			continue
		var weight: float = archetype.get_weight(normalized_difficulty)
		if weight > 0.0:
			total_weight += weight

	if total_weight <= 0.0:
		return get_default_archetype(allowed_spawn_requirements)

	var roll: float = rng.randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for archetype: BoardingEnemyArchetype in archetypes:
		if not _is_selectable(archetype, allowed_spawn_requirements):
			continue
		var weight: float = archetype.get_weight(normalized_difficulty)
		if weight <= 0.0:
			continue
		cumulative += weight
		if roll <= cumulative:
			return archetype
	return get_default_archetype(allowed_spawn_requirements)


func validate() -> bool:
	if archetypes.is_empty():
		return false
	var ids: Dictionary[StringName, bool] = {}
	for archetype: BoardingEnemyArchetype in archetypes:
		if archetype == null or not archetype.is_valid():
			return false
		if ids.has(archetype.archetype_id):
			return false
		ids[archetype.archetype_id] = true
	return true


func _is_selectable(
	archetype: BoardingEnemyArchetype,
	allowed_spawn_requirements: Array[int]
) -> bool:
	return (
		archetype != null
		and archetype.is_valid()
		and _is_requirement_allowed(
			archetype,
			allowed_spawn_requirements
		)
	)


func _is_requirement_allowed(
	archetype: BoardingEnemyArchetype,
	allowed_spawn_requirements: Array[int]
) -> bool:
	return (
		allowed_spawn_requirements.is_empty()
		or allowed_spawn_requirements.has(archetype.spawn_requirement)
	)
