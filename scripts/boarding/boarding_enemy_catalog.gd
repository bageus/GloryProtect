class_name BoardingEnemyCatalog
extends Resource

@export var archetypes: Array[BoardingEnemyArchetype] = []


func get_archetype(archetype_id: StringName) -> BoardingEnemyArchetype:
	for archetype: BoardingEnemyArchetype in archetypes:
		if archetype != null and archetype.archetype_id == archetype_id:
			return archetype
	return null


func get_default_archetype() -> BoardingEnemyArchetype:
	for archetype: BoardingEnemyArchetype in archetypes:
		if archetype != null and archetype.is_valid():
			return archetype
	return null


func choose_archetype(
	rng: RandomNumberGenerator,
	normalized_difficulty: float
) -> BoardingEnemyArchetype:
	var total_weight: float = 0.0
	for archetype: BoardingEnemyArchetype in archetypes:
		if archetype == null or not archetype.is_valid():
			continue
		total_weight += archetype.get_weight(normalized_difficulty)

	if total_weight <= 0.0:
		return get_default_archetype()

	var roll: float = rng.randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for archetype: BoardingEnemyArchetype in archetypes:
		if archetype == null or not archetype.is_valid():
			continue
		cumulative += archetype.get_weight(normalized_difficulty)
		if roll <= cumulative:
			return archetype
	return get_default_archetype()


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
