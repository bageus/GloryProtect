extends SceneTree


class FakeGeometry:
	extends AnchorGeometry

	var current_orb_id: int = 0

	func get_current_installation_orb_id() -> int:
		return current_orb_id

	func get_ground_point_for_orb(orb_id: int, anchor_id: int) -> Vector2:
		return Vector2(float(anchor_id) * 8.0, float(orb_id) * 4.0)


class FakeOperationQueue:
	extends AnchorOperationQueue

	var store: AnchorRuntimeStore
	var requested := PackedInt32Array()

	func configure_fake(runtime_store: AnchorRuntimeStore) -> void:
		store = runtime_store

	func request_install(
		anchor_id: int,
		orb_id: int,
		ground_point: Vector2
	) -> void:
		requested.append(anchor_id)
		store.set_install_target(anchor_id, orb_id, ground_point)
		store.set_queued(anchor_id)


class AlwaysTensionedConstraints:
	extends AnchorConstraintProvider

	func is_anchor_tensioned_in_wind(_anchor_id: int) -> bool:
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_one_winch_per_side_until_mega()
	_assert_overload_threshold_changes_with_reinforced_upgrade()
	_assert_upgrade_runtime_and_catalog_contract()
	print("Anchor reinforced winch scenarios passed")
	quit()


func _assert_one_winch_per_side_until_mega() -> void:
	var store := AnchorRuntimeStore.new()
	store.initialize()
	var geometry := FakeGeometry.new()
	var operations := FakeOperationQueue.new()
	operations.configure_fake(store)
	var commands := AnchorCommandController.new()
	commands.configure(
		store,
		geometry,
		operations,
		func(_side: int) -> bool: return true
	)
	var rejected: Array[StringName] = []
	commands.command_rejected.connect(
		func(_anchor_id: int, reason: StringName) -> void:
			rejected.append(reason)
	)

	commands.toggle(0)
	_assert_requested_anchor_ids(operations.requested, [0])
	assert(store.get_anchor(0).state == AnchorRuntime.State.QUEUED)

	commands.toggle(1)
	_assert_requested_anchor_ids(operations.requested, [0])
	assert(rejected[rejected.size() - 1] == &"second_winch_locked")
	assert(store.get_anchor(1).state == AnchorRuntime.State.STOWED)

	commands.toggle(2)
	_assert_requested_anchor_ids(operations.requested, [0, 2])
	assert(store.get_anchor(2).state == AnchorRuntime.State.QUEUED)

	commands.set_second_winch_pair_enabled(true)
	commands.toggle(1)
	_assert_requested_anchor_ids(operations.requested, [0, 2, 1])
	assert(store.get_anchor(1).state == AnchorRuntime.State.QUEUED)


func _assert_overload_threshold_changes_with_reinforced_upgrade() -> void:
	var wind := WindSystem.new()
	wind.direction = 1
	wind.strength_level = 2
	var balance := AnchorBalance.new()
	balance.overload_duration = 1.0

	var base_store := _make_store_with_attached_anchor()
	var base_overload := AnchorOverloadController.new()
	base_overload.configure(
		base_store,
		AlwaysTensionedConstraints.new(),
		balance,
		wind
	)
	base_overload.tick(0.1)
	assert(base_overload.get_wind_strength_threshold() == 2)
	assert(base_store.get_anchor(0).state == AnchorRuntime.State.OVERLOADED)

	var reinforced_store := _make_store_with_attached_anchor()
	var reinforced_overload := AnchorOverloadController.new()
	reinforced_overload.configure(
		reinforced_store,
		AlwaysTensionedConstraints.new(),
		balance,
		wind
	)
	reinforced_overload.set_wind_strength_threshold(3)
	reinforced_overload.tick(0.1)
	assert(reinforced_store.get_anchor(0).state == AnchorRuntime.State.ATTACHED)

	wind.strength_level = 3
	reinforced_overload.tick(0.1)
	assert(reinforced_store.get_anchor(0).state == AnchorRuntime.State.OVERLOADED)


func _assert_upgrade_runtime_and_catalog_contract() -> void:
	var runtime := CombatAnchorUpgradeRuntime.new()
	var reinforced := _make_flag_effect(
		CombatAnchorUpgradeRuntime.REINFORCED_WIND_THRESHOLD
	)
	var mega := _make_flag_effect(CombatAnchorUpgradeRuntime.SECOND_WINCH_PAIR)
	assert(runtime.can_apply_effect(reinforced))
	assert(runtime.apply_flag(CombatAnchorUpgradeRuntime.REINFORCED_WIND_THRESHOLD))
	assert(runtime.reinforced_wind_threshold_enabled)
	assert(runtime.can_apply_effect(mega))
	assert(runtime.apply_flag(CombatAnchorUpgradeRuntime.SECOND_WINCH_PAIR))
	assert(runtime.second_winch_pair_enabled)

	var catalog: UpgradeCatalog = load(
		"res://resources/upgrades/combat_anchor_upgrade_catalog.tres"
	)
	var reinforced_card: UpgradeDefinition = catalog.get_definition(
		&"anchor_overload_basic"
	)
	var mega_card: UpgradeDefinition = catalog.get_definition(
		&"anchor_overload_advanced"
	)
	assert(reinforced_card.title == "Усиленное закрепление")
	assert(reinforced_card.effect.target_id == CombatAnchorUpgradeRuntime.REINFORCED_WIND_THRESHOLD)
	assert(mega_card.title == "Мега закрепление")
	assert(mega_card.effect.target_id == CombatAnchorUpgradeRuntime.SECOND_WINCH_PAIR)
	assert(mega_card.prerequisite_card_ids.size() == 1)
	assert(mega_card.prerequisite_card_ids[0] == &"anchor_overload_basic")


func _assert_requested_anchor_ids(
	actual: PackedInt32Array,
	expected: Array[int]
) -> void:
	assert(actual.size() == expected.size())
	for index: int in range(expected.size()):
		assert(actual[index] == expected[index])


func _make_store_with_attached_anchor() -> AnchorRuntimeStore:
	var store := AnchorRuntimeStore.new()
	store.initialize()
	store.set_install_target(0, 0, Vector2.ZERO)
	store.attach(0, 0.0)
	return store


func _make_flag_effect(target_id: StringName) -> UpgradeEffectDefinition:
	var effect := UpgradeEffectDefinition.new()
	effect.effect_type = UpgradeEffectDefinition.EffectType.DOMAIN_FLAG
	effect.target_id = target_id
	return effect
