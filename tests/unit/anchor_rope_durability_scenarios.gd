extends SceneTree

var _destroyed_ids: Array[int] = []
var _destroyed_sources: Array[StringName] = []


func _init() -> void:
	_test_independent_durability_and_snapshots()
	_test_invalid_damage_is_rejected()
	_test_damage_eligibility_by_anchor_state()
	_test_destroyed_event_is_emitted_once()
	_test_new_attachment_restores_full_durability()
	_test_reset_restores_all_anchors()
	print("Anchor rope durability scenarios passed")
	quit()


func _test_independent_durability_and_snapshots() -> void:
	var context: Dictionary = _create_context(60.0)
	var store: AnchorRuntimeStore = context.store
	var durability: AnchorRopeDurability = context.durability

	assert(not durability.apply_damage(0, 10.0, &"stowed"))
	store.attach(0, 0.0)
	assert(durability.apply_damage(0, 15.0, &"test"))

	var damaged: AnchorRopeSnapshot = durability.get_snapshot(0)
	var untouched: AnchorRopeSnapshot = durability.get_snapshot(1)
	assert(is_equal_approx(damaged.current_durability, 45.0))
	assert(is_equal_approx(damaged.maximum_durability, 60.0))
	assert(is_equal_approx(damaged.durability_ratio, 0.75))
	assert(not damaged.is_destroyed)
	assert(is_equal_approx(untouched.current_durability, 60.0))
	assert(durability.get_all_snapshots().size() == 4)


func _test_invalid_damage_is_rejected() -> void:
	var context: Dictionary = _create_context(50.0)
	var store: AnchorRuntimeStore = context.store
	var durability: AnchorRopeDurability = context.durability

	store.attach(1, 0.0)
	assert(not durability.apply_damage(1, 0.0, &"zero"))
	assert(not durability.apply_damage(1, -10.0, &"negative"))
	assert(not durability.apply_damage(99, 10.0, &"invalid_anchor"))
	assert(is_equal_approx(
		durability.get_snapshot(1).current_durability,
		50.0
	))
	assert(durability.get_snapshot(99) == null)


func _test_damage_eligibility_by_anchor_state() -> void:
	var context: Dictionary = _create_context(50.0)
	var store: AnchorRuntimeStore = context.store
	var durability: AnchorRopeDurability = context.durability

	assert(not durability.apply_damage(0, 10.0, &"stowed"))
	store.set_queued(0)
	assert(not durability.apply_damage(0, 10.0, &"queued"))
	store.begin_install(0)
	assert(not durability.apply_damage(0, 10.0, &"installing"))

	store.attach(0, 0.0)
	assert(durability.apply_damage(0, 10.0, &"attached"))
	assert(is_equal_approx(
		durability.get_snapshot(0).current_durability,
		40.0
	))

	store.begin_overload(0)
	assert(durability.apply_damage(0, 10.0, &"overloaded"))
	assert(is_equal_approx(
		durability.get_snapshot(0).current_durability,
		30.0
	))

	store.begin_return(0)
	assert(not durability.apply_damage(0, 10.0, &"returning"))
	assert(is_equal_approx(
		durability.get_snapshot(0).current_durability,
		30.0
	))


func _test_destroyed_event_is_emitted_once() -> void:
	_destroyed_ids.clear()
	_destroyed_sources.clear()
	var context: Dictionary = _create_context(40.0)
	var store: AnchorRuntimeStore = context.store
	var durability: AnchorRopeDurability = context.durability
	durability.rope_destroyed.connect(_on_rope_destroyed)

	store.attach(2, 0.0)
	assert(durability.apply_damage(2, 100.0, &"test_destroy"))
	assert(not durability.apply_damage(2, 1.0, &"duplicate"))
	assert(_destroyed_ids == [2])
	assert(_destroyed_sources == [&"test_destroy"])
	assert(durability.get_snapshot(2).is_destroyed)


func _test_new_attachment_restores_full_durability() -> void:
	var context: Dictionary = _create_context(75.0)
	var store: AnchorRuntimeStore = context.store
	var durability: AnchorRopeDurability = context.durability

	store.attach(3, 0.0)
	durability.apply_damage(3, 30.0, &"test")
	assert(is_equal_approx(
		durability.get_snapshot(3).current_durability,
		45.0
	))

	store.set_stowed(3)
	store.attach(3, 10.0)
	assert(is_equal_approx(
		durability.get_snapshot(3).current_durability,
		75.0
	))


func _test_reset_restores_all_anchors() -> void:
	var context: Dictionary = _create_context(90.0)
	var store: AnchorRuntimeStore = context.store
	var durability: AnchorRopeDurability = context.durability

	store.attach(0, 0.0)
	store.attach(2, 0.0)
	durability.apply_damage(0, 25.0, &"test")
	durability.apply_damage(2, 80.0, &"test")
	durability.reset_all()

	for snapshot: AnchorRopeSnapshot in durability.get_all_snapshots():
		assert(is_equal_approx(snapshot.current_durability, 90.0))
		assert(not snapshot.is_destroyed)


func _create_context(maximum_durability: float) -> Dictionary:
	var balance := AnchorBalance.new()
	balance.rope_max_durability = maximum_durability
	var store := AnchorRuntimeStore.new()
	var durability := AnchorRopeDurability.new()
	store.initialize()
	durability.configure(store, balance)
	return {
		"balance": balance,
		"store": store,
		"durability": durability,
	}


func _on_rope_destroyed(anchor_id: int, source: StringName) -> void:
	_destroyed_ids.append(anchor_id)
	_destroyed_sources.append(source)
