extends SceneTree

var _expected_source: Node
var _source_seen: bool = false


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	var target := HealthComponent.new()
	var melee := MeleeAttackComponent.new()
	_expected_source = Node.new()
	root.add_child(target)
	root.add_child(melee)
	root.add_child(_expected_source)
	target.configure(2)
	target.damage_received.connect(_on_damage_received)
	melee.configure(1, 0.1, 0.2, _expected_source)
	assert(melee.try_start(target))
	melee.tick(0.1)
	assert(_source_seen)
	assert(target.current_health == 1)
	print("Melee damage source scenarios passed")
	quit()


func _on_damage_received(
	_requested_amount: int,
	_health_damage: int,
	source_id: StringName,
	source_node: Node
) -> void:
	assert(source_id == &"melee")
	assert(source_node == _expected_source)
	_source_seen = true
