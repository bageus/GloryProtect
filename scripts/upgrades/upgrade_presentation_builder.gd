class_name UpgradePresentationBuilder
extends RefCounted

var _catalog: UpgradeCatalog
var _runtime: UpgradeRuntime


func configure(catalog: UpgradeCatalog, runtime: UpgradeRuntime) -> void:
	assert(catalog != null and catalog.is_valid())
	assert(runtime != null)
	_catalog = catalog
	_runtime = runtime


func build_card(
	definition: UpgradeDefinition,
	unavailable_reason: StringName = &"",
	is_specialization_offer: bool = false
) -> UpgradeCardViewData:
	assert(_catalog != null and _runtime != null)
	assert(definition != null and definition.is_valid())
	var view := UpgradeCardViewData.new()
	view.card_id = definition.card_id
	view.title = definition.title
	view.description = definition.description
	view.branch_id = definition.branch_id
	view.branch_label = get_branch_label(definition.branch_id)
	view.card_type = definition.card_type
	view.card_type_label = get_card_type_label(definition.card_type)
	view.effect_summary = _build_effect_summary(definition.effect)
	view.requirements_summary = _build_requirements_summary(definition)
	view.repeat_progress = _build_repeat_progress(definition)
	view.unavailable_reason_id = unavailable_reason
	view.unavailable_reason_text = get_reason_text(unavailable_reason)
	if is_specialization_offer:
		view.specialization_warning = _build_specialization_warning(definition)
	return view


func get_branch_label(branch_id: StringName) -> String:
	match branch_id:
		&"":
			return "Общий пул"
		&"turret":
			return "Турели"
		&"defender", &"melee":
			return "Защитники"
		&"shooter":
			return "Стрелки"
		&"medic":
			return "Лекарь"
		&"anchor":
			return "Якоря"
		&"control":
			return "Управление"
		&"shield":
			return "Щит и ядро"
	return String(branch_id).capitalize()


func get_card_type_label(card_type: int) -> String:
	match card_type:
		UpgradeDefinition.CardType.UNLOCK:
			return "Открывающая"
		UpgradeDefinition.CardType.BASIC:
			return "Базовая"
		UpgradeDefinition.CardType.ADVANCED:
			return "Продвинутая"
		UpgradeDefinition.CardType.INDIVIDUAL:
			return "Индивидуальная"
		UpgradeDefinition.CardType.SPECIALIZATION:
			return "Специализация"
		UpgradeDefinition.CardType.SPECIALIZATION_EXTRA:
			return "Усиление специализации"
		UpgradeDefinition.CardType.GENERAL:
			return "Общая"
	return "Неизвестный тип"


func get_reason_text(reason_id: StringName) -> String:
	match reason_id:
		&"":
			return "Доступна"
		&"invalid_definition":
			return "Некорректное определение карточки"
		&"specialization_event_only":
			return "Появляется только в событии специализации"
		&"not_specialization_card":
			return "Не является карточкой специализации"
		&"wrong_specialization_branch":
			return "Относится к другой ветке специализации"
		&"specialization_already_selected":
			return "В этой ветке уже выбрана специализация"
		&"specialization_closed":
			return "Заблокирована выбранной специализацией"
		&"repeat_limit_reached":
			return "Достигнут лимит повторений"
		&"missing_prerequisite":
			return "Не получена обязательная предыдущая карточка"
		&"missing_repeat_count":
			return "Недостаточно повторов обязательной карточки"
		&"wrong_specialization":
			return "Требуется другая специализация"
		&"branch_not_specialized":
			return "Ветка ещё не специализировалась"
		&"branch_line_not_completed":
			return "Не завершена требуемая линия ветки"
		&"unavailable":
			return "Карточка сейчас недоступна"
	return String(reason_id).replace("_", " ").capitalize()


func _build_effect_summary(effect: UpgradeEffectDefinition) -> String:
	if effect == null or effect.effect_type == UpgradeEffectDefinition.EffectType.NONE:
		return "Без мгновенного эффекта"
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.UNLOCK_BUILDABLE:
			return "Доступный объект: %s +%d" % [
				_get_buildable_label(effect.buildable_type_id),
				effect.integer_value,
			]
		UpgradeEffectDefinition.EffectType.UNLOCK_ROLE:
			return "Открывает роль: %s" % _format_target_id(effect.target_id)
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
			return "Открывает правило: %s" % _format_target_id(effect.target_id)
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			return "Изменяет параметр %s: %s" % [
				_format_target_id(effect.target_id),
				_format_scalar(effect.scalar_value),
			]
		UpgradeEffectDefinition.EffectType.ADD_DEFENDER:
			return "Экипаж: +%d защитник" % effect.integer_value
		UpgradeEffectDefinition.EffectType.CREW_MOVE_SPEED_MULTIPLIER:
			return "Скорость защитников: +%d%%" % _multiplier_bonus_percent(
				effect.scalar_value
			)
		UpgradeEffectDefinition.EffectType.CREW_RESPAWN_MULTIPLIER:
			return "Время замены: −%d%%" % _reduction_percent(
				effect.scalar_value
			)
	return "Эффект задан игровым доменом"


