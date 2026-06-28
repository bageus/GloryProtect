extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var timeline: Array = [
		{
			"time_seconds": 60.0,
			"purchase_number": 1,
			"card_id": &"first",
		},
		{
			"time_seconds": 1200.0,
			"purchase_number": 20,
			"card_id": &"twentieth",
		},
	]
	var snapshot := RunStatisticsSnapshot.new(
		1200.0,
		240,
		25,
		20,
		&"test_complete",
		1050,
		1025,
		timeline,
		{&"general": 30, &"turret": 90, &"melee": 180},
		[5, 12]
	)
	assert(snapshot.get_offer_slot_total() == 300)
	assert(is_equal_approx(snapshot.get_offer_share(&"general"), 0.10))
	assert(is_equal_approx(snapshot.get_purchase_time_seconds(20), 1200.0))
	assert(snapshot.get_purchase_time_seconds(21) < 0.0)
	assert(snapshot.get_specialization_purchase_number(0) == 5)
	assert(snapshot.get_specialization_purchase_number(1) == 12)
	assert(snapshot.get_specialization_purchase_number(2) == -1)
	var summary: String = snapshot.get_balance_summary_text()
	assert(summary.contains("survival 20.00 min"))
	assert(summary.contains("coins/min 52.50"))
	assert(summary.contains("purchase #20 20.00 min"))
	assert(summary.contains("specializations 5, 12"))
	assert(summary.contains("general pool 10.00%"))
	print("Run statistics balance summary scenarios passed")
	quit()
