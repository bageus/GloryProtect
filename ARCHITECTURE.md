# GloryProtect — архитектура проекта

Этот файл — единственный источник правды для архитектуры. Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md).

## 1. Основные правила

- Godot 4.6.2 stable, строго типизированный GDScript.
- Максимум 600 строк на поддерживаемый файл; с 450 строк файл оценивается на разделение.
- Каждое изменяемое состояние имеет одного владельца.
- Настройки и баланс находятся в типизированных `Resource`.
- UI читает состояние и отправляет команды, но не реализует механику.
- Представление не изменяет симуляцию.
- Архитектурное изменение обновляет этот файл в том же наборе изменений.

## 2. Направление зависимостей

```text
Input / UI
    ↓ команды
Domain systems
    ↓ события и неизменяемые снимки
Presentation
```

## 3. Композиция GameRoot

```text
GameRoot
├── GameFlowController
├── RunDifficulty
├── RunEconomy
├── UpgradeSystem
├── BuildableInventory
├── RunStatistics
├── ShieldSystem
├── ShieldCriticalAlertController
├── Input adapters
├── World
│   ├── OrbDomain
│   ├── StrategicWaveDomain
│   ├── AnchorDomain
│   ├── BoardingDomain
│   ├── BuildableGrid
│   ├── MedicalStationSystem
│   └── Platform
│       ├── PlatformVisualController
│       ├── BuildableGridVisual
│       ├── CrewManager
│       ├── CrewRoleManager
│       └── Camera2D
└── CanvasLayer
    ├── PrototypeHUD
    ├── StrategicMinimap
    ├── ShieldCriticalAlertPresenter
    ├── UpgradeSelectionPanel
    └── GameOverPanel
```

`GameRoot` только собирает системы и передаёт зависимости.

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Состояние забега и пауза | `GameFlowController` |
| Активное время и общая сложность | `RunDifficulty` |
| Текущие физические убийства и финальный результат | `RunStatistics` |
| Лучшие результаты текущего запуска | `SessionRecordsStore` |
| Монеты | `RunEconomy` |
| Выдача и число покупок карточек | `UpgradeSystem` |
| Открытое количество размещаемых объектов | `BuildableInventory` |
| Размещённые объекты и занятость клеток | `BuildableGrid` |
| Текущий цикл лечения и выбранная цель | `MedicalStationSystem` |
| Роли экипажа и занятость постов | `CrewRoleManager` и `RoleStationRegistry` |
| Здоровье сущности | её `HealthComponent` |
| Пять значений щита | `ShieldSystem` |
| Активные стратегические группы и маршруты | `StrategicWaveSystem` |
| Таймер и номер волны | `StrategicWaveDirector` |
| Таймер и RNG мутаций групп | `StrategicGroupMutationController` |
| Положение и скорость платформы | `PlatformController` |
| Состояния якорей | `AnchorRuntimeStore` |
| Реестр физических врагов | `BoardingEnemyRegistry` |
| Таймер атаки | её `MeleeAttackComponent` |

## 5. GameFlowDomain

```text
BOOT
START_DELAY
RUNNING
CARD_SELECTION
MANUAL_PAUSE
GAME_OVER
```

`GameFlowController` владеет переходами, полной паузой и причиной поражения. `restart_run()` разрешён только из `GAME_OVER` и перезагружает текущую сцену.

## 6. PlatformDomain

`PlatformController` владеет горизонтальной физикой и является единственным источником геометрии клеток:

```text
get_cell_count()
is_valid_cell(cell_index)
get_cell_local_x(cell_index)
get_nearest_cell_index(local_x)
```

BuildableDomain, роли и визуал не повторяют формулу положения клетки.

## 7. BuildableDomain

```text
BuildableType
BuildableBalance
BuildableRuntime
BuildableSnapshot
BuildableInventory
BuildableGrid
BuildableDebugInput
BuildableGridVisual
```

### Типы

```text
MEDICAL_STATION
TURRET
```

`TURRET` пока является только точкой расширения и имеет нулевое доступное количество.

### BuildableInventory

Владеет открытым количеством каждого типа:

```text
unlock(type_id, amount)
get_unlocked_count(type_id)
is_unlocked(type_id)
can_deploy(type_id, deployed_count)
```

Демонтаж не удаляет открытие.

### BuildableGrid

Единственный владелец:

```text
Dictionary[buildable_id, BuildableRuntime]
Dictionary[cell_index, buildable_id]
```

Атомарные операции:

```text
place(type_id, cell_index)
move(buildable_id, cell_index)
demolish(buildable_id)
```

Правила:

- одна клетка содержит максимум один объект;
- служебные клетки недоступны;
- присутствие персонажа на клетке не проверяется;
- объекты не создают коллизий;
- размещённое количество не превышает открытое;
- наружу выдаются только `BuildableSnapshot`.

### Адаптер и визуал

`BuildableDebugInput` только преобразует клавиши в команды. `BuildableGridVisual` только читает снимки и рисует выбранную клетку и медицинский пост.

## 8. DynamicRoleStationDomain

`MEDIC` является динамическим фиксированным постом.

`RoleStationRegistry` поддерживает:

```text
set_dynamic_target(role_id, local_x)
clear_dynamic_target(role_id)
has_station(role_id)
reserve(role_id, defender_id)
```

