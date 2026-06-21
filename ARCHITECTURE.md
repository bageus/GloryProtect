# GloryProtect — архитектура проекта

Этот файл — единственный источник правды для архитектуры. Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md).

## 1. Основные правила

- Godot 4.6.2 stable, строго типизированный GDScript.
- Максимум 600 строк на поддерживаемый файл; с 450 строк файл оценивается на разделение.
- Каждое изменяемое состояние имеет одного владельца.
- Баланс и определения находятся в типизированных `Resource`.
- UI читает состояние и отправляет команды, но не реализует механику.
- Представление не изменяет симуляцию.
- Архитектурное изменение обновляет этот файл в том же наборе изменений.

## 2. Направление зависимостей

```text
Input / UI
    ↓ команды
Domain systems
    ↓ события и неизменяемые определения
Presentation
```

UI может владеть только состоянием интерфейса, например выбранным защитником. Визуальные компоненты могут хранить только восстановимый кэш и краткоживущие эффекты.

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
│   ├── BoardingEnemyRegistry
│   ├── BoardingMovementResolver
│   ├── BoardingJumpPlanner
│   ├── BoardingSpawnDirector
│   ├── BoardingEnemyContainer
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

`BoardingSpawnDirector` получает каталог типов косвенно через `BoardingBalance`. Сцена не перечисляет конкретные архетипы.

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Состояние забега и пауза | `GameFlowController` |
| Активное время и общая сложность | `RunDifficulty` |
| Монеты | `RunEconomy` |
| Выдача карточек | `UpgradeSystem` |
| Выбранный защитник | `CrewSelectionController` |
| Роли и владельцы постов | `CrewRoleManager` + `RoleStationRegistry` |
| Здоровье сущности | её `HealthComponent` |
| Положение и скорость платформы | `PlatformController` |
| Состояния четырёх якорей | `AnchorRuntimeStore` |
| Прочность четырёх тросов | `AnchorRopeDurability`; значения хранятся в соответствующих `AnchorRuntime` |
| Размещённые объекты и занятость клеток | `BuildableGrid` |
| Текущий цикл лечения | `MedicalStationSystem` |
| Боевой runtime турели | `TurretSystem` через `TurretRuntime` |
| Визуальные эффекты турели | `TurretVisualController` |
| Активные физические враги | `BoardingEnemyRegistry` |
| Состояние конкретного врага | его `BoardingEnemyController` |
| Неизменяемые характеристики типа врага | `BoardingEnemyArchetype` |
| Доступный набор и веса типов | `BoardingEnemyCatalog` |
| Стратегические группы | `StrategicWaveSystem` |
| Статистика забега | `RunStatistics` |

## 5. CrewSelectionDomain

```text
CrewSelectionController
CrewDebugInput
DefenderVisual
```

`CrewSelectionController` владеет `selected_defender_id` и принимает выбор от клавиатуры, портретов и мирового клика. `CrewDebugInput` является совместимой тонкой оболочкой.

`DefenderVisual.set_selected(bool)` только рисует кольцо и не меняет доменное состояние.

## 6. CrewCommandPresentation

```text
CrewCommandPanel
CrewCommandPanelView
CrewCommandText
PrototypeHUD
```

`CrewCommandPanel` читает состояние экипажа и объектов, затем отправляет только:

```text
CrewRoleManager.request_assignment(defender_id, role_id, station_id)
```

Панель не резервирует пост и не меняет `CrewAssignmentRuntime`. `CrewCommandPanelView` создаёт контролы, а `CrewCommandText` форматирует названия и причины отказа.

Большая диагностическая телеметрия скрыта по умолчанию и переключается `F10`.

## 7. PlatformDomain

`PlatformController` является единственным источником геометрии клеток:

```text
get_cell_count()
is_valid_cell(cell_index)
get_cell_local_x(cell_index)
get_nearest_cell_index(local_x)
```

Роли, объекты, медицина и турели не повторяют формулу координаты клетки.

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

`BuildableInventory` владеет открытым количеством. `BuildableGrid` владеет размещёнными экземплярами и занятостью клеток.

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
- демонтаж не удаляет открытие;
- наружу выдаются `BuildableSnapshot`.

## 9. ConcreteRoleStationDomain

Назначение содержит:

```text
current_role
current_station_id
target_role
target_station_id
state
```

Статические посты используют `station_id = -1`. Медицинский пост использует `MEDIC / 0`. Каждая турель использует `TURRET / buildable_id`.

`RoleStationRegistry` хранит владельца и координату по составному ключу `role_id : station_id`.

## 10. Неделимые внешние действия

Лечение и выстрел сообщают менеджеру ролей только общий флаг:

