class_name UpgradeCardFormatter
extends RefCounted


static func get_type_name(card_type: int) -> String:
	match card_type:
		UpgradeDefinition.CardType.UNLOCK:
			return "ОТКРЫТИЕ"
		UpgradeDefinition.CardType.BASIC:
			return "БАЗОВАЯ"
		UpgradeDefinition.CardType.ADVANCED:
			return "ПРОДВИНУТАЯ"
		UpgradeDefinition.CardType.INDIVIDUAL:
			return "ИНДИВИДУАЛЬНАЯ"
		UpgradeDefinition.CardType.SPECIALIZATION:
			return "СПЕЦИАЛИЗАЦИЯ"
		UpgradeDefinition.CardType.SPECIALIZATION_EXTRA:
			return "УСИЛЕНИЕ СПЕЦИАЛИЗАЦИИ"
		UpgradeDefinition.CardType.GENERAL:
			return "ОБЩАЯ"
	return "НЕИЗВЕСТНО"


static func get_card_group_id(card_type: int) -> StringName:
	match card_type:
		UpgradeDefinition.CardType.BASIC, UpgradeDefinition.CardType.ADVANCED:
			return &"basic"
		UpgradeDefinition.CardType.SPECIALIZATION:
			return &"specialization"
		UpgradeDefinition.CardType.INDIVIDUAL, UpgradeDefinition.CardType.SPECIALIZATION_EXTRA:
			return &"special"
		UpgradeDefinition.CardType.UNLOCK, UpgradeDefinition.CardType.GENERAL:
			return &"main"
	return &"main"


static func get_card_group_name(card_type: int) -> String:
	match get_card_group_id(card_type):
		&"basic":
			return "БАЗОВАЯ"
		&"specialization":
			return "СПЕЦИАЛИЗАЦИЯ"
		&"special":
			return "СПЕЦИАЛЬНАЯ"
		&"main":
			return "ОСНОВНАЯ"
	return "ОСНОВНАЯ"


static func get_card_group_symbol(card_type: int) -> String:
	match get_card_group_id(card_type):
		&"basic":
			return "◆"
		&"specialization":
			return "✦"
		&"special":
			return "⬟"
		&"main":
			return "●"
	return "●"


static func get_card_group_accent_color(card_type: int) -> Color:
	match get_card_group_id(card_type):
		&"basic":
			return Color(0.34, 0.68, 1.0)
		&"specialization":
			return Color(0.94, 0.56, 1.0)
		&"special":
			return Color(1.0, 0.68, 0.28)
		&"main":
			return Color(0.46, 0.92, 0.66)
	return Color(0.46, 0.92, 0.66)


static func get_price_color() -> Color:
	return Color(1.0, 0.84, 0.34)


static func get_branch_name(branch_id: StringName) -> String:
	match branch_id:
		&"turret":
			return "Турели"
		&"melee":
			return "Ближний бой"
		&"ranged":
			return "Дальний бой"
		&"healer":
			return "Лекарь"
		&"steering":
			return "Управление"
		&"anchors":
			return "Якоря"
		&"shield_core":
			return "Ядро щита"
		&"defender":
			return "Защитник"
		&"":
			return "Общий пул"
	return String(branch_id)


static func get_effect_summary(effect: UpgradeEffectDefinition) -> String:
	if effect == null:
		return "Без немедленного эффекта"
	match effect.effect_type:
		UpgradeEffectDefinition.EffectType.NONE:
			return "Без немедленного эффекта"
		UpgradeEffectDefinition.EffectType.UNLOCK_BUILDABLE:
			return "Открывает объект: +%d" % effect.integer_value
		UpgradeEffectDefinition.EffectType.UNLOCK_ROLE:
			return "Открывает роль"
		UpgradeEffectDefinition.EffectType.DOMAIN_FLAG:
			return ""
		UpgradeEffectDefinition.EffectType.DOMAIN_SCALAR:
			return "×%s" % _format_number(effect.scalar_value)
		UpgradeEffectDefinition.EffectType.ADD_DEFENDER:
			return "Добавляет защитника: +%d" % effect.integer_value
		UpgradeEffectDefinition.EffectType.CREW_MOVE_SPEED_MULTIPLIER:
			return "Скорость экипажа: ×%s" % _format_number(effect.scalar_value)
		UpgradeEffectDefinition.EffectType.CREW_RESPAWN_MULTIPLIER:
			return "Время респауна: ×%s" % _format_number(effect.scalar_value)
	return "Игровой эффект"


static func get_requirements_text(
	definition: UpgradeDefinition,
	runtime: UpgradeRuntime
) -> String:
	var lines := PackedStringArray()
	for card_id: StringName in definition.prerequisite_card_ids:
		lines.append("%s %s" % [
			"✓" if runtime.has_card(card_id) else "○",
			String(card_id),
		])
	if definition.required_repeat_count > 0:
		var current: int = runtime.get_repeat_count(
			definition.required_repeat_card_id
		)
		lines.append("%s %s: %d/%d" % [
			"✓" if current >= definition.required_repeat_count else "○",
			String(definition.required_repeat_card_id),
			current,
			definition.required_repeat_count,
		])
	if definition.required_specialization_id != &"":
		var selected: StringName = runtime.get_specialization(
			definition.branch_id
		)
		lines.append("%s Специализация: %s" % [
			"✓" if selected == definition.required_specialization_id else "○",
			String(definition.required_specialization_id),
		])
	if definition.required_specialized_branch_id != &"":
		lines.append("%s Специализирована ветка: %s" % [
			"✓" if runtime.has_specialization(
				definition.required_specialized_branch_id
			) else "○",
			get_branch_name(definition.required_specialized_branch_id),
		])
	if definition.required_completed_branch_id != &"":
		lines.append("Требуется завершённая линия: %s" % get_branch_name(
			definition.required_completed_branch_id
		))
	return "Нет требований" if lines.is_empty() else "\n".join(lines)


static func get_repeat_text(
	definition: UpgradeDefinition,
	runtime: UpgradeRuntime
) -> String:
	if definition.repeat_limit <= 1:
		return ""
	return "Получено: %d/%d" % [
		runtime.get_repeat_count(definition.card_id),
		definition.repeat_limit,
	]


static func get_specialization_lock_text(
	definition: UpgradeDefinition
) -> String:
	if definition.card_type != UpgradeDefinition.CardType.SPECIALIZATION:
		return ""
	if definition.closes_specialization_ids.is_empty():
		return ""
	var names := PackedStringArray()
	for card_id: StringName in definition.closes_specialization_ids:
		names.append(String(card_id))
	return "Заблокирует альтернативы: %s" % ", ".join(names)


static func get_diagnostic_text(reason: StringName) -> String:
	match reason:
		&"":
			return "Доступна"
		&"repeat_limit_reached":
			return "Достигнут лимит повторений"
		&"specialization_closed":
			return "Специализация закрыта"
		&"missing_prerequisite":
			return "Не выполнено обязательное улучшение"
		&"missing_repeat_count":
			return "Недостаточно повторений обязательной карточки"
		&"wrong_specialization":
			return "Выбрана другая специализация"
		&"branch_not_specialized":
			return "Ветка ещё не специализирована"
		&"branch_line_not_completed":
			return "Не завершена базовая линия ветки"
		&"specialization_event_only":
			return "Доступна только в событии специализации"
	return String(reason).replace("_", " ")


static func _format_number(value: float) -> String:
	return "%.2f" % value
