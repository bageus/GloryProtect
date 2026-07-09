# GloryProtect — архитектура проекта

Этот файл — единый источник правды для архитектуры. Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md). Подробные игровые правила вынесены в `docs/rules`.

## 1. Основные правила

- Godot 4.6.2 stable, строго типизированный GDScript.
- Максимум 600 строк на поддерживаемый файл; с 450 строк файл оценивается на разделение.
- Каждое изменяемое состояние имеет одного владельца.
- Баланс и неизменяемые определения находятся в типизированных `Resource`.
- UI читает состояние и отправляет команды, но не реализует механику.
- Presentation не изменяет симуляцию.
- Архитектурное изменение обновляет этот файл в том же наборе изменений.

## 2. Направление зависимостей

```text
Input / UI
    ↓ команды
Domain systems
    ↓ события и read-only данные
Presentation
```

UI может владеть только состоянием интерфейса. Визуальные компоненты могут хранить восстановимый кэш и краткоживущие эффекты.

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
├── CrewSelectionController
├── Input adapters
├── World
│   ├── OrbDomain
│   ├── StrategicWaveDomain
│   ├── AnchorDomain
│   ├── AnchorPathRegistry
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
│       ├── PlatformUpgradeAssetOverlay
│       ├── BuildableGridVisual
│       ├── CrewManager
│       ├── CrewRoleManager
│       └── Camera2D
└── CanvasLayer
    ├── PrototypeHUD
    ├── StrategicMinimap
    ├── UpgradeSelectionPanel
    └── GameOverPanel
```

`BoardingSpawnDirector` получает каталог типов через `BoardingBalance`. Сцена не перечисляет конкретные архетипы и не содержит веток по их ID.

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
| Прочность четырёх тросов | `AnchorRopeDurability` |
| Физические последствия разрушения троса | `AnchorBreakRecoveryController` |
| Размещённые объекты и занятость клеток | `BuildableGrid` |
| Текущий цикл лечения | `MedicalStationSystem` |
| Боевой runtime турели | `TurretSystem` через `TurretRuntime` |
| Активные физические враги | `BoardingEnemyRegistry` |
| Обычное состояние абордажника | его `BoardingEnemyController` |
| Специальное состояние врага | подключённый `EnemyBehaviorComponent` |
| Состояние подрывника троса | его `RopeSaboteurBehavior` |
| Неизменяемые характеристики типа | `BoardingEnemyArchetype` или подкласс |
| Доступный набор и веса типов | `BoardingEnemyCatalog` |
| Фаза дальнего выстрела | `RangedAttackComponent` |
| Яд на защитнике | его `StatusEffectComponent` |
| Стратегические группы | `StrategicWaveSystem` |
| Статистика забега | `RunStatistics` |

## 5. CrewSelectionDomain

`CrewSelectionController` владеет `selected_defender_id` и принимает выбор от клавиатуры, портретов и мирового клика. `DefenderVisual.set_selected(bool)` только рисует выделение.

## 6. CrewCommandPresentation

```text
CrewCommandPanel
CrewCommandPanelView
CrewCommandText
PrototypeHUD
```

Панель читает состояние и отправляет только доменные запросы, например:

```text
CrewRoleManager.request_assignment(defender_id, role_id, station_id)
```

Она не резервирует посты и не изменяет `CrewAssignmentRuntime` напрямую. `PrototypeHUD` не показывает общий диагностический оверлей подсказок; допустима только контекстная подсказка мгновенного снятия якорей, когда соответствующее улучшение активно.

## 7. PlatformDomain

`PlatformController` является единственным источником геометрии клеток:

```text
get_cell_count()
is_valid_cell(cell_index)
get_cell_local_x(cell_index)
get_nearest_cell_index(local_x)
```

Роли, объекты, медицина и турели не повторяют формулу координаты клетки.

### 7.1 PlatformUpgradePresentation

`PlatformUpgradeAssetOverlay` является единым владельцем визуального слоя улучшений платформы: ядро, ускорители, рулевой привод, стабилизаторы и компенсатор ветра. Он читает read-only состояние из доменных систем и рисует восстановимые visuals; он не изменяет симуляцию и не хранит отдельную копию runtime-улучшений.

Новый platform upgrade asset добавляется в этот общий overlay через один asset id, одну проверку видимости, один draw path и один integration guard. Отдельные `Node2D`-визуалы, z-index-слои или presentation controllers для того же класса platform upgrade assets запрещены без нового архитектурного раздела и обоснования владельца.

Специализированные подклассы overlay могут менять layout уже поддержанных ассетов, но не должны вводить второй pipeline отрисовки для новых platform upgrade assets.

## 8. BuildableDomain

```text
BuildableType
BuildableBalance
BuildableRuntime
BuildableSnapshot
BuildableInventory
BuildableGrid
```

`BuildableInventory` владеет открытым количеством. `BuildableGrid` владеет размещёнными экземплярами и занятостью клеток.

```text
place(type_id, cell_index)
move(buildable_id, cell_index)
demolish(buildable_id)
```

Одна клетка содержит максимум один объект. Персонажи не блокируют установку, объекты не создают коллизий, демонтаж не удаляет открытие, наружу выдаются snapshots.

## 9. ConcreteRoleStationDomain

Назначение содержит текущую и целевую роль, текущий и целевой `station_id`, а также состояние перехода. Статические посты используют `station_id = -1`, медицинский пост — `MEDIC / 0`, каждая турель — `TURRET / buildable_id`.

`RoleStationRegistry` хранит владельца и координату по составному ключу `role_id : station_id`.

## 10. Неделимые внешние действия

Лечение и выстрел сообщают менеджеру ролей общий флаг:

```text
set_external_role_action_active(defender_id, role_id, active)
```

Пока флаг активен, переназначение ожидает завершения текущего неделимого действия.

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

`BoardingEnemyArchetype` является неизменяемым определением типа. Он задаёт ID, отображаемое имя, здоровье, радиус, скорости, обычные параметры атаки, диагностические цвета, порог открытия, веса спавна и необязательную `behavior_scene`.

`behavior_scene` создаёт `EnemyBehaviorComponent`. Обычные архетипы оставляют поле пустым и используют `BoardingEnemyController`.

`BoardingEnemyCatalog`:

- проверяет уникальность ID и валидность ресурсов;
- возвращает определение по ID;
- рассчитывает вес по нормализованной сложности;
- выполняет взвешенный выбор через переданный RNG.

Текущие определения:

```text
basic          — доступен с 0.00
runner         — доступен с 0.15
rope_saboteur  — доступен с 0.25
brute          — доступен с 0.45
```

`BoardingBalance` владеет только общими правилами спавна, разделения, прыжка и боя защитников.

## 13. BoardingEnemyRuntimeDomain

```text
BoardingEnemy
BoardingEnemyController
EnemyBehaviorComponent
EnemyBehaviorContext
```
