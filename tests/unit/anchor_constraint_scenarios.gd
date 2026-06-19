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
	var anchor_balance: AnchorBalance = context.anchor_balance

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

	overload.tick(anchor_balance.overload_duration)
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
	var platform_balance := PlatformBalance.new()
	var wind_balance := WindBalance.new()
	var anchor_balance := AnchorBalance.new()

	var platform := PlatformController.new()
	platform.balance = platform_balance
	platform.position = Vector2.ZERO

	var wind := WindSystem.new()
	wind.balance = wind_balance

	var store := AnchorRuntimeStore.new()
	var geometry := AnchorGeometry.new()
	var constraints := AnchorConstraintProvider.new()
	var overload := AnchorOverloadController.new()

	store.initialize()
	geometry.configure(platform, anchor_balance, 0.0, 510.0)
	constraints.configure(store, geometry, anchor_balance, platform, wind)
	overload.configure(store, constraints, anchor_balance, wind)

	return {
		"platform": platform,
		"wind": wind,
		"anchor_balance": anchor_balance,
		"store": store,
		"geometry": geometry,
		"constraints": constraints,
		"overload": overload,
	}
