class_name UpgradeDrawGenerator
extends RefCounted

const GENERAL_POOL_ID: StringName = &"general"

var _balance: UpgradeDrawBalance
var _catalog: UpgradeCatalog
var _runtime: UpgradeRuntime
var _rng := RandomNumberGenerator.new()
var _branch_weights: Dictionary[StringName, int] = {}


func configure(
	balance: UpgradeDrawBalance,
	catalog: UpgradeCatalog,
	runtime: UpgradeRuntime,
	seed: int = 0
) -> void:
	assert(balance != null and balance.is_valid())
	assert(catalog != null and catalog.is_valid())
	assert(runtime != null)
	_balance = balance
	_catalog = catalog
	_runtime = runtime
	if seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed
	reset_for_run()


func reset_for_run() -> void:
	_branch_weights.clear()
	if _balance == null:
		return
	for rule: UpgradeBranchWeightRule in _balance.branch_rules:
		_branch_weights[rule.branch_id] = rule.starting_weight


func set_seed(seed: int) -> void:
	_rng.seed = seed


func get_branch_weight(branch_id: StringName) -> int:
	return int(_branch_weights.get(branch_id, 0))


func generate_offer() -> Array[UpgradeDefinition]:
	var pools: Dictionary[StringName, Array] = _build_pools()
	var offer: Array[UpgradeDefinition] = []
	while offer.size() < _balance.cards_per_offer:
		var pool_id: StringName = _choose_pool_id(pools)
		if pool_id == &"":
			break
		var pool: Array = pools[pool_id]
		if pool.is_empty():
			pools.erase(pool_id)
			continue
		var card_index: int = _rng.randi_range(0, pool.size() - 1)
		var definition: UpgradeDefinition = pool[card_index]
		pool.remove_at(card_index)
		pools[pool_id] = pool
		offer.append(definition)
	return offer


func apply_selected_card(definition: UpgradeDefinition) -> void:
	if definition == null:
		return
	if definition.card_type in [
		UpgradeDefinition.CardType.UNLOCK,
		UpgradeDefinition.CardType.GENERAL,
	]:
		return
	var rule: UpgradeBranchWeightRule = _balance.get_rule(definition.branch_id)
	if rule == null:
		return
	_change_weight(definition.branch_id, _balance.selected_branch_bonus)
	for branch_id: StringName in rule.related_branch_ids:
		_change_weight(branch_id, _balance.related_branch_bonus)
	for branch_id: StringName in rule.opposing_branch_ids:
		_change_weight(branch_id, -_balance.opposing_branch_penalty)


func get_unavailability_reason(definition: UpgradeDefinition) -> StringName:
	if definition == null or not definition.is_valid():
		return &"invalid_definition"
	if definition.card_type == UpgradeDefinition.CardType.SPECIALIZATION:
		return &"specialization_event_only"
	if not _catalog.is_available(definition, _runtime):
		return _get_catalog_reason(definition)
	if (
		definition.card_type == UpgradeDefinition.CardType.INDIVIDUAL
		and not _has_completed_line(definition.branch_id)
	):
		return &"branch_line_not_completed"
	return &""


func _get_catalog_reason(definition: UpgradeDefinition) -> StringName:
	if _runtime.get_repeat_count(definition.card_id) >= definition.repeat_limit:
		return &"repeat_limit_reached"
	if _runtime.is_specialization_closed(definition.card_id):
		return &"specialization_closed"
	for prerequisite_id: StringName in definition.prerequisite_card_ids:
		if not _runtime.has_card(prerequisite_id):
			return &"missing_prerequisite"
	if definition.required_repeat_count > 0:
		return &"missing_repeat_count"
	if definition.required_specialization_id != &"":
		return &"wrong_specialization"
	if definition.required_specialized_branch_id != &"":
		return &"branch_not_specialized"
	if definition.required_completed_branch_id != &"":
		return &"branch_line_not_completed"
	return &"unavailable"


func _build_pools() -> Dictionary[StringName, Array]:
	var pools: Dictionary[StringName, Array] = {}
	for definition: UpgradeDefinition in _catalog.definitions:
		if get_unavailability_reason(definition) != &"":
			continue
		var pool_id: StringName = (
			GENERAL_POOL_ID
			if definition.card_type == UpgradeDefinition.CardType.GENERAL
			else definition.branch_id
		)
		var pool: Array = pools.get(pool_id, [])
		pool.append(definition)
		pools[pool_id] = pool
	return pools


func _choose_pool_id(pools: Dictionary[StringName, Array]) -> StringName:
	var ids: Array[StringName] = []
	var total_weight: int = 0
	for raw_id: Variant in pools.keys():
		var pool_id: StringName = raw_id
		var pool: Array = pools[pool_id]
		if pool.is_empty():
			continue
		var weight: int = (
			_balance.general_pool_weight
			if pool_id == GENERAL_POOL_ID
			else get_branch_weight(pool_id)
		)
		if weight <= 0:
			continue
		ids.append(pool_id)
		total_weight += weight
	if total_weight <= 0:
		return &""
	var roll: int = _rng.randi_range(1, total_weight)
	var cursor: int = 0
	for pool_id: StringName in ids:
		cursor += (
			_balance.general_pool_weight
			if pool_id == GENERAL_POOL_ID
			else get_branch_weight(pool_id)
		)
		if roll <= cursor:
			return pool_id
	return &""


func _has_completed_line(branch_id: StringName) -> bool:
	for definition: UpgradeDefinition in _catalog.definitions:
		if definition.branch_id != branch_id:
			continue
		if definition.card_type != UpgradeDefinition.CardType.ADVANCED:
			continue
		if _runtime.has_card(definition.card_id):
			return true
	return false


func _change_weight(branch_id: StringName, delta: int) -> void:
	if not _branch_weights.has(branch_id):
		return
	_branch_weights[branch_id] = maxi(
		_balance.minimum_branch_weight,
		get_branch_weight(branch_id) + delta
	)
