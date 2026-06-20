# GloryProtect — архитектура проекта

Этот файл — **единственный источник правды для архитектуры проекта**. Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md). Изменение владельцев состояния, границ систем или направления зависимостей должно обновлять этот файл в том же наборе изменений.

## 1. Базовые принципы

- Godot **4.6.2 stable**, строго типизированный GDScript.
- Композиция небольших сцен и компонентов.
- Максимум 600 строк на поддерживаемый файл; с 450 строк файл оценивается на разделение.
- Каждое изменяемое состояние имеет одного владельца.
- Баланс хранится в типизированных `Resource`.
- UI читает состояние и отправляет команды, но не реализует механику.
- Визуальные компоненты не изменяют доменное состояние.
- Зависимости передаются явно через сцену, `NodePath`, ресурс или небольшой интерфейс.

## 2. Направление зависимостей

```text
Input / UI
    ↓ команды
Domain Systems
    ↓ события и снимки
Presentation
```

Доменные системы не зависят от HUD, спрайтов, расположения панелей или универсального глобального менеджера.

## 3. Высокоуровневая композиция

```text
GameRoot
├── GameFlowController
├── RunDifficulty
├── RunEconomy
├── UpgradeSystem
├── InputAdapters
├── ShieldDomain
├── CrewReplacementController
├── World
│   ├── OrbDomain
│   ├── StrategicWaveSystem
│   ├── StrategicWaveDirector
│   ├── StrategicGroupMutationController
│   ├── PlatformDomain
│   ├── AnchorDomain
│   ├── CrewDomain
│   ├── CombatDomain
│   ├── BoardingDomain
│   ├── BoardingRewardController
│   └── BuildableDomain
└── CanvasLayer
    ├── PrototypeHUD
    ├── StrategicMinimap
    └── UpgradeSelectionPanel
```

`GameRoot` только собирает системы и передаёт зависимости.

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Забег и пауза | `GameFlowController` |
| Активное время и нормализованная сложность | `RunDifficulty` |
| Кривая общей сложности | `RunDifficultyBalance` |
| Монеты забега | `RunEconomy` |
| Число покупок и открытая выдача | `UpgradeSystem` |
| Формула стоимости карточек | `UpgradeBalance` |
| Массив стратегических групп | `StrategicWaveSystem` |
| Положение и маршрут стратегической группы | её `StrategicGroupRuntime`, внутри `StrategicWaveSystem` |
| Номер и таймер следующей волны | `StrategicWaveDirector` |
| Таймер проверки мутаций и RNG решений | `StrategicGroupMutationController` |
| Параметры стратегических волн и мутаций | `StrategicWaveBalance` |
| Ветер | `WindSystem` |
| Позиция и скорость платформы | `PlatformController` |
| Доступность рулевого ввода | `SteeringInputProvider`, управляемый `CrewRoleManager` |
| Состояния якорей | `AnchorRuntimeStore` |
| Очереди операций якорей | `AnchorOperationQueue` |
| Активные пути абордажа | вычисляет `AnchorSystem`, публикует `AnchorPathRegistry` |
| Реестр физических врагов | `BoardingEnemyRegistry` |
| Состояние и координаты физического врага | его `BoardingEnemyController` |
| Координаты защитника | `DefenderMovement` |
| Здоровье сущности | её `HealthComponent` |
| Таймер атаки | её `MeleeAttackComponent` |
| Слоты экипажа | `CrewManager` |
| Роли и переходы | `CrewRoleManager` |
| Занятость постов | `RoleStationRegistry` |
| Кулдауны замен | `CrewReplacementController` |
| Энергетический контакт | `OrbContactSystem` |
| Пять значений щита | `ShieldSystem` |
| Геометрия шаров | `GroundOrbCatalog` через `GroundOrbRegistry` |
| Занятость клеток объектами | будущий `BuildableGrid` |

Контроллеры решений и представление не дублируют состояние владельцев. `StrategicGroupMutationController` читает снимки и отправляет команды, а `StrategicMinimap` получает только `StrategicGroupSnapshot`.

## 5. GameFlowDomain

### GameFlowController

