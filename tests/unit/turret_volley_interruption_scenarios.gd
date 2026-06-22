extends SceneTree


func _init() -> void:
	var system := TurretUpgradeSystem.new()
	var runtime := TurretRuntime.new(1)
	assert(runtime.begin_volley(2))
	runtime.begin_shot(10, 0.0)
	assert(not runtime.finish_shot(0.0))
	assert(runtime.is_volley_active())
	system._cancel_runtime_action(runtime)
	assert(not runtime.is_volley_active())
	assert(runtime.completed_volleys == 0)
	assert(runtime.begin_volley(1))
	print("Turret volley interruption scenarios passed")
	quit()
