# Common and Repeatable Upgrade Architecture

Этот документ фиксирует архитектуру общего пула и повторяемых карточек. Игровые правила и числовые значения находятся в:

- [`../rules/06_UPGRADE_CARDS_BRANCHES_AND_SPECIALIZATIONS.md`](../rules/06_UPGRADE_CARDS_BRANCHES_AND_SPECIALIZATIONS.md);
- [`../rules/07_UPGRADE_BRANCH_CATALOG.md`](../rules/07_UPGRADE_BRANCH_CATALOG.md).

## Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Выбранные карточки и число повторов | `UpgradeRuntime` |
| Прогресс веток и выбранные специализации | `UpgradeRuntime` |
| Веса веток | `UpgradeDrawGenerator` |
| Текущее предложение и стоимость покупки | `UpgradeSystem` |
| Открытое количество объектов | `BuildableInventory` |
| Состав экипажа и множитель скорости | `CrewManager` |
| Ожидающие замены и множитель времени замены | `CrewReplacementController` |

`UpgradeCatalog` хранит неизменяемые определения и условия доступности. Он не хранит состояние забега.

## Поток покупки

```text
UpgradeSystem
→ UpgradeDrawGenerator / UpgradeSpecializationEventGenerator
→ UpgradeEffectApplier.can_apply(definition)
→ RunEconomy.spend_coins(cost)
→ UpgradeEffectApplier.apply_effect(definition)
→ UpgradeRuntime.record_card(definition)
→ UpgradeDrawGenerator.apply_selected_card(definition)
```

Если доменный эффект применить невозможно, покупка не выполняется. Если применение эффекта не удалось после списания, стоимость возвращается.

## Границы UpgradeEffectApplier

`UpgradeEffectApplier` не владеет:

- числом выбранных копий;
- prerequisites;
- прогрессом специализации;
- весами веток;
- лимитом повторов.

Он только переводит типизированный эффект в вызов публичного API владельца домена:

```text
UNLOCK_BUILDABLE
→ BuildableInventory.unlock(...)

ADD_DEFENDER
→ CrewManager.add_defender(...)

CREW_MOVE_SPEED_MULTIPLIER
→ CrewManager.multiply_movement_speed(...)

CREW_RESPAWN_MULTIPLIER
→ CrewReplacementController.multiply_respawn_time(...)

DOMAIN_FLAG / DOMAIN_SCALAR
→ UpgradeRuntime
```

Поэтому после третьего `Поста турели` effect layer технически способен открыть ещё один объект, но `UpgradeCatalog` уже запрещает повтор карточки. Четвёртая турель открывается только отдельной карточкой.

## Игровой каталог

Активный каталог прототипа:

```text
resources/upgrades/game_upgrade_catalog.tres
```

`technical_upgrade_catalog.tres` остаётся изолированной фикстурой старых unit-тестов и не используется игровым `UpgradeSystem`.

## Общий пул

Общие карточки:

- имеют пустой `branch_id`;
- получают постоянный вес общего пула;
- не изменяют веса веток;
- не увеличивают прогресс специализации.

Текущие эффекты:

```text
Добавить защитника: +1, максимум 5 копий
Скорость перемещения: ×1.15, затем ещё ×1.15
Время замены: ×0.75, затем ещё ×0.75
```

`CrewManager` применяет текущий множитель скорости ко всем существующим защитникам и к каждому вновь созданному или восстановленному защитнику.

`CrewReplacementController` использует текущий множитель при создании нового `CrewReplacementRuntime`. Уже запущенный таймер не пересчитывается задним числом.

## Повторяемый Пост турели

`turret_post`:

- тип `UNLOCK`;
- `repeat_limit = 3`;
- каждая копия вызывает `BuildableInventory.unlock(TURRET, 1)`;
- ни одна копия не учитывается для специализации;
- ни одна копия не меняет вес турельной ветки.

Три базовые линии используют `turret_post` как prerequisite. Поэтому первая копия автоматически открывает:

- `turret_damage_basic`;
- `turret_cooldown_basic`;
- `turret_range_basic`.

Отдельной карточки базового урона турели нет. Базовый урон `1` принадлежит `BuildableBalance`.

## Четвёртая турель

`turret_fourth` является индивидуальной одноразовой карточкой. Все условия задаются данными:

```text
required_repeat_card_id = turret_post
required_repeat_count = 3
required_specialized_branch_id = turret
required_completed_branch_id = turret
```

`UpgradeCatalog` проверяет условия. UI, `UpgradeEffectApplier` и `TurretSystem` не дублируют эту логику.

## Турельные боевые значения

До реализации NEXT-09 турельные карточки сохраняют значения в `UpgradeRuntime`:

```text
turret_damage_bonus
turret_cooldown_reduction
turret_range_bonus_ratio
```

Выбранная специализация сохраняется как specialization ID и domain flag. NEXT-09 должен читать эти значения через публичный upgrade runtime API и применять их в `TurretSystem`, не перемещая владение выбором карточек в боевой домен.

## Сброс забега

В текущем прототипе новый забег создаёт новую игровую сцену. Поэтому полный состав экипажа и открытые объекты возвращаются к начальному состоянию вместе с новыми экземплярами доменных систем.

Дополнительно `UpgradeSystem.reset_for_run()` сбрасывает:

- `UpgradeRuntime`;
- веса генератора;
- множитель скорости экипажа;
- множитель времени замены.

## Обязательные тестовые границы

- предложение содержит уникальные `card_id`;
- повторяемая карточка не дублируется внутри предложения;
- первый пост открывает ровно три базовые турельные линии;
- пост не изменяет вес и прогресс специализации;
- четвёртая копия поста недоступна;
- `Добавить защитника` недоступна после пятой копии или достижения восьми защитников;
- новые защитники регистрируются в `CrewRoleManager`;
- скорость применяется к существующим и новым защитникам;
- время будущей замены использует текущий множитель;
- `4-я турель` требует все три условия;
- свежая сцена начинает с трёх защитников, нулевого количества турелей и единичных множителей.

## Запрещённые решения

- Хранить число повторов в `UpgradeEffectApplier` или UI.
- Добавлять защитника напрямую из карточки без `CrewManager`.
- Изменять скорость отдельных защитников из `UpgradeSystem`.
- Изменять таймеры замены напрямую из каталога.
- Хардкодить условия четвёртой турели в UI.
- Создавать отдельную карточку базового урона `1`.
- Давать открывающей или общей карточке прогресс специализации.
- Использовать `technical_upgrade_catalog.tres` как игровой каталог.
