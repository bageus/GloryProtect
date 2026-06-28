class_name UpgradeBranchWeightRule
extends Resource

@export var branch_id: StringName
@export_range(1, 100, 1) var starting_weight: int = 10
@export var related_branch_ids: Array[StringName] = []
@export var opposing_branch_ids: Array[StringName] = []


func is_valid() -> bool:
	if branch_id == &"" or starting_weight <= 0:
		return false
	if related_branch_ids.has(branch_id) or opposing_branch_ids.has(branch_id):
		return false
	var seen: Dictionary[StringName, bool] = {}
	for related_id: StringName in related_branch_ids:
		if related_id == &"" or seen.has(related_id):
			return false
		seen[related_id] = true
	for opposing_id: StringName in opposing_branch_ids:
		if opposing_id == &"" or seen.has(opposing_id):
			return false
		seen[opposing_id] = true
	return true
