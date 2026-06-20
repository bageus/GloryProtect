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
| Стратегические группы | `StrategicWaveSystem` |
| Номер и таймер следующей волны | `StrategicWaveDirector` |
| Параметры стратегических волн | `StrategicWaveBalance` |
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

Stateless-компоненты и представление не дублируют состояние владельцев. `StrategicMinimap` получает только `StrategicGroupSnapshot`, а не изменяемые runtime-объекты.

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

Владеет началом забега, полной паузой и причиной поражения. `CARD_SELECTION` включает `SceneTree.paused`. UI карточек использует `PROCESS_MODE_ALWAYS`, чтобы оставаться доступным во время паузы.

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

Время растёт только в `RUNNING`. Стартовая задержка, карточки, ручная пауза и `GAME_OVER` не увеличивают сложность. Каждый домен применяет собственный ресурс баланса к общему нормализованному значению.

## 7. StrategicWaveDomain

```text
StrategicWaveBalance
StrategicWaveDirector
StrategicWaveSystem
StrategicGroupRuntime
StrategicGroupSnapshot
```

### StrategicWaveBalance

Единственный источник:

```text
first_wave_delay
initial_wave_interval
minimum_wave_interval
initial_wave_size
maximum_wave_size
initial_travel_duration
minimum_travel_duration
initial_target_sections
maximum_target_sections
impact_interval
damage_per_enemy
max_active_groups
maximum_lane_offset
```

Текущие диапазоны:

```text
wave interval: 12 → 4 seconds
wave size: 6 → 30
group travel: 8 → 4 seconds
target sections: 1 → 3
damage per enemy: 1
impact interval: 0.35 seconds
```

### StrategicWaveDirector

Владеет только `_wave_remaining`, `_wave_number` и RNG.

Он:

- читает `RunDifficulty`;
- вычисляет размер, интервал, скорость и число целей через `StrategicWaveBalance`;
- выбирает уникальные секции;
- распределяет реальное количество врагов между группами;
- создаёт группы через `StrategicWaveSystem.add_group()`;
- не двигает группы;
- не наносит урон;
- не изменяет щит.

### StrategicWaveSystem

Единственный владелец `Array[StrategicGroupRuntime]`.

Состояния группы:

```text
TRAVELING
IMPACTING
```

Поток:

```text
Director creates group
    ↓
TRAVELING: progress 0 → 1
    ↓
IMPACTING at assigned shield section
    ↓
one enemy applies damage
    ↓
enemy_count -= 1
    ↓
remove group when enemy_count == 0
```

Урон проходит только через:

```text
ShieldSystem.apply_damage(section_id, damage_per_enemy)
```

Группа сохраняет реальное количество врагов. Визуальная масса уменьшается синхронно с `enemy_count`.

### StrategicGroupSnapshot

Неизменяемое представление для UI:

```text
group_id
section_id
enemy_count
initial_enemy_count
progress
lane_offset
is_impacting
```

Изменяемый `StrategicGroupRuntime` наружу не выдаётся.

### Независимость от физического абордажа

Стратегические враги:

- не создаются как `BoardingEnemy`;
- не имеют `HealthComponent` и `MeleeAttackComponent`;
- не регистрируются в `BoardingEnemyRegistry`;
- не используют якоря;
- не взаимодействуют с экипажем;
- не публикуют физическую причину смерти;
- не дают монет.

## 8. PresentationDomain: StrategicMinimap

```text
StrategicMinimap
scenes/ui/strategic_minimap.tscn
```

Миникарта всегда находится в `CanvasLayer`, независимо от камеры платформы.

Она читает:

- проценты и цвета секций из `ShieldSystem`;
- снимки групп из `StrategicWaveSystem`;
- номер и таймер волны из `StrategicWaveDirector`.

Она отображает:

- пять секций;
- проценты;
- зелёное, оранжевое и мигающее красное состояние;
- движение групп к целям;
- реальное количество внутри массы;
- сокращение массы при ударах;
- номер волны и время до следующей.

Миникарта не меняет щит, группы, таймеры или цели.

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

Награды за физических врагов проходят через:

```text
BoardingEnemyRegistry.enemy_removed
    ↓
BoardingRewardController
    ↓
RunEconomy.add_coins
```

Стратегический домен не подключён к этому потоку.

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

На текущем этапе карточки одинаковы и не применяют эффект. UI только вызывает `choose_card(index)`.

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

`PlatformController` владеет горизонтальной позицией и скоростью. `PlatformVisualController` только отображает платформу, клетки, посты, шар и дверь замены.

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
- `GroundOrbRegistry` публикует координаты, зоны и точки крепления.
- `OrbContactSystem` владеет активным контактом.
- `ShieldSystem` владеет пятью значениями прочности.
- `ShieldRechargeController` восстанавливает только связанную секцию.
- Стратегические удары и зарядка используют публичный интерфейс `ShieldSystem`.

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

`CrewManager` владеет стабильными `defender_id`. `CrewReplacementController` владеет независимыми таймерами. `CrewRoleManager` владеет ролями. `DefenderMovement` владеет целевой координатой.

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

`BoardingSpawnDirector` получает `RunDifficulty` и через `BoardingBalance` вычисляет:

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

Будущая турель наносит физический урон и использует существующий reward flow через причину `combat`.

## 18. Обязательные тестовые границы

### Стратегические волны

- Волны не идут во время `START_DELAY` и полной паузы.
- Одна волна выбирает уникальные секции.
- Сумма врагов в группах равна размеру волны.
- Группа сохраняет реальное количество.
- При `CARD_SELECTION` прогресс не меняется.
- Каждый враг наносит отдельный импульс урона.
- Группа уменьшается после каждого удара.
- Исчерпанная группа удаляется.
- Стратегические враги не дают монет.
- Новый забег очищает группы и номер волны.
- Миникарта постоянно присутствует.

### Сложность

- Начало, середина и максимум дают корректные параметры обоих типов угроз.
- Сложность растёт только в `RUNNING`.
- Новый забег сбрасывает прогресс.

### Остальные системы

- Контакт заряжает только связанную секцию.
- Разрушение секции завершает забег.
- Ноль живых защитников завершает забег.
- Без якорей физический спавн запрещён.
- Физические враги сохраняют минимальные дистанции.
- Лимит 600 строк не нарушен.

## 19. Следующая итерация

1. Визуальное объединение близких стратегических масс.
2. Разделение группы на несколько групп.
3. Перенаправление частей к разным секциям.
4. Общий звуковой сигнал новой критической угрозы.
5. Статистика времени выживания и физических убийств.

Карточки остаются заглушками без различных эффектов.

## 20. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- Второй владелец стратегических групп.
- Движение или урон групп внутри `StrategicWaveDirector`.
- Планирование волн внутри `StrategicWaveSystem`.
- Выдача изменяемого runtime миникарте.
- Создание физического `Node2D` на каждого стратегического врага.
- Регистрация стратегических врагов в `BoardingEnemyRegistry`.
- Начисление монет за стратегических врагов.
- Хардкод параметров волн вне `StrategicWaveBalance`.
- UI как владелец симуляции, монет, сложности или карточек.
- Изменение монет вне `RunEconomy`.
- Дублирование здоровья вне `HealthComponent`.
- Зависимость симуляции от визуала.
- Один большой скрипт для стратегических волн, физического абордажа или UI.
- Архитектурное изменение без обновления этого файла.
