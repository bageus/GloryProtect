extends SceneTree

const ECONOMY_BALANCE: EconomyBalance = preload(
	"res://resources/balance/economy_balance.tres"
)


func _init() -> void:
	call_deferred("_run_scenario")


func _run_scenario() -> void:
	assert(ECONOMY_BALANCE.is_rewarded_boarding_reason(
		&"shooter_anchor_knockdown"
	))
	print("Shooter reward reason scenario passed")
	quit()
