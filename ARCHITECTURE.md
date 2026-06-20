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

UI может владеть только состоянием интерфейса, например выбранным защитником. Оно не определяет доступность роли окончательно и не изменяет назначение напрямую.

Представление может хранить только краткоживущие визуальные данные: время вспышки, трассера или последнюю известную позицию цели. Эти данные не используются симуляцией.

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
├── CrewDebugInput : CrewSelectionController
├── Input adapters
├── World
│   ├── OrbDomain
│   ├── StrategicWaveDomain
│   ├── AnchorDomain
│   ├── BoardingDomain
│   ├── BuildableGrid
│   ├── MedicalStationSystem
│   ├── TurretSystem
│   └── Platform
│       ├── PlatformVisualController
│       ├── BuildableGridVisual
│       │   └── TurretVisualController
│       ├── CrewManager
│       ├── CrewRoleManager
│       └── Camera2D
└── CanvasLayer
    ├── PrototypeHUD
    │   └── CrewCommandPanel
    ├── StrategicMinimap
    ├── UpgradeSelectionPanel
    └── GameOverPanel
```

`CrewDebugInput` сохранён как совместимое имя узла и тонкая оболочка над `CrewSelectionController`. Клавиатура, мышь и панель экипажа используют один контроллер выбора.

`PrototypeHUD` создаёт и настраивает `CrewCommandPanel` внутри слоя UI. Панель не добавляется в доменный слой.

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Состояние забега и пауза | `GameFlowController` |
| Активное время и общая сложность | `RunDifficulty` |
| Монеты | `RunEconomy` |
| Выдача карточек | `UpgradeSystem` |
| Выбранный защитник | `CrewSelectionController` |
| Открытое количество объектов | `BuildableInventory` |
| Размещённые объекты и занятость клеток | `BuildableGrid` |
| Текущий цикл лечения | `MedicalStationSystem` |
| Боевой runtime каждой турели | `TurretSystem` через `TurretRuntime` |
| Визуальные эффекты турели | `TurretVisualController` через `TurretVisualRuntime` |
| Роли, конкретные посты и их владельцы | `CrewRoleManager` + `RoleStationRegistry` |
| Здоровье сущности | её `HealthComponent` |
| Положение и скорость платформы | `PlatformController` |
| Состояния якорей | `AnchorRuntimeStore` |
| Реестр физических врагов | `BoardingEnemyRegistry` |
| Стратегические группы | `StrategicWaveSystem` |
| Статистика забега | `RunStatistics` |

## 5. CrewSelectionDomain

```text
CrewSelectionController
CrewDebugInput
DefenderVisual
```

`CrewSelectionController` владеет только `selected_defender_id` и публикует:

```text
select_defender(defender_id)
get_selected_defender_id()
get_selected_defender()
selected_defender_changed
```

Источники выбора:

- клавиши `5`, `6`, `7`;
- кнопки портретов;
- необработанный левый клик рядом с живым защитником в мировых координатах.

Клик по UI не доходит до мирового выбора, потому что панель перехватывает мышь. Для преобразования экранной позиции используется canvas transform текущего viewport.

`DefenderVisual` получает только флаг `set_selected(bool)` и рисует жёлтое кольцо. Он не меняет доменное состояние.

После замены защитника сохраняется тот же стабильный `defender_id`, поэтому выбранность автоматически применяется к новому экземпляру.

## 6. CrewCommandPresentation

```text
CrewCommandPanel
CrewCommandPanelView
CrewCommandText
PrototypeHUD
```

### CrewCommandPanel

Координатор UI:

- читает `CrewManager`, `CrewRoleManager`, `CrewReplacementController` и `BuildableGrid`;
- получает выбранного защитника из `CrewSelectionController`;
- отправляет только `request_assignment(...)`;
- подписывается на изменения назначений, экипажа и объектов;
- показывает результат или причину отказа.

Панель не резервирует пост и не меняет `CrewAssignmentRuntime` напрямую.

### CrewCommandPanelView

Создаёт и хранит только контролы:

- портрет-кнопки;
- стандартные роли;
- список турелей;
- выбранное состояние;
- строку обратной связи.

Он не знает правила доступности ролей.

### CrewCommandText

Статически форматирует:

- названия ролей;
- текущую и целевую роль;
- занятость поста;
- причины отказа.

Он не читает дерево сцены и не хранит состояние.

### Доступность кнопок

UI предварительно блокирует команду, если:

- игра не выполняет мировую симуляцию;
- защитник погиб;
- назначение не находится в `ACTIVE`;
- пост отсутствует;
- пост занят другим защитником;
- роль уже активна на том же `station_id`.

`CrewRoleManager` остаётся окончательным валидатором и может отклонить команду независимо от состояния кнопки.

### Диагностический HUD

Большая телеметрическая панель скрыта по умолчанию и переключается `F10`. Она остаётся только диагностическим представлением и не участвует в управлении.

## 7. PlatformDomain

`PlatformController` является единственным источником геометрии клеток:

```text
get_cell_count()
is_valid_cell(cell_index)
get_cell_local_x(cell_index)
get_nearest_cell_index(local_x)
```

BuildableDomain, роли, медицина, турели и визуал не повторяют формулу положения клетки.

## 8. BuildableDomain

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

Поддерживаемые типы:

```text
MEDICAL_STATION
TURRET
```

`BuildableInventory` владеет открытым количеством каждого типа. `BuildableGrid` владеет:

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
- персонажи не блокируют установку;
- объекты не создают коллизий;
- размещённое количество не превышает открытое;
- демонтаж не удаляет открытие;
- наружу выдаются `BuildableSnapshot`.

## 9. ConcreteRoleStationDomain

Назначение защитника состоит из:

```text
current_role
current_station_id
target_role
target_station_id
state
```

Статические посты используют `station_id = -1`:

```text
DRIVER
LEFT_ANCHOR
RIGHT_ANCHOR
```

Медицинский пост использует `MEDIC / 0`. Каждая турель использует `TURRET / buildable_id`.

`RoleStationRegistry` хранит владельца и координату по составному ключу `role_id : station_id`.

Основной API:

```text
request_assignment(defender_id, role_id, station_id)
set_dynamic_role_station(role_id, available, local_x, station_id, relocate_active)
get_role_owner(role_id, station_id)
is_role_station_available(role_id, station_id)
```

## 10. Неделимые внешние действия

Системы ролей не знают устройство лечения или выстрела. Они получают только общий флаг:

```text
set_external_role_action_active(defender_id, role_id, active)
```

Пока флаг активен, переназначение переходит в `WAITING_FOR_ACTION`. После снятия флага начинается физический переход.

Интерфейс используют:

- `MedicalStationSystem` для цикла лечения;
- `TurretSystem` для начатого выстрела.

## 11. MedicalStationDomain

`MedicalStationSystem` владеет целью и таймером лечения, но не здоровьем и не ролью.

Цикл:

```text
выбрать наиболее раненую цель
→ добежать до неё
→ 5 секунд непрерывного контакта
→ HealthComponent.heal(1)
→ повторная оценка целей
```

Активный лекарь не использует ближний бой. При переносе поста текущий цикл завершается, затем лекарь прибывает к новой позиции. Демонтаж немедленно освобождает роль.

## 12. TurretCombatDomain

```text
TurretRuntime
TurretTargetSelector
TurretGeometry
TurretSystem
TurretDebugInput
```

Каждая турель имеет независимые:

```text
operator_id
target_enemy_id
shot_remaining
cooldown_remaining
firing
```

`TurretGeometry` является общим источником локального и мирового pivot.

`TurretTargetSelector` выбирает ближайшую допустимую цель в состояниях:

```text
CLIMBING
ON_PLATFORM
FIGHTING
JUMPING
```

`TurretSystem`:

- регистрирует пост `TURRET/buildable_id`;
- проверяет живого прибывшего оператора;
- фиксирует ближайшую цель на весь выстрел;
- вызывает `HealthComponent.apply_damage(1)`;
- запускает независимый кулдаун;
- публикует read-only состояние;
- не начисляет монеты напрямую.

Смерть проходит через общий поток:

```text
HealthComponent.depleted
→ BoardingEnemy.kill("combat")
→ BoardingEnemyRegistry.enemy_removed
→ BoardingRewardController
→ RunEconomy / RunStatistics
```

Во время выстрела оператор завершает неделимое действие перед переходом. При переносе турели объект меняет клетку сразу, а оператор должен физически прибыть. Демонтаж отменяет выстрел и освобождает оператора.

## 13. TurretPresentationDomain

```text
TurretVisualRuntime
TurretVisualController
BuildableBalance
```

Визуальный runtime хранит только:

```text
shot_origin_local
last_target_world
tracer_remaining
flash_remaining
```

Контроллер рисует корпус, состояние оператора, радиус, заряд, кулдаун, отдачу, вспышку и трассер. Он не выбирает цель и не наносит урон.

При переносе во время подготовки сохранённый `shot_origin_local` позволяет завершить визуальный выстрел из старой позиции.

## 14. Пауза

Во время `CARD_SELECTION` и `MANUAL_PAUSE`:

- мировые системы не изменяют таймеры;
- UI назначения не отправляет команды;
- при карточках `CrewCommandPanel` скрыт;
- при ручной паузе панель видима, но кнопки отключены;
- flash/tracer и остальные pausable-процессы заморожены.

## 15. Обязательные тестовые границы

### CrewSelectionController

- выбранный `defender_id` является единым для мыши, кнопок и клавиш;
- выбранный защитник получает визуальное кольцо;
- при смене выбора кольцо снимается с предыдущего;
- замена экземпляра сохраняет выбранный стабильный ID.

### CrewCommandPanel

- создаёт кнопку для каждого доступного защитника;
- стандартные роли отправляют команду выбранному защитнику;
- лекарь недоступен без медицинского поста;
- установленная турель создаёт отдельную кнопку;
- занятый другим защитником пост отключён;
- состояние `MOVING` и `WAITING_FOR_ACTION` отключает новые команды;
- карточки скрывают панель;
- ручная пауза отключает команды;
- UI не изменяет назначения напрямую.

### Общие

- здоровье изменяется только через `HealthComponent`;
- UI не владеет боевой логикой;
- карточки и ручная пауза останавливают симуляцию;
- лимит 600 строк не нарушен.

## 16. Следующая итерация

1. Подключение настоящих ассетов защитников и врагов.
2. Состояния idle, бег, атака, смерть и переход к рабочему посту.
3. Отдельный presentation-controller анимаций без изменения боевой логики.
4. Подключение ассетов медицинского поста, турели, якорей и тросов.
5. Сохранение диагностической векторной графики как fallback для тестов.

Карточки остаются заглушками до отдельной итерации.

## 17. Запрещённые решения

- Второй владелец выбранного защитника.
- Прямое изменение `CrewAssignmentRuntime` из UI.
- Резервирование поста кнопкой интерфейса.
- Отдельная система ролей только для турелей.
- Один общий оператор для нескольких турелей.
- Прямое начисление монет из `TurretSystem`.
- Прямое удаление врага вместо `HealthComponent.apply_damage()`.
- Выбор цели или нанесение урона из визуального слоя.
- Управление ролью из `DefenderVisual`.
- Архитектурное изменение без обновления этого файла.