```text
set_external_role_action_active(defender_id, role_id, active)
```

Пока флаг активен, переназначение переходит в `WAITING_FOR_ACTION`. После завершения действия начинается физический переход.

## 11. MedicalStationDomain

`MedicalStationSystem` владеет целью и пятисекундным циклом лечения, но не здоровьем и не ролью.

```text
выбрать наиболее раненую цель
→ добежать
→ 5 секунд контакта
→ HealthComponent.heal(1)
→ повторная оценка
```

При переносе текущий цикл завершается. Демонтаж освобождает роль немедленно.

## 12. BoardingEnemyDefinitionDomain

```text
BoardingEnemyArchetype
BoardingEnemyCatalog
BoardingBalance
resources/enemies/*.tres
```

### BoardingEnemyArchetype

Один ресурс описывает один тип и является единственным источником:

```text
archetype_id
display_name
max_health
body_radius
body_color
accent_color
ground_move_speed
climb_move_speed
platform_move_speed
attack_damage
attack_windup
attack_cooldown
attack_range
unlock_difficulty
weight_at_unlock
weight_at_max_difficulty
```

Ресурс не хранит изменяемое состояние экземпляра.

### BoardingEnemyCatalog

Каталог:

- хранит типизированный массив архетипов;
- проверяет уникальность `archetype_id`;
- возвращает архетип по ID;
- рассчитывает вес для текущей нормализованной сложности;
- выполняет взвешенный выбор через переданный `RandomNumberGenerator`.

При сложности ниже `unlock_difficulty` вес равен нулю.

### Текущие определения

```text
basic  — доступен с 0.00
runner — доступен с 0.15
brute  — доступен с 0.45
```

`BoardingBalance` владеет только общими правилами спавна, разделения, прыжка и боя защитников. Поля группы `Legacy Base Enemy Defaults` временно сохранены для совместимости старых тестовых сценариев и не читаются runtime врага.

## 13. BoardingEnemyRuntimeDomain

```text
BoardingEnemy
BoardingEnemyController
BoardingEnemyRegistry
BoardingSpawnDirector
BoardingMovementResolver
BoardingJumpPlanner
BoardingEnemyVisual
```

### Создание экземпляра

```text
BoardingSpawnDirector
→ BoardingEnemyCatalog.choose_archetype(difficulty)
→ instantiate BoardingEnemy
→ BoardingEnemy.configure(archetype, ...)
→ BoardingEnemyRegistry.register_enemy(enemy)
```

Конфигурация происходит до регистрации, поэтому подписчики `enemy_registered` всегда видят настроенный архетип.

### BoardingEnemy

Хранит ссылку на неизменяемый `archetype` и предоставляет:

```text
get_archetype_id()
get_archetype_name()
get_body_radius()
```

Здоровье остаётся у `HealthComponent`, атака — у `MeleeAttackComponent`, движение и состояния — у `BoardingEnemyController`.

### BoardingEnemyController

Общая машина состояний:

```text
WAITING_WITHOUT_PATH
RUNNING_TO_ANCHOR
CLIMBING
ON_PLATFORM
FIGHTING
JUMPING
DEAD
```

Контроллер не проверяет конкретные ID типов. Он читает скорость и параметры атаки из назначенного архетипа.

### BoardingSpawnDirector

Директор владеет только таймером спавна и RNG. Он не хранит копии характеристик типов.

Для тестов доступны:

```text
spawn_debug_archetype(archetype_id, side)
spawn_debug_on_platform(local_x, archetype_id)
```

### BoardingMovementResolver

Разделение пары врагов:

```text
max(global_minimum_spacing, first.radius + second.radius)
```

Правило применяется на земле, тросе, платформе и при поиске свободной точки. Разделение врага и защитника равно сумме их радиусов.

### BoardingJumpPlanner

Использует радиус прыгающего врага, радиус блокирующего врага и индивидуальную дальность атаки архетипа. Точка приземления резервируется через обычный movement resolver.

### BoardingEnemyVisual

Временная векторная графика читает цвет, акцент и радиус архетипа. Она не участвует в выборе типа, движении, атаке или награде.

### Награды

Все текущие архетипы проходят общий поток смерти:

```text
HealthComponent.depleted
→ BoardingEnemy.kill(reason)
→ BoardingEnemyRegistry.enemy_removed
→ BoardingRewardController
→ RunEconomy / RunStatistics
```

Prototype 2.0 выдаёт одинаковую базовую награду всем физическим типам.

## 14. TurretDomain

Каждая турель имеет отдельный `TurretRuntime`, конкретный пост `TURRET/buildable_id`, оператора, цель, windup и cooldown.

`TurretTargetSelector` атакует физического врага в состояниях:

