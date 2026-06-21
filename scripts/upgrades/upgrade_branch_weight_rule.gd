class_name UpgradeBranchWeightRule
extends Resource

@export var branch_id: StringName
@export_range(1, 100, 1) var starting_weight: int = 10
@export var related_branch_ids: Array[StringName] = []
@export var opposing_branch_ids: Array[StringName] = []


func is_valid() -> bool:
	if branch_id == &"" or starting_weight <= 0:
		return false
	return not related_branch_ids.has(branch_id) and not opposing_branch_ids.has(branch_id)
