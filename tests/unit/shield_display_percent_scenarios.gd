extends SceneTree

const SHIELD_BALANCE: ShieldBalance = preload(
	"res://resources/balance/shield_balance.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	var shield := ShieldSystem.new()
	shield.balance = SHIELD_BALANCE
	root.add_child(shield)
	await process_frame
	assert(shield.get_display_health_percent(0) == 100.0)
	shield.set_health(0, -1000.0)
	assert(shield.get_display_health_percent(0) == 0.0)
	assert(shield.get_display_health_percent(-1) == 0.0)
	print("Shield display percent scenarios passed")
	quit()