```text
CLIMBING
ON_PLATFORM
FIGHTING
JUMPING
```

`TurretSystem` наносит урон только через `HealthComponent.apply_damage(1)` и не начисляет монеты напрямую.

`TurretVisualController` рисует корпус, радиус, заряд, кулдаун, отдачу, вспышку и трассер, но не меняет симуляцию.

## 15. Пауза

Во время `CARD_SELECTION` и `MANUAL_PAUSE` мировые таймеры не изменяются.

- при карточках `CrewCommandPanel` скрыт;
- при ручной паузе панель видима, но команды отключены;
- спавн и движение врагов остановлены;
- лечение, атаки, flash и tracer заморожены.

## 16. AnchorRopeDurabilityDomain

```text
AnchorBalance.rope_max_durability
AnchorRuntime.rope_durability
AnchorRopeDurability
AnchorRopeSnapshot
AnchorSystem public API
```

`AnchorRopeDurability` является единственным компонентом, который изменяет прочность тросов. Текущее значение хранится в соответствующем `AnchorRuntime`, чтобы каждый из четырёх якорей имел независимый runtime.

Публичный доступ проходит только через `AnchorSystem`:

```text
apply_rope_damage(anchor_id, amount, source)
get_rope_snapshot(anchor_id)
get_all_rope_snapshots()
```

Правила:

- максимальная прочность находится в типизированном `AnchorBalance`;
- урон принимают только установленные или перегруженные тросы;
- отрицательный и нулевой урон отклоняется;
- прочность ограничивается диапазоном от `0` до максимума;
- новая успешная установка восстанавливает трос до полной прочности;
- перегрузка ветром и повреждение прочности являются независимыми механизмами;
- при достижении нуля публикуется `rope_destroyed(anchor_id, source)` ровно один раз;
- в рамках issue #14 нулевая прочность сама не меняет состояние якоря и не закрывает путь;
- переход в возврат, уничтожение пути, падение врагов и визуальный обрыв принадлежат issue #16;
- UI и враги получают только snapshots и отправляют команды через публичный API.

`AnchorRopeSnapshot` является read-only DTO для UI, diagnostics и тестов. Он содержит текущее значение, максимум, нормализованную долю и признак разрушения.

## 17. Обязательные тестовые границы

### Rope durability

- четыре троса имеют независимую прочность;
- снятый трос не принимает урон;
- урон ограничивается нулём;
- событие разрушения не повторяется после достижения нуля;
- новая установка восстанавливает полную прочность;
- reset забега восстанавливает все четыре шкалы;
- snapshot не даёт внешнему коду изменять runtime;
- достижение нуля до реализации #16 не снимает путь автоматически.

### Enemy catalog

- ID уникальны;
- некорректный каталог не проходит `validate()`;
- типы закрыты до своего порога;
- при нулевой сложности выбирается только базовый тип;
- при максимальной сложности выбираются все доступные типы.

### Enemy instances

- здоровье, радиус и скорости берутся из архетипа;
- быстрый враг проходит большее расстояние за одинаковое время;
- тяжёлый враг имеет три сегмента здоровья;
- реестр считает типы отдельно;
- два крупных врага сохраняют расстояние не меньше суммы радиусов;
- старые сценарии прыжка, боя и тросовой очереди продолжают работать.

### Общие

- здоровье изменяется только через `HealthComponent`;
- UI не владеет боевой логикой;
- стратегические враги не используют физический каталог;
- карточки остаются заглушками;
- лимит 600 строк не нарушен.

## 18. Следующая итерация

1. Добавить маленького врага-взрывателя, который выбирает доступный трос.
2. Взрыв должен вызывать `AnchorSystem.apply_rope_damage(...)`, а не менять runtime напрямую.
3. Разрушение троса должно закрывать путь, сбрасывать поднимающихся врагов и возвращать якорь.
4. Добавить предупреждение и диагностическое состояние повреждённого троса.

Ассеты и карточки остаются отложенными до готовности соответствующей спецификации.

## 19. Запрещённые решения

- Прямое изменение `AnchorRuntime.rope_durability` из врага, UI или presentation.
- Второй владелец прочности троса вне `AnchorRopeDurability`.
- Автоматическое закрытие пути внутри компонента прочности до реализации #16.
- Проверки `archetype_id` внутри общей машины движения и ближнего боя.
- Копирование характеристик архетипа в `BoardingBalance` как активный источник runtime.
- Случайный выбор типа внутри `BoardingEnemy`.
- Разные сцены с дублированной логикой для простых вариантов скорости и здоровья.
- Второй владелец выбранного защитника.
- Прямое изменение `CrewAssignmentRuntime` из UI.