```text
BOOT
START_DELAY
RUNNING
CARD_SELECTION
MANUAL_PAUSE
GAME_OVER
```

Владеет началом забега, полной паузой и причиной поражения. `CARD_SELECTION` включает `SceneTree.paused`. UI карточек использует `PROCESS_MODE_ALWAYS`.

### Контроллеры поражения

- `ShieldFailureController` завершает забег при разрушении любой секции.
- `CrewFailureController` завершает забег при нуле живых защитников, даже если идут кулдауны замен.

## 6. DifficultyDomain

```text
RunDifficultyBalance
RunDifficulty
```

`RunDifficultyBalance` преобразует активное время в `0.0…1.0` через `seconds_to_max_difficulty` и `growth_exponent`.

`RunDifficulty` владеет `_elapsed_seconds` и `_normalized_difficulty`.

```text
get_elapsed_seconds()
get_normalized()
get_percent()
reset_for_run()
```

Время растёт только в `RUNNING`. Стартовая задержка, карточки, ручная пауза и `GAME_OVER` не увеличивают сложность. Каждый домен применяет собственный ресурс баланса к общему значению.

## 7. StrategicWaveDomain

```text
StrategicWaveBalance
StrategicWaveDirector
StrategicWaveSystem
StrategicGroupMutationController
StrategicGroupRuntime
StrategicGroupSnapshot
```

### StrategicWaveBalance

Единственный источник параметров создания, движения, ударов и мутаций:

```text
first_wave_delay
initial/minimum_wave_interval
initial/maximum_wave_size
initial/minimum_travel_duration
initial/maximum_target_sections
impact_interval
damage_per_enemy
max_active_groups
maximum_lane_offset
mutation_check_interval
merge_angle_tolerance
merge_distance_tolerance
mutation_cooldown
minimum_split_enemy_count
maximum_split_parts
initial/maximum_split_chance
split_redirect_chance
split_min/max_progress
```

Текущие диапазоны:

```text
wave interval: 12 → 4 seconds
wave size: 6 → 30
group travel: 8 → 4 seconds
target sections: 1 → 3
split chance per check: 4% → 22%
mutation cooldown: 2 seconds
```

### StrategicWaveDirector

Владеет только `_wave_remaining`, `_wave_number` и RNG новой волны.

Он:

- читает `RunDifficulty`;
- вычисляет параметры через `StrategicWaveBalance`;
- выбирает уникальные секции;
- распределяет реальное количество врагов;
- вызывает `StrategicWaveSystem.add_group()`;
- не двигает и не мутирует группы;
- не наносит урон.

### StrategicGroupRuntime

Хранит доменное состояние одной агрегированной группы:

```text
group_id
section_id
enemy_count
initial_enemy_count
state
map_angle
map_distance
route_start_angle
route_start_distance
route_target_angle
route_elapsed
travel_duration
impact_remaining
mutation_cooldown_remaining
```

`map_distance` равен `1.0` на внешнем краю и `0.0` у щита. Положение принадлежит симуляции, а не миникарте.

`replan_route()` создаёт новый плавный маршрут из фактической текущей точки. Это используется после слияния и перенаправленного разделения.

### StrategicWaveSystem

Единственный владелец `Array[StrategicGroupRuntime]`.

Публичные атомарные операции:

```text
add_group()
merge_groups()
split_group()
get_group_snapshots()
reset_for_run()
```

Обычный поток:

```text
Director creates group
    ↓
TRAVELING: map_distance 1 → 0
    ↓
IMPACTING at assigned section
    ↓
one enemy applies damage
    ↓
enemy_count -= 1
    ↓
remove group at zero
```

Урон проходит только через:

```text
ShieldSystem.apply_damage(section_id, damage_per_enemy)
```

### Объединение

`merge_groups(first_id, second_id)` допускает только две движущиеся группы с завершённым кулдауном.

- Более крупная группа становится выжившей.
- Сохраняется её секция.
- Количество и `initial_enemy_count` суммируются.
- Угол, расстояние и оставшееся время усредняются с весом по количеству врагов.
- Поглощённая группа удаляется.
- Общее количество врагов остаётся неизменным.

