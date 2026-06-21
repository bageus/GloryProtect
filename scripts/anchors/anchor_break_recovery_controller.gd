class_name AnchorBreakRecoveryController
extends RefCounted

signal recovery_started(
	anchor_id: int,
	source: StringName,
	removed_enemy_count: int
)

var _store: AnchorRuntimeStore
var _operations: AnchorOperationQueue
var _constraints: AnchorConstraintProvider
var _enemies: BoardingEnemyRegistry


func configure(
	store: AnchorRuntimeStore,
	operations: AnchorOperationQueue,
	constraints: AnchorConstraintProvider,
	enemies: BoardingEnemyRegistry
) -> void:
	assert(store != null)
	assert(operations != null)
	assert(constraints != null)
	assert(enemies != null)
	_store = store
	_operations = operations
	_constraints = constraints
	_enemies = enemies


func recover(anchor_id: int, source: StringName) -> bool:
	if _store == null or not _store.is_valid(anchor_id):
		return false

	var anchor: AnchorRuntime = _store.get_anchor(anchor_id)
	if anchor.state not in [
		AnchorRuntime.State.ATTACHED,
		AnchorRuntime.State.OVERLOADED,
		AnchorRuntime.State.RETURNING,
	]:
		return false

	_operations.cancel_anchor(anchor_id)
	if anchor.is_holding():
		_store.begin_return(anchor_id)

	var removed_enemy_count: int = _enemies.kill_climbing_on_anchor(
		anchor_id,
		&"anchor_path_closed"
	)
	_constraints.update_full_fix_state()
	recovery_started.emit(anchor_id, source, removed_enemy_count)
	return true
