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

Она не резервирует посты и не изменяет `CrewAssignmentRuntime` напрямую. Диагностическая телеметрия переключается `F10`.

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
BuildableGridVisual
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
→ archetype.instantiate_behavior()
→ behavior.set_context(...)
→ BoardingEnemy.attach_special_behavior(...)
→ BoardingEnemyRegistry.register_enemy(enemy)
```

Специальное поведение подключается до регистрации, поэтому подписчики всегда видят полностью настроенного врага.

### Обычный враг

Без специального behavior движение и бой принадлежат `BoardingEnemyController`:

```text
WAITING_WITHOUT_PATH
RUNNING_TO_ANCHOR
CLIMBING
ON_PLATFORM
FIGHTING
JUMPING
DEAD
```

Контроллер не проверяет конкретные ID типов.

### Специальный враг

`BoardingEnemy.attach_special_behavior()` останавливает обычный controller и melee-компонент. `EnemyBehaviorComponent` сообщает общему runtime:

```text
is_targetable_by_turret()
is_counted_as_ground()
is_counted_as_climbing()
is_counted_as_boarded()
```

Это позволяет registry, турелям и movement resolver работать без знания конкретного специального типа.

`EnemyBehaviorContext` предоставляет только необходимые доменные ссылки: платформу, пути, орбы, movement resolver, якоря и общий boarding balance. Контекст устанавливается до активации behavior.

### Физическое разделение

Расстояние между врагами:

```text
max(global_minimum_spacing, first.radius + second.radius)
```

Наземная фильтрация использует `is_counted_as_ground()`, поэтому специальные наземные враги участвуют в тех же пробках и поиске точки спавна.

### Смерть и награды

```text
HealthComponent.depleted
→ BoardingEnemy.kill(reason)
→ BoardingEnemyRegistry.enemy_removed
→ BoardingRewardController
→ RunEconomy / RunStatistics
```

Награда определяется причиной смерти, а не конкретным классом врага.

## 14. RopeSaboteurDomain

```text
RopeSaboteurArchetype
RopeSaboteurBehavior
RopeSaboteurVisual
resources/enemies/boarding_rope_saboteur.tres
scenes/boarding/rope_saboteur_behavior.tscn
```

`RopeSaboteurBehavior` владеет состояниями:

```text
WAITING_WITHOUT_PATH
→ RUNNING_TO_ROPE
→ ARMING
→ DEAD
```

Правила:

- выбирается ближайший доступный трос с прочностью выше нуля;
- выбранный `anchor_id` фиксируется до закрытия пути или разрушения троса;
- подрывник остаётся наземным врагом и использует обычное ground separation;
- он не поднимается по тросу и не атакует защитников;
- турели могут выбирать его только во время `ARMING`;
- взрыв вызывает только `AnchorSystem.apply_rope_damage(...)`;
- успешный взрыв завершает врага причиной `rope_sabotage` без награды;
- обычное убийство через `HealthComponent` использует `combat` и выдаёт стандартную награду;
- presentation рисует фитиль и кольцо подготовки, но не меняет runtime.

Физический обрыв троса и закрытие пути остаются ответственностью #16.

## 15. TurretDomain

Каждая турель имеет отдельный `TurretRuntime`, пост, оператора, цель, windup и cooldown. `TurretTargetSelector` получает цели из `BoardingEnemyRegistry.get_turret_targets()` и не проверяет state machine или тип врага.

`TurretSystem` наносит урон только через `HealthComponent.apply_damage()` и не начисляет монеты напрямую. `TurretVisualController` не изменяет симуляцию.

## 16. RangedAndStatusCombatDomain

`RangedAttackComponent` владеет фазой, locked target и положением временного projectile runtime:

```text
READY → WINDUP → PROJECTILE → COOLDOWN
```

Фактический урон всегда проходит через целевой `HealthComponent`.

`StatusEffectComponent` находится на цели и владеет стеками, длительностью и таймером яда. Яд не хранит вторую копию здоровья и наносит каждый tick через `HealthComponent.apply_damage()`.

## 17. Пауза

Во время `CARD_SELECTION` и `MANUAL_PAUSE` мировые таймеры не изменяются.

- спавн и движение врагов остановлены;
- обычные и специальные behavior не обновляются;
- подготовка подрывника заморожена;
- лечение, melee, ranged projectile, cooldown и poison остановлены;
- presentation не продвигает gameplay-состояние.

## 18. AnchorRopeDurabilityDomain

```text
AnchorBalance.rope_max_durability
AnchorRuntime.rope_durability
AnchorRopeDurability
AnchorRopeSnapshot
AnchorSystem public API
```

`AnchorRopeDurability` является единственным писателем прочности. Публичный доступ:

```text
apply_rope_damage(anchor_id, amount, source)
get_rope_snapshot(anchor_id)
get_all_rope_snapshots()
```

Урон принимают только установленные или перегруженные тросы. Значение ограничено диапазоном `0..maximum`. Новая успешная установка восстанавливает полную прочность. Перегрузка ветром и повреждение являются независимыми механизмами.

При достижении нуля публикуется `rope_destroyed` один раз. До #16 нулевая прочность сама не закрывает путь. Подрывник уже исключает такой трос из списка целей.

## 19. Обязательные тестовые границы

### Rope durability

- четыре независимые шкалы;
- снятый трос не принимает урон;
- событие разрушения не повторяется;
- новая установка восстанавливает прочность;
- ноль до #16 не закрывает путь автоматически.

### Enemy catalog и runtime

- ID уникальны и определения валидны;
- типы закрыты до порога сложности;
- специальный behavior создаётся из архетипа до регистрации;
- обычные враги продолжают использовать прежний controller;
- registry и турели не зависят от конкретной state machine;
- физическое разделение учитывает радиусы и special ground enemies.

### Rope saboteur

- без пути автоматический spawn невозможен;
- цель фиксируется и меняется только при недоступности;
- подготовка замораживается паузой;
- взрыв повреждает только выбранный трос;
- щит, платформа, экипаж и другие тросы не меняются;
- самоподрыв не выдаёт награду;
- combat-убийство выдаёт обычную награду.

### Общие

- здоровье меняется только через `HealthComponent`;
- UI и presentation не владеют боевой логикой;
- стратегические враги не используют физический каталог;
- лимит 600 строк не нарушен.

## 20. Следующая якорная итерация

Issue #16 должен подписаться на разрушение троса и через существующих владельцев:

1. закрыть boarding-путь;
2. сбросить поднимающихся врагов;
3. перевести якорь в возврат;
4. показать визуальный обрыв и повреждённое состояние.

## 21. Запрещённые решения

- Прямое изменение `AnchorRuntime.rope_durability` из врага, UI или presentation.
- Второй владелец прочности вне `AnchorRopeDurability`.
- Физический обрыв внутри `RopeSaboteurBehavior`.
- Проверки `archetype_id` внутри общей машины движения, registry, турелей или spawn director.
- Специальный controller, дублирующий `EnemyBehaviorComponent` framework.
- Копирование характеристик архетипа в общий balance как активный runtime-источник.
- Случайный выбор типа внутри `BoardingEnemy`.
- Прямое начисление монет из врага или турели.
- Прямое удаление врага вместо общего death pipeline.
- Нанесение урона из визуального слоя.
- Прямое изменение `CrewAssignmentRuntime` из UI.
- Архитектурное изменение без обновления этого файла.