### Разделение

`split_group(source_id, target_sections, enemy_counts)` проверяет:

- минимум две части;
- одинаковую длину массивов;
- положительное количество каждой части;
- валидность секций;
- наличие свободных слотов;
- точное равенство суммы исходной группе.

Исходная группа удаляется, а части создаются в одной `map_angle/map_distance`. Каждая часть строит маршрут от точки разделения к своей секции.

### StrategicGroupMutationController

Владеет только таймером проверки и RNG решения.

За одну проверку:

1. читает снимки;
2. ищет ближайшую допустимую пару;
3. при наличии вызывает `merge_groups()`;
4. иначе выполняет вероятностную проверку разделения;
5. выбирает 2–3 части и их количества;
6. сохраняет первую цель;
7. дополнительные части могут получить другие секции;
8. вызывает `split_group()`.

Контроллер не хранит ссылки на runtime-группы и не изменяет их поля напрямую. Вне `RUNNING` мутации запрещены.

### StrategicGroupSnapshot

Неизменяемое представление:

```text
group_id
section_id
enemy_count
initial_enemy_count
progress
map_angle
map_distance
is_impacting
mutation_ready
```

Изменяемый runtime наружу не выдаётся.

### Независимость от физического абордажа

Стратегические враги:

- не создаются как `BoardingEnemy`;
- не имеют `HealthComponent` и `MeleeAttackComponent`;
- не регистрируются в `BoardingEnemyRegistry`;
- не используют якоря;
- не взаимодействуют с экипажем;
- не дают монет.

## 8. PresentationDomain: StrategicMinimap

```text
StrategicMinimap
scenes/ui/strategic_minimap.tscn
```

Миникарта находится в `CanvasLayer` и читает:

- секции из `ShieldSystem`;
- снимки групп из `StrategicWaveSystem`;
- номер и таймер из `StrategicWaveDirector`.

Она преобразует `map_angle/map_distance` в экранную позицию. Поэтому слияние увеличивает одну массу, а разделённые части сначала совпадают и затем плавно расходятся.

Миникарта не меняет щит, группы, маршруты, таймеры или цели.

## 9. EconomyDomain

```text
EconomyBalance
RunEconomy
BoardingRewardController
```

`RunEconomy` — единственный владелец монет.

```text
get_coins()
can_afford(cost)
add_coins(amount, source)
spend_coins(cost, source)
reset_for_run()
```

Награды за физических врагов проходят через `BoardingEnemyRegistry.enemy_removed → BoardingRewardController → RunEconomy`. Стратегический домен к этому потоку не подключён.

## 10. UpgradeDomain

```text
UpgradeBalance
UpgradeSystem
UpgradeSelectionPanel
```

`UpgradeSystem` владеет количеством покупок и открытой выдачей. `UpgradeBalance` владеет формулой стоимости.

```text
5, 10, 15, …, 100, 200, 400, 800
```

Карточки одинаковы и не применяют эффект. UI только вызывает `choose_card(index)`.

## 11. PlatformDomain

```text
Platform
├── PlatformController
├── PlatformVisualController
├── CrewManager
├── CrewRoleManager
└── Camera2D

GameRoot
├── SteeringInputProvider
└── WindSystem
```

`PlatformController` владеет горизонтальной позицией и скоростью. `PlatformVisualController` только отображает платформу.

## 12. OrbDomain и ShieldDomain

```text
GroundOrbCatalog
GroundOrbRegistry
OrbContactSystem
GroundOrbVisualController
ShieldBalance
ShieldSystem
ShieldRechargeController
ShieldFailureController
```

- `GroundOrbCatalog` хранит позиции и контактную геометрию.
- `OrbContactSystem` владеет активным контактом.
- `ShieldSystem` владеет пятью значениями прочности.
- Зарядка и стратегические удары используют публичный интерфейс `ShieldSystem`.

## 13. AnchorDomain

```text
AnchorSystem
├── AnchorRuntimeStore
├── AnchorCommandController
├── AnchorOperationQueue
├── AnchorConstraintProvider
├── AnchorOverloadController
├── AnchorGeometry
└── AnchorVisualController
```

