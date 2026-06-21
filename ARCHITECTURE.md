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

`BoardingSpawnDirector` получает каталог типов косвенно через `BoardingBalance`. Сцена `GameRoot` не перечисляет конкретные архетипы или специализированные сцены врагов.

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
| Состояние конкретного врага | конкретный наследник `BoardingEnemyBehavior` |
| Состояние обычного абордажника | `BoardingEnemyController` |
| Цель и подготовка подрывника | `RopeSaboteurController` |
| Неизменяемые характеристики типа врага | `BoardingEnemyArchetype` или его специализированный наследник |
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
RopeSaboteurArchetype
BoardingEnemyCatalog
BoardingBalance
resources/enemies/*.tres
```

### BoardingEnemyArchetype

Базовый ресурс описывает общие неизменяемые свойства физического типа:

```text
archetype_id
display_name
enemy_scene
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

`enemy_scene` необязателен. Если поле пустое, `BoardingSpawnDirector` использует стандартную сцену обычного абордажника. Специализированный тип может предоставить собственную сцену, сохраняя общий корень `BoardingEnemy`.

Ресурс не хранит изменяемое состояние экземпляра.

### RopeSaboteurArchetype

Наследует базовые поля и добавляет:

```text
rope_damage
arming_duration
```

Определение не выбирает цель и не наносит урон. Оно только предоставляет данные `RopeSaboteurController`.

### BoardingEnemyCatalog

Каталог:

- хранит типизированный массив базовых и специализированных архетипов;
- проверяет уникальность `archetype_id`;
- возвращает архетип по ID;
- рассчитывает вес для текущей нормализованной сложности;
- выполняет взвешенный выбор через переданный `RandomNumberGenerator`.

При сложности ниже `unlock_difficulty` вес равен нулю.

### Текущие определения

```text
basic          — доступен с 0.00
runner         — доступен с 0.15
rope_saboteur  — доступен с 0.25
brute          — доступен с 0.45
```

`BoardingBalance` владеет только общими правилами спавна, разделения, прыжка и боя защитников. Специализированные параметры подрывника находятся в его архетипе.

## 13. BoardingEnemyRuntimeDomain

```text
BoardingEnemy
BoardingEnemyBehavior
BoardingEnemyController
RopeSaboteurController
BoardingEnemyRegistry
BoardingSpawnDirector
BoardingMovementResolver
BoardingJumpPlanner
BoardingEnemyVisual
RopeSaboteurVisual
```

### Создание экземпляра

```text
BoardingSpawnDirector
→ BoardingEnemyCatalog.choose_archetype(difficulty)
→ выбрать archetype.enemy_scene или стандартную сцену
→ instantiate BoardingEnemy
→ BoardingEnemy.configure(archetype, ...)
→ BoardingEnemyRegistry.register_enemy(enemy)
```

Конфигурация происходит до регистрации, поэтому подписчики `enemy_registered` всегда видят настроенный архетип и конкретное поведение.

### BoardingEnemy

Общий корень хранит:

- ссылку на неизменяемый `archetype`;
- `HealthComponent`;
- общий поток смерти;
- ссылку на выбранный `BoardingEnemyBehavior`;
- совместимые запросы registry, movement и turret systems.

`BoardingEnemy` не проверяет `archetype_id` и не выбирает специализированную логику.

### BoardingEnemyBehavior

Это общий контракт поведения, а не вторая машина состояний. Он предоставляет запросы:

```text
get_selected_anchor_id()
get_climb_progress()
get_platform_occupancy_x()
is_grounded_for_limit()
is_climbing()
is_on_platform()
is_fighting()
is_turret_targetable()
```

Registry, movement resolver, visuals и turret selector используют контракт вместо предположения, что каждый враг является обычным абордажником.

### BoardingEnemyController

Обычная машина состояний:

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

### RopeSaboteurController

Отдельная машина состояний:

```text
WAITING_WITHOUT_PATH
RUNNING_TO_ROPE
ARMING
DEAD
```

Правила:

- выбирает ближайший доступный путь через `AnchorPathRegistry`;
- фиксирует `anchor_id` до закрытия выбранного пути;
- при закрытии сбрасывает подготовку и выбирает новую цель;
- участвует в наземном разделении;
- не входит в состояние `CLIMBING`;
- не выходит на платформу и не использует melee;
- во время `ARMING` становится допустимой целью турелей;
- после завершения подготовки вызывает только `AnchorSystem.apply_rope_damage(...)`;
- после успешного урона умирает с причиной `rope_sabotage`.

Controller не изменяет runtime троса напрямую и не выполняет последствия его разрушения.

### BoardingSpawnDirector

Директор владеет только таймером спавна и RNG. Он не хранит копии характеристик типов и не содержит условной ветки подрывника.

Для тестов доступны:

```text
spawn_debug_archetype(archetype_id, side)
spawn_debug_on_platform(local_x, archetype_id)
```

`spawn_debug_on_platform` предназначен для поведений, поддерживающих принудительный выход на платформу. Подрывник эту операцию не использует.

### BoardingMovementResolver

Разделение пары врагов:

```text
max(global_minimum_spacing, first.radius + second.radius)
```

Правило применяется на земле, тросе, платформе и при поиске свободной точки. Тип положения определяется через behavior-контракт. Подрывник участвует только в наземном разделении.

### BoardingJumpPlanner

Использует радиус прыгающего врага, радиус блокирующего врага и индивидуальную дальность атаки архетипа. Точка приземления резервируется через обычный movement resolver.

### Presentation

`BoardingEnemyVisual` рисует обычных абордажников. `RopeSaboteurVisual` рисует компактный корпус, фитиль и кольцо подготовки.

Оба компонента только читают состояние. Визуал подрывника не обновляет таймер и не наносит урон.

### Награды

Все физические типы проходят общий поток смерти:

```text
HealthComponent.depleted или domain action
→ BoardingEnemy.kill(reason)
→ BoardingEnemyRegistry.enemy_removed
→ BoardingRewardController
→ RunEconomy / RunStatistics
```

Причины:

- `combat` — награждаемое физическое убийство;
- `anchor_path_closed` — награждаемое удаление обычного врага с троса;
- `rope_sabotage` — самоподрыв, не выдаёт монеты и не увеличивает счёт убийств игрока.

## 14. TurretDomain

Каждая турель имеет отдельный `TurretRuntime`, конкретный пост `TURRET/buildable_id`, оператора, цель, windup и cooldown.

`TurretTargetSelector` читает `enemy.is_turret_targetable()`:

- обычный абордажник доступен на тросе и платформе;
- подрывник доступен только во время `ARMING` у наземной точки троса.

`TurretSystem` наносит урон только через `HealthComponent.apply_damage(1)` и не начисляет монеты напрямую.

`TurretVisualController` рисует корпус, радиус, заряд, кулдаун, отдачу, вспышку и трассер, но не меняет симуляцию.

## 15. Пауза

Во время `CARD_SELECTION` и `MANUAL_PAUSE` мировые таймеры не изменяются.

- спавн и движение врагов остановлены;
- лечение и атаки заморожены;
- подготовка взрыва подрывника заморожена;
- flash, tracer и диагностическое кольцо не продвигают gameplay;
- при карточках `CrewCommandPanel` скрыт;
- при ручной паузе панель видима, но команды отключены.

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
- нулевая прочность сама пока не меняет состояние якоря и не закрывает путь;
- переход в возврат, уничтожение пути, падение врагов и визуальный обрыв принадлежат issue #16;
- UI и враги получают snapshots или вызывают публичные команды, но не меняют runtime.

`RopeSaboteurController` является первым клиентом API урона и передаёт источник `rope_saboteur`.

## 17. RopeSaboteurDomain

```text
RopeSaboteurArchetype
rope_saboteur_enemy.tscn
RopeSaboteurController
RopeSaboteurVisual
AnchorPathRegistry
AnchorSystem public API
```

Поток:

```text
catalog выбирает rope_saboteur
→ director создаёт специализированную сцену
→ controller выбирает ближайший путь
→ бежит к ground_point
→ ARMING
→ apply_rope_damage
→ kill(rope_sabotage)
```

Граница ответственности:

- каталог и архетип определяют вероятность и параметры;
- controller владеет целью и прогрессом подготовки;
- path registry предоставляет доступные пути;
- anchor domain принимает урон;
- registry и reward controller обрабатывают смерть;
- visual только отображает подготовку;
- issue #16 обрабатывает физическое разрушение троса.

## 18. Обязательные тестовые границы

### Rope durability

- четыре троса имеют независимую прочность;
- снятый трос не принимает урон;
- урон ограничивается нулём;
- событие разрушения не повторяется после достижения нуля;
- новая установка восстанавливает полную прочность;
- reset забега восстанавливает все четыре шкалы;
- snapshot не даёт внешнему коду изменять runtime;
- достижение нуля до реализации #16 не снимает путь автоматически.

### Rope saboteur

- без доступного пути автоматический spawn не создаёт врага;
- специализированный archetype создаёт специализированную сцену;
- ближайший путь фиксируется как цель;
- новый более близкий путь сам по себе не меняет цель;
- закрытие цели вызывает повторный выбор;
- враг не поднимается и не выходит на платформу;
- подготовка замораживается паузой;
- во время подготовки враг доступен турели;
- взрыв повреждает только выбранный трос;
- щит, платформа, экипаж и остальные тросы не меняются;
- `rope_sabotage` не выдаёт награду;
- убийство через `HealthComponent` до взрыва выдаёт обычную награду.

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
- старые сценарии прыжка, боя, турелей и тросовой очереди продолжают работать.

### Общие

- здоровье изменяется только через `HealthComponent`;
- UI не владеет боевой логикой;
- стратегические враги не используют физический каталог;
- карточки остаются заглушками;
- лимит 600 строк не нарушен.

## 19. Следующая итерация

1. Подписать recovery-компонент на `rope_destroyed`.
2. Немедленно закрывать разрушенный путь.
3. Удалять поднимающихся врагов через общий поток смерти.
4. Возвращать якорь и сбрасывать его перегрузку и операции.
5. Добавить повреждённое, критическое и предупреждающее представление троса.

Ассеты и карточки остаются отложенными до готовности соответствующей спецификации.

## 20. Запрещённые решения

- Проверки `archetype_id` внутри `BoardingEnemyController`, movement resolver, turret selector или общего `BoardingEnemy`.
- Добавление логики подрывника как ветки в обычную машину ближнего врага.
- Прямое изменение `AnchorRuntime.rope_durability` из врага, UI или presentation.
- Нанесение взрывом урона щиту, платформе или защитникам.
- Начисление награды за `rope_sabotage`.
- Второй владелец цели или таймера подготовки подрывника вне `RopeSaboteurController`.
- Второй владелец прочности троса вне `AnchorRopeDurability`.
- Автоматическое закрытие пути внутри компонента прочности до реализации #16.
- Копирование характеристик архетипа в `BoardingBalance` как активный источник runtime.
- Случайный выбор типа внутри `BoardingEnemy`.
- Дублирование общей смерти, registry или health logic в специализированной сцене.
- Второй владелец выбранного защитника.
- Прямое изменение `CrewAssignmentRuntime` из UI.
- Резервирование поста кнопкой интерфейса.
- Прямое начисление монет из `TurretSystem`.
- Прямое удаление врага вместо `HealthComponent.apply_damage()` или общего `kill(reason)`.
- Выбор цели или нанесение урона из визуального слоя.
- Архитектурное изменение без обновления этого файла.
