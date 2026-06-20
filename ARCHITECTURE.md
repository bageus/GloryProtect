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

Представление может хранить только краткоживущие визуальные данные: время вспышки, трассера, последнюю известную экранную позицию цели. Эти данные не используются симуляцией.

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
    ├── StrategicMinimap
    ├── UpgradeSelectionPanel
    └── GameOverPanel
```

`BuildableGridVisual` создаёт и настраивает дочерний `TurretVisualController`. Это композиция только внутри слоя представления; `TurretSystem` не зависит от визуального контроллера.

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Состояние забега и пауза | `GameFlowController` |
| Активное время и общая сложность | `RunDifficulty` |
| Монеты | `RunEconomy` |
| Выдача карточек | `UpgradeSystem` |
| Открытое количество объектов | `BuildableInventory` |
| Размещённые объекты и занятость клеток | `BuildableGrid` |
| Текущий цикл лечения | `MedicalStationSystem` |
| Боевой runtime каждой турели | `TurretSystem` через `TurretRuntime` |
| Вспышка, трассер и последняя визуальная позиция цели | `TurretVisualController` через `TurretVisualRuntime` |
| Роли, конкретные посты и их владельцы | `CrewRoleManager` + `RoleStationRegistry` |
| Здоровье сущности | её `HealthComponent` |
| Положение и скорость платформы | `PlatformController` |
| Состояния якорей | `AnchorRuntimeStore` |
| Реестр физических врагов | `BoardingEnemyRegistry` |
| Стратегические группы | `StrategicWaveSystem` |
| Статистика забега | `RunStatistics` |

## 5. PlatformDomain

`PlatformController` является единственным источником геометрии клеток:

```text
get_cell_count()
is_valid_cell(cell_index)
get_cell_local_x(cell_index)
get_nearest_cell_index(local_x)
```

BuildableDomain, роли, медицина, турели и визуал не повторяют формулу положения клетки.

## 6. BuildableDomain

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

`BuildableGridVisual` рисует только выбранную клетку и медицинский пост. Полное изображение турелей принадлежит `TurretVisualController`.

## 7. ConcreteRoleStationDomain

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

Медицинский пост использует `MEDIC / 0`.

Каждая турель использует:

```text
TURRET / buildable_id
```

`RoleStationRegistry` хранит владельца и координату по составному ключу `role_id : station_id`. Две турели являются двумя независимыми постами одной роли.

Основной API:

```text
request_assignment(defender_id, role_id, station_id)
set_dynamic_role_station(role_id, available, local_x, station_id, relocate_active)
get_role_owner(role_id, station_id)
is_role_station_available(role_id, station_id)
```

## 8. Неделимые внешние действия

Системы ролей не знают устройство лечения или выстрела. Они получают только общий флаг:

```text
set_external_role_action_active(defender_id, role_id, active)
```

Пока флаг активен, обычное переназначение переходит в `WAITING_FOR_ACTION`. После снятия флага начинается физический переход.

Интерфейс используют:

- `MedicalStationSystem` для пятисекундного цикла лечения;
- `TurretSystem` для уже начатого выстрела.

## 9. MedicalStationDomain

`MedicalStationSystem` владеет целью и таймером лечения, но не здоровьем и не ролью.

Приоритет цели:

1. минимальное здоровье;
2. при равенстве — ближайший защитник.

Цикл:

```text
добежать до цели
→ 5 секунд непрерывного контакта
→ HealthComponent.heal(1)
→ повторная оценка целей
```

Активный лекарь не использует ближний бой. При переносе поста текущий цикл завершается, затем лекарь физически прибывает к новой позиции. Демонтаж немедленно освобождает роль.

## 10. TurretCombatDomain

```text
TurretRuntime
TurretTargetSelector
TurretGeometry
TurretSystem
TurretDebugInput
```

### TurretRuntime

Каждая установленная турель имеет собственное состояние:

```text
buildable_id
operator_id
target_enemy_id
shot_remaining
cooldown_remaining
firing
```

Клетка читается из `BuildableGrid` и не дублируется.

### TurretGeometry

Единственный источник геометрии башни:

```text
get_local_pivot(snapshot, balance)
get_world_pivot(platform, snapshot, balance)
get_default_aim_direction()
```

`TurretSystem` использует мировой pivot для выбора целей. `TurretVisualController` использует локальный pivot для корпуса, радиуса, заряда и трассера.

### TurretTargetSelector

Возвращает ближайшую допустимую цель в круговом радиусе.

Допустимые состояния:

```text
CLIMBING
ON_PLATFORM
FIGHTING
JUMPING
```

Наземные враги без пути не являются целями. При равной дистанции выбирается меньший стабильный `enemy_id`.

### TurretSystem

`TurretSystem`:

- создаёт `TurretRuntime` на `buildable_placed`;
- регистрирует пост `TURRET/buildable_id`;
- проверяет живого прибывшего оператора;
- выбирает ближайшую цель;
- фиксирует её на весь выстрел;
- вызывает `HealthComponent.apply_damage(1)` после windup;
- запускает независимый кулдаун;
- публикует read-only состояние для HUD и визуала;
- не выдаёт монеты напрямую.

Публичное визуальное состояние:

```text
is_operational(buildable_id)
is_firing(buildable_id)
get_shot_progress(buildable_id)
get_cooldown_remaining(buildable_id)
get_target_enemy_id(buildable_id)
```

Смерть проходит через общий поток:

```text
HealthComponent.depleted
→ BoardingEnemy.kill("combat")
→ BoardingEnemyRegistry.enemy_removed
→ BoardingRewardController
→ RunEconomy / RunStatistics
```

### Переназначение и перенос

Во время выстрела поднимается внешний флаг неделимого действия. Оператор завершает текущий выстрел, затем уходит. Новый выстрел в `WAITING_FOR_ACTION` не начинается.

При переносе `BuildableGrid` мгновенно меняет клетку, а оператор физически идёт к новому посту. До прибытия турель не работает.

### Демонтаж

`TurretSystem` отменяет текущий выстрел, снимает внешний флаг, удаляет динамический пост, освобождает оператора и удаляет `TurretRuntime`.

## 11. TurretPresentationDomain

```text
TurretVisualRuntime
TurretVisualController
BuildableBalance
```

### TurretVisualRuntime

Хранит только данные представления:

```text
buildable_id
target_enemy_id
shot_origin_local
last_target_world
tracer_remaining
flash_remaining
```

Эти данные не участвуют в выборе цели, попадании, уроне или кулдауне.

### TurretVisualController

Контроллер подписывается на:

```text
turret_registered
turret_removed
shot_started
shot_completed
shot_cancelled
selected_turret_changed
```

Он рисует:

- полный корпус турели;
- приглушённое состояние без прибывшего оператора;
- зелёный или красный индикатор;
- фактический радиус выбранной турели;
- растущий заряд у дула;
- дугу progress/cooldown;
- краткую отдачу;
- вспышку;
- короткий трассер до последней известной позиции цели.

Если турель перенесена во время подготовки, `shot_origin_local` сохраняет старую позицию. Текущий визуальный выстрел завершается из неё, а новый корпус уже отображается на новой клетке как неактивный.

### Пауза

`TurretVisualController` использует обычный pausable process mode. При карточках или ручной паузе:

- боевые таймеры TurretSystem не меняются;
- flash/tracer runtime не меняется;
- визуальный progress остаётся на прежнем значении.

## 12. Balance

`BuildableBalance` является единственным источником параметров медицинского поста, боя и представления турелей.

```text
max_count = 4
damage = 1
range = 360
shot_windup = 0.45
shot_cooldown = 0.8
flash_duration = 0.10
tracer_duration = 0.14
recoil_distance = 5
inactive_alpha = 0.35
```

## 13. Обязательные тестовые границы

### TurretSystem

- закрытую турель нельзя установить;
- без прибывшего оператора турель не стреляет;
- несколько турелей имеют независимые посты и таймеры;
- успешный выстрел наносит ровно один урон;
- убийство выдаёт обычную физическую награду;
- начатый выстрел завершается перед переназначением;
- перенос во время выстрела ждёт его завершения;
- демонтаж немедленно освобождает оператора;
- карточки замораживают windup и cooldown.

### TurretPresentation

- pivot вычисляется через `TurretGeometry`;
- визуальный runtime сохраняет origin начатого выстрела;
- resolve запускает flash и tracer;
- tick уменьшает только визуальные таймеры;
- cancel полностью очищает визуальный эффект;
- визуальный слой не вызывает `apply_damage`, `add_coins` или `request_assignment`.

### Общие

- здоровье изменяется только через `HealthComponent`;
- UI не владеет стрельбой или назначением;
- карточки и ручная пауза останавливают симуляцию;
- лимит 600 строк не нарушен.

## 14. Следующая итерация

1. Подключение размещаемых объектов к data-driven каталогу карточек.
2. Разные карточки открытия медицинского поста и турелей.
3. Уровни улучшения дальности, скорости и количества турелей.
4. Отделение боевого баланса турели от общего `BuildableBalance`, если каталог начнёт расти.
5. Финальные графические ассеты вместо диагностической векторной отрисовки.

## 15. Запрещённые решения

- Второй владелец занятости клеток.
- Отдельная система ролей только для турелей.
- Один общий оператор для нескольких турелей.
- Хранение клетки турели внутри `TurretRuntime`.
- Прямое начисление монет из `TurretSystem`.
- Прямое удаление врага вместо `HealthComponent.apply_damage()`.
- Перенаправление уже начатого выстрела.
- Работа турели до прибытия оператора.
- Сохранение роли после демонтажа турели.
- Выбор цели или нанесение урона из `TurretVisualController`.
- Использование flash/tracer runtime в симуляции.
- Архитектурное изменение без обновления этого файла.