BoardingDomain получает только `AnchorPathSnapshot`. Внутренний store наружу не раскрывается.

## 14. CrewDomain

```text
CrewManager
CrewRoleManager
RoleStationRegistry
CrewCombatCoordinator
CrewReplacementController

Defender
├── HealthComponent
├── DefenderMovement
├── MeleeAttackComponent
├── DefenderCombatController
└── DefenderVisual
```

`CrewManager` владеет стабильными `defender_id`. `CrewReplacementController` владеет таймерами замен. `CrewRoleManager` владеет ролями. `DefenderMovement` владеет целевой координатой.

## 15. CombatDomain

```text
HealthComponent
MeleeAttackComponent
DefenderCombatController
BoardingEnemyController
```

Цель фиксируется в начале взмаха. Начатая атака не перенаправляется. Боевые компоненты не начисляют монеты напрямую.

## 16. BoardingDomain

```text
AnchorPathRegistry
BoardingSpawnDirector
BoardingEnemyRegistry
BoardingMovementResolver
BoardingJumpPlanner
BoardingEnemyContainer
```

`BoardingSpawnDirector` через `BoardingBalance` вычисляет:

```text
ground limit: 8 → 20
spawn interval: 3.0 → 0.8 seconds
```

`BoardingEnemyRegistry` хранит только физических врагов. `BoardingMovementResolver` разделяет физические сущности. `BoardingJumpPlanner` создаёт план условного прыжка.

## 17. BuildableDomain

Планируются:

```text
BuildableInventory
BuildableGrid
MedicalStationSystem
TurretSystem
```

Будущая турель наносит физический урон и использует reward flow через причину `combat`.

## 18. Обязательные тестовые границы

### Стратегические мутации

- Мутации выполняются только в `RUNNING`.
- За проверку выполняется максимум одна операция.
- Две близкие группы объединяются в одну.
- Сумма врагов при объединении не меняется.
- Разделение создаёт 2–3 положительные части.
- Сумма частей равна исходной группе.
- Все части начинают в одной точке.
- Хотя бы одна часть может получить другую секцию.
- Перенаправление не создаёт телепорта.
- Кулдаун блокирует немедленную повторную мутацию.
- Таймер проверки останавливается при `CARD_SELECTION`.

### Стратегические волны

- Волны не идут во время `START_DELAY` и полной паузы.
- Сумма врагов в группах равна размеру волны.
- Каждый враг наносит отдельный импульс урона.
- Исчерпанная группа удаляется.
- Стратегические враги не дают монет.
- Новый забег очищает группы, номер волны и таймер мутаций.

### Остальные системы

- Сложность растёт только в `RUNNING`.
- Контакт заряжает только связанную секцию.
- Разрушение секции завершает забег.
- Ноль живых защитников завершает забег.
- Без якорей физический спавн запрещён.
- Лимит 600 строк не нарушен.

## 19. Следующая итерация

1. `RunStatistics` как владелец времени выживания и физических убийств.
2. Итоговый экран забега.
3. Звуковой сигнал новой критической секции.
4. История лучших результатов текущего запуска.
5. Подготовка точек расширения лекаря и турелей.

Карточки остаются заглушками без различных эффектов.

## 20. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- Второй владелец стратегических групп или их положения.
- Прямое изменение runtime-полей из `StrategicGroupMutationController`.
- Решение о мутации внутри миникарты.
- Движение, мутации или урон групп внутри `StrategicWaveDirector`.
- Планирование волн внутри `StrategicWaveSystem`.
- Выдача изменяемого runtime представлению.
- Потеря или создание врагов при слиянии и разделении.
- Создание физического `Node2D` на каждого стратегического врага.
- Регистрация стратегических врагов в `BoardingEnemyRegistry`.
- Начисление монет за стратегических врагов.
- Хардкод параметров волн или мутаций вне `StrategicWaveBalance`.
- UI как владелец симуляции, монет, сложности или карточек.
- Зависимость симуляции от визуала.
- Один большой скрипт для всех стратегических обязанностей.
- Архитектурное изменение без обновления этого файла.
