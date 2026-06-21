class_name UpgradeDrawBalance
extends Resource

@export_range(1, 8, 1) var cards_per_offer: int = 3
@export_range(1, 100, 1) var general_pool_weight: int = 10
@export_range(0, 20, 1) var selected_branch_bonus: int = 3
@export_range(0, 20, 1) var related_branch_bonus: int = 1
@export_range(0, 20, 1) var opposing_branch_penalty: int = 1
@export_range(1, 100, 1) var minimum_branch_weight: int = 2
@export var branch_rules: Array[UpgradeBranchWeightRule] = []


func is_valid() -> bool:
	if cards_per_offer <= 0 or general_pool_weight <= 0:
		return false
	var seen: Dictionary[StringName, bool] = {}
	for rule: UpgradeBranchWeightRule in branch_rules:
		if rule == null or not rule.is_valid() or seen.has(rule.branch_id):
			return false
		seen[rule.branch_id] = true
	return not branch_rules.is_empty()


func get_rule(branch_id: StringName) -> UpgradeBranchWeightRule:
	for rule: UpgradeBranchWeightRule in branch_rules:
		if rule.branch_id == branch_id:
			return rule
	return null
