extends SceneTree

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/common_repeatable_upgrade_catalog.tres"
)


func _init() -> void:
	call_deferred("_run_scenarios")


func _run_scenarios() -> void:
	_test_type_and_branch_names()
	_test_repeat_progress()
	_test_requirements()
	_test_specialization_warning()
	_test_diagnostics()
	print("Upgrade card formatter scenarios passed")
	quit()


func _test_type_and_branch_names() -> void:
	assert(
		UpgradeCardFormatter.get_type_name(
			UpgradeDefinition.CardType.GENERAL
		) == "ОБЩАЯ"
	)
	assert(UpgradeCardFormatter.get_branch_name(&"turret") == "Турели")
	assert(UpgradeCardFormatter.get_branch_name(&"") == "Общий пул")


func _test_repeat_progress() -> void:
	var runtime := UpgradeRuntime.new()
	var definition: UpgradeDefinition = CATALOG.get_definition(
		&"common_add_defender"
	)
	assert(
		UpgradeCardFormatter.get_repeat_text(definition, runtime)
		== "Получено: 0/5"
	)
	assert(runtime.record_card(definition))
	assert(runtime.record_card(definition))
	assert(
		UpgradeCardFormatter.get_repeat_text(definition, runtime)
		== "Получено: 2/5"
	)


func _test_requirements() -> void:
	var runtime := UpgradeRuntime.new()
	var definition: UpgradeDefinition = CATALOG.get_definition(
		&"common_move_speed_power"
	)
	var before: String = UpgradeCardFormatter.get_requirements_text(
		definition,
		runtime
	)
	assert(before.contains("○"))
	assert(runtime.record_card(CATALOG.get_definition(&"common_move_speed")))
	var after: String = UpgradeCardFormatter.get_requirements_text(
		definition,
		runtime
	)
	assert(after.contains("✓"))


func _test_specialization_warning() -> void:
	var definition: UpgradeDefinition = CATALOG.get_definition(
		&"turret_specialization_heavy"
	)
	var warning: String = UpgradeCardFormatter.get_specialization_lock_text(
		definition
	)
	assert(warning.contains("Заблокирует альтернативы"))
	assert(warning.contains("turret_specialization_rapid"))
	assert(warning.contains("turret_specialization_electric"))


func _test_diagnostics() -> void:
	assert(
		UpgradeCardFormatter.get_diagnostic_text(&"repeat_limit_reached")
		== "Достигнут лимит повторений"
	)
	assert(
		UpgradeCardFormatter.get_diagnostic_text(&"missing_prerequisite")
		== "Не выполнено обязательное улучшение"
	)
	assert(UpgradeCardFormatter.get_diagnostic_text(&"") == "Доступна")