`CrewRoleManager` остаётся единственным владельцем назначений.

При установке или переносе поста медицинская система вызывает:

```text
set_dynamic_role_station(MEDIC, true, local_x)
```

При демонтаже вызывается:

```text
set_dynamic_role_station(MEDIC, false)
```

Это немедленно освобождает назначенного или направляющегося лекаря и переводит его в `FREE_FIGHTER`.

## 9. MedicalStationDomain

```text
MedicalStationSystem
BuildableBalance
CrewManager
CrewRoleManager
HealthComponent
```

`MedicalStationSystem` владеет только:

```text
идентификатором текущего поста
координатой поста
идентификатором лекаря текущего цикла
идентификатором цели
оставшимся временем цикла
флагом активного цикла
```

Он не владеет здоровьем или ролью.

### Выбор цели

Из живых защитников выбирается:

1. минимальное `current_health`;
2. при равенстве — ближайший к лекарю;
3. полностью здоровые цели игнорируются.

Лекарь может лечить себя.

### Цикл

```text
выбрать цель
    ↓
добежать до цели
    ↓
непрерывный контакт heal_interval
    ↓
HealthComponent.heal(heal_amount)
    ↓
повторная оценка целей
```

Текущие параметры:

```text
heal_interval = 5.0 seconds
heal_amount = 1 segment
heal_range = 18
```

Если цель выходит из радиуса, лекарь следует за ней, а непрерывный таймер сбрасывается. Вне `RUNNING` таймер не меняется.

### Неделимое действие и переназначение

Чтобы менеджер ролей не зависел от медицинской реализации, медицинская система сообщает только общий факт неделимого действия:

```text
CrewRoleManager.set_external_role_action_active(
    defender_id,
    MEDIC,
    true или false
)
```

`CrewRoleManager` не знает цель лечения, оставшееся время или величину восстановления.

При новой команде во время активного цикла:

- назначение переходит в `WAITING_FOR_ACTION`;
- медицинская система завершает текущий цикл;
- восстанавливается один сегмент;
- медицинская система снимает флаг внешнего действия;
- менеджер ролей начинает переход к новой роли;
- следующий цикл не запускается.

При смерти, демонтаже или принудительном освобождении роли флаг внешнего действия очищается.

### Бой

`DefenderCombatController` не разрешает ближний бой роли `MEDIC`. Во время перехода к посту защитник может остановиться для боя по общим правилам перехода.

## 10. Остальные домены

- `RunDifficulty` владеет активным временем и общей сложностью.
- `RunStatistics` владеет физическими убийствами и финальным снимком.
- `RunEconomy` владеет монетами.
- `UpgradeSystem` владеет выдачей карточек; карточки пока без эффектов.
- `ShieldSystem` владеет прочностью секций.
- `StrategicWaveSystem` владеет агрегированными группами.
- `AnchorRuntimeStore` владеет состояниями якорей.
- `BoardingEnemyRegistry` хранит только физических врагов.

## 11. Обязательные тестовые границы

### BuildableGrid

- Закрытый объект нельзя установить.
- Служебную клетку нельзя занять.
- На клетке может находиться максимум один объект.
- Второй медицинский пост запрещён.
- Перенос освобождает старую клетку и занимает новую.
- Демонтаж освобождает клетку, но сохраняет открытие.
- Координата снимка совпадает с `PlatformController.get_cell_local_x()`.

### MedicalStationSystem

- Роль `MEDIC` недоступна без поста.
- После установки защитник физически прибывает к посту.
- Выбирается наиболее раненая цель, при равенстве — ближайшая.
- Карточки останавливают таймер лечения.
- Один цикл восстанавливает один сегмент.
- Переназначение ждёт завершения текущего цикла.
- При ожидающей команде следующий цикл не начинается.
- Перенос поста не отменяет текущий цикл.
- Демонтаж немедленно освобождает лекаря.
- Лекарь не использует ближний бой.

### Общие

- Здоровье изменяется только через `HealthComponent`.
- UI не владеет размещением или лечением.
- Карточки полностью останавливают симуляцию.
- Лимит 600 строк не нарушен.

## 12. Следующая итерация

1. Размещаемая базовая турель.
2. Несколько турелей на разных клетках.
3. Отдельный оператор каждой турели.
4. Стрельба по физическим врагам в радиусе.
5. Урон через существующий combat/reward flow.
6. Завершение начатого выстрела перед переназначением.
7. Перенос и демонтаж турели.

Карточки остаются заглушками до отдельного проектирования каталога улучшений.

## 13. Запрещённые решения

- Второй владелец занятости клеток.
- Хранение размещённых объектов в визуальном компоненте.
- Повторение формулы координаты клетки вне `PlatformController`.
- Изменение здоровья напрямую вне `HealthComponent`.
- Подсчёт таймера лечения в `CrewRoleManager` или HUD.
- Прямая зависимость `CrewRoleManager` от `MedicalStationSystem`.
- Ближний бой активного лекаря.
- Прерывание уже начатого цикла обычным переназначением.
- Сохранение роли `MEDIC` после демонтажа поста.
- Установка объектов на служебные клетки.
- Физическая коллизия поста с персонажами.
- Реализация турели внутри медицинской системы.
- Глобальный менеджер всех объектов и ролей.
- Архитектурное изменение без обновления этого файла.
