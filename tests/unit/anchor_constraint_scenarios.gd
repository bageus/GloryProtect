extends SceneTree


func _init() -> void:
	_test_right_anchor_breaks_when_wind_pulls_right()
	_test_right_anchor_breaks_when_wind_pulls_left()
	_test_two_right_anchors_cancel_overload()
	print("Anchor constraint scenarios passed")
	quit()


func _test_right_anchor_breaks_when_wind_pulls_right() -> void:
	var context := _create_context()
	var store: AnchorRuntimeStore = context.store
	var platform: PlatformController = context.platform
	var wind: WindSystem = context.wind
	var constraints: AnchorConstraintProvider = context.constraints
	var overload: AnchorOverloadController = context.overload
	var balance: AnchorBalance = context.balance

	store.attach(3, platform.position.x)
	var maximum_x := constraints.get_maximum_platform_x()
	assert(maximum_x < INF, "Right anchor must have a finite right boundary")
	assert(maximum_x > platform.position.x)

	platform.position.x = maximum_x
	wind.set_debug_state(1, 3)
	overload.tick(0.01)
	assert(
		store.get_anchor(3).state == AnchorRuntime.State.OVERLOADED,
		"Right anchor must overload when strong wind pulls right at rope limit"
	)

	overload.tick(balance.overload_duration)
	assert(
		store.get_anchor(3).state == AnchorRuntime.State.RETURNING,
		"Overloaded right anchor must break and start returning"
	)


func _test_right_anchor_breaks_when_wind_pulls_left() -> void:
	var context := _create_context()
	var store: AnchorRuntimeStore = context.store
	var platform: PlatformController = context.platform
	var wind: WindSystem = context.wind
	var overload: AnchorOverloadController = context.overload

	store.attach(3, platform.position.x)
	wind.set_debug_state(-1, 3)
	overload.tick(0.01)
	assert(
		store.get_anchor(3).state == AnchorRuntime.State.OVERLOADED,
		"Right anchor must overload immediately when strong wind pulls left"
	)


func _test_two_right_anchors_cancel_overload() -> void:
	var context := _create_context()
	var store: AnchorRuntimeStore = context.store
	var platform: PlatformController = context.platform
	var wind: WindSystem = context.wind
	var constraints: AnchorConstraintProvider = context.constraints
	var overload: AnchorOverloadController = context.overload

	store.attach(2, platform.position.x)
	store.attach(3, platform.position.x)
	platform.position.x = constraints.get_maximum_platform_x()
	wind.set_debug_state(1, 3)
	overload.tick(1.0)

	assert(store.get_anchor(2).state == AnchorRuntime.State.ATTACHED)
	assert(store.get_anchor(3).state == AnchorRuntime.State.ATTACHED)


func _create_context() -> Dictionary:
	var platform := PlatformController.new()
	platform.position = Vector2.ZERO
	platform.cell_count = 18
	platform.cell_width = 40.0
	platform.platform_height = 58.0

	var wind := WindSystem.new()
	var balance := AnchorBalance.new()
	var store := AnchorRuntimeStore.new()
	var geometry := AnchorGeometry.new()
	var constraints := AnchorConstraintProvider.new()
	var overload := AnchorOverloadController.new()

	store.initialize()
	geometry.configure(platform, balance, 0.0, 510.0)
	constraints.configure(store, geometry, balance, platform, wind)
	overload.configure(store, constraints, balance, wind)

	return {
		"platform": platform,
		"wind": wind,
		"balance": balance,
		"store": store,
		"geometry": geometry,
		"constraints": constraints,
		"overload": overload,
	}