func _build_requirements_summary(definition: UpgradeDefinition) -> String:
	var requirements := PackedStringArray()
	for prerequisite_id: StringName in definition.prerequisite_card_ids:
		requirements.append(_format_card_requirement(
			prerequisite_id,
			_runtime.has_card(prerequisite_id)
		))
	if definition.required_repeat_count > 0:
		var current_count: int = _runtime.get_repeat_count(
			definition.required_repeat_card_id
		)
		requirements.append("%s %d/%d" % [
			_get_definition_title(definition.required_repeat_card_id),
			current_count,
			definition.required_repeat_count,
		])
	if definition.required_specialization_id != &"":
		var selected_id: StringName = _runtime.get_specialization(
			definition.branch_id
		)
		requirements.append(_format_card_requirement(
			definition.required_specialization_id,
			selected_id == definition.required_specialization_id
		))
	if definition.required_specialized_branch_id != &"":
		requirements.append("%s: %s" % [
			get_branch_label(definition.required_specialized_branch_id),
			"✓ специализация выбрана"
			if _runtime.has_specialization(definition.required_specialized_branch_id)
			else "○ специализация не выбрана",
		])
	if definition.required_completed_branch_id != &"":
		requirements.append("%s: %s" % [
			get_branch_label(definition.required_completed_branch_id),
			"✓ линия завершена"
			if _has_completed_line(definition.required_completed_branch_id)
			else "○ линия не завершена",
		])
	if definition.card_type == UpgradeDefinition.CardType.INDIVIDUAL:
		requirements.append("%s: %s" % [
			get_branch_label(definition.branch_id),
			"✓ линия завершена"
			if _has_completed_line(definition.branch_id)
			else "○ линия не завершена",
		])
	if requirements.is_empty():
		return "Нет дополнительных требований"
	return "\n".join(requirements)


func _build_repeat_progress(definition: UpgradeDefinition) -> String:
	if definition.repeat_limit <= 1:
		return ""
	return "%d/%d" % [
		_runtime.get_repeat_count(definition.card_id),
		definition.repeat_limit,
	]


func _build_specialization_warning(definition: UpgradeDefinition) -> String:
	if definition.card_type != UpgradeDefinition.CardType.SPECIALIZATION:
		return ""
	var closed_titles := PackedStringArray()
	for closed_id: StringName in definition.closes_specialization_ids:
		closed_titles.append(_get_definition_title(closed_id))
	if closed_titles.is_empty():
		return "Выбор закрепит специализацию этой ветки"
	return "Выбор навсегда заблокирует: %s" % ", ".join(closed_titles)


func _format_card_requirement(card_id: StringName, is_complete: bool) -> String:
	return "%s %s" % [
		"✓" if is_complete else "○",
		_get_definition_title(card_id),
	]


func _get_definition_title(card_id: StringName) -> String:
	var definition: UpgradeDefinition = _catalog.get_definition(card_id)
	return definition.title if definition != null else String(card_id)


func _has_completed_line(branch_id: StringName) -> bool:
	for definition: UpgradeDefinition in _catalog.definitions:
		if definition.branch_id != branch_id:
			continue
		if definition.card_type != UpgradeDefinition.CardType.ADVANCED:
			continue
		if _runtime.has_card(definition.card_id):
			return true
	return false


func _get_buildable_label(type_id: int) -> String:
	match type_id:
		BuildableType.Id.MEDICAL_STATION:
			return "медицинский пост"
		BuildableType.Id.TURRET:
			return "турель"
	return "объект %d" % type_id


func _format_target_id(target_id: StringName) -> String:
	return String(target_id).replace("_", " ")


func _format_scalar(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%+.0f" % value
	return "%+.2f" % value


func _multiplier_bonus_percent(multiplier: float) -> int:
	return maxi(0, int(round((multiplier - 1.0) * 100.0)))


func _reduction_percent(multiplier: float) -> int:
	return maxi(0, int(round((1.0 - multiplier) * 100.0)))
