class_name UpgradeDrawBalance
extends Resource

@export_range(1, 8, 1) var cards_per_offer: int = 3
@export_range(1, 100, 1) var general_pool_weight: int = 10
@export_range(0.0, 0.5, 0.01) var minimum_general_pool_share: float = 0.10
@export_range(0, 20, 1) var selected_branch_bonus: int = 3
@export_range(0, 20, 1) var related_branch_bonus: int = 1
@export_range(0, 20, 1) var opposing_branch_penalty: int = 1
@export_range(1, 100, 1) var minimum_branch_weight: int = 2
@export var branch_rules: Array[UpgradeBranchWeightRule] = []


func is_valid() -> bool:
	if cards_per_offer <= 0 or general_pool_weight <= 0:
		return false
	if minimum_general_pool_share < 0.0 or minimum_general_pool_share >= 1.0:
		return false
	if branch_rules.is_empty():
		return false
	var rules_by_id: Dictionary[StringName, UpgradeBranchWeightRule] = {}
	var related_count: int = -1
	var opposing_count: int = -1
	for rule: UpgradeBranchWeightRule in branch_rules:
		if rule == null or not rule.is_valid() or rules_by_id.has(rule.branch_id):
			return false
		if related_count < 0:
			related_count = rule.related_branch_ids.size()
		if opposing_count < 0:
			opposing_count = rule.opposing_branch_ids.size()
		if rule.related_branch_ids.size() != related_count:
			return false
		if rule.opposing_branch_ids.size() != opposing_count:
			return false
		rules_by_id[rule.branch_id] = rule
	for rule: UpgradeBranchWeightRule in branch_rules:
		for related_id: StringName in rule.related_branch_ids:
			var related_rule: UpgradeBranchWeightRule = rules_by_id.get(related_id)
			if related_rule == null or not related_rule.related_branch_ids.has(rule.branch_id):
				return false
		for opposing_id: StringName in rule.opposing_branch_ids:
			var opposing_rule: UpgradeBranchWeightRule = rules_by_id.get(opposing_id)
			if opposing_rule == null or not opposing_rule.opposing_branch_ids.has(rule.branch_id):
				return false
	return true


func get_general_pool_weight(available_branch_weight: int) -> int:
	var base_weight: int = maxi(1, general_pool_weight)
	if minimum_general_pool_share <= 0.0 or available_branch_weight <= 0:
		return base_weight
	var required_weight: int = ceili(
		float(available_branch_weight)
		* minimum_general_pool_share
		/ (1.0 - minimum_general_pool_share)
	)
	return maxi(base_weight, required_weight)


func get_rule(branch_id: StringName) -> UpgradeBranchWeightRule:
	for rule: UpgradeBranchWeightRule in branch_rules:
		if rule.branch_id == branch_id:
			return rule
	return null
