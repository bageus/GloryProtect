extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var balance := BuildableBalance.new()
	assert(balance.get_medical_cell_indices() == [2, 3, 4, 5, 6, 7, 12, 13, 14, 15])
	assert(balance.get_medical_footprint_cells(2) == [2])
	assert(balance.get_medical_footprint_cells(7) == [7])
	assert(balance.get_medical_footprint_cells(12) == [12])
	assert(balance.get_medical_footprint_cells(8).is_empty())
	assert(not balance.is_reserved_cell(6))
	assert(not balance.is_reserved_cell(7))
	assert(balance.is_reserved_cell(8))

	var polished_turret := TurretVisualControllerPolished.new()
	assert(is_equal_approx(polished_turret.get_effective_asset_scale(), 0.095))
	assert(is_equal_approx(
		polished_turret.get_effective_asset_scale() / 0.19,
		0.5
	))
	print("Buildable visual scale scenarios passed")
	quit()
