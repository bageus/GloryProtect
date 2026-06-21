class_name AnchorRopeDurability
extends RefCounted

signal durability_changed(
	anchor_id: int,
	current_durability: float,
	maximum_durability: float
)
signal rope_destroyed(anchor_id: int, source: StringName)

var _store: AnchorRuntimeStore
var _balance: AnchorBalance


func configure(store: AnchorRuntimeStore, balance: AnchorBalance) -> void:
	assert(store != null, "AnchorRopeDurability requires AnchorRuntimeStore")
	assert(balance != null, "AnchorRopeDurability requires AnchorBalance")
	assert(
		balance.rope_max_durability > 0.0,
		"Rope maximum durability must be positive"
	)
	_store = store
	_balance = balance
	if not _store.anchor_attached.is_connected(_on_anchor_attached):
		_store.anchor_attached.connect(_on_anchor_attached)
	reset_all()


func reset_all() -> void:
	_assert_configured()
	for anchor: AnchorRuntime in _store.get_all():
		_set_durability(anchor, _balance.rope_max_durability)


func apply_damage(
	anchor_id: int,
	amount: float,
	source: StringName = &"unknown"
) -> bool:
	_assert_configured()
	if amount <= 0.0 or not _store.is_valid(anchor_id):
		return false

	var anchor: AnchorRuntime = _store.get_anchor(anchor_id)
	if not anchor.is_holding() or anchor.rope_durability <= 0.0:
		return false

	var next_durability: float = maxf(anchor.rope_durability - amount, 0.0)
	_set_durability(anchor, next_durability)
	if is_zero_approx(next_durability):
		rope_destroyed.emit(anchor_id, source)
	return true


func restore_full(anchor_id: int) -> bool:
	_assert_configured()
	if not _store.is_valid(anchor_id):
		return false
	_set_durability(
		_store.get_anchor(anchor_id),
		_balance.rope_max_durability
	)
	return true


func get_snapshot(anchor_id: int) -> AnchorRopeSnapshot:
	_assert_configured()
	if not _store.is_valid(anchor_id):
		return null
	var anchor: AnchorRuntime = _store.get_anchor(anchor_id)
	return AnchorRopeSnapshot.new(
		anchor.anchor_id,
		anchor.rope_durability,
		_balance.rope_max_durability
	)


func get_all_snapshots() -> Array[AnchorRopeSnapshot]:
	_assert_configured()
	var snapshots: Array[AnchorRopeSnapshot] = []
	for anchor: AnchorRuntime in _store.get_all():
		snapshots.append(
			AnchorRopeSnapshot.new(
				anchor.anchor_id,
				anchor.rope_durability,
				_balance.rope_max_durability
			)
		)
	return snapshots


func _on_anchor_attached(anchor_id: int) -> void:
	restore_full(anchor_id)


func _set_durability(anchor: AnchorRuntime, value: float) -> void:
	var clamped_value: float = clampf(
		value,
		0.0,
		_balance.rope_max_durability
	)
	if is_equal_approx(anchor.rope_durability, clamped_value):
		return
	anchor.rope_durability = clamped_value
	durability_changed.emit(
		anchor.anchor_id,
		anchor.rope_durability,
		_balance.rope_max_durability
	)


func _assert_configured() -> void:
	assert(_store != null, "AnchorRopeDurability is not configured")
	assert(_balance != null, "AnchorRopeDurability is not configured")
