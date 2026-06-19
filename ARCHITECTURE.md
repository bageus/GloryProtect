# GloryProtect — архитектура проекта

Этот файл является **единственным источником правды для архитектуры проекта**.

Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md). Изменение владельцев состояния, границ систем или направления зависимостей должно обновлять этот файл в том же наборе изменений.

---

## 1. База и принципы

- Godot **4.6.2 stable** и GDScript со строгой типизацией.
- Композиция сцен и небольших компонентов.
- Симуляция отделена от UI и визуального слоя.
- Баланс хранится в типизированных `Resource`.
- Максимум 600 строк на поддерживаемый файл; с 450 строк требуется оценка разделения.
- Каждое изменяемое состояние имеет ровно одного владельца.
- UI читает состояние и отправляет команды, но не реализует механику.
- Визуальные компоненты не изменяют доменное состояние.
- Зависимости передаются явно через сцену, `NodePath`, ресурс или небольшой интерфейс.
- Временный прототипный инструмент не может стать источником правды.

---

## 2. Направление зависимостей

```text
Input / UI
    ↓ команды
Domain Systems
    ↓ события и снимки
UI / Visual / Audio
```

Доменные системы могут зависеть от собственных ресурсов, явно переданных ссылок и публичных интерфейсов соседних доменов.

Запрещены зависимости симуляции от HUD, спрайтов, расположения панелей, глубоких путей чужих сцен и универсального глобального менеджера.

---

## 3. Высокоуровневая структура

```text
GameRoot
├── GameFlowDomain
├── InputAdapters
├── ShieldDomain
├── World
│   ├── OrbDomain
│   ├── PlatformDomain
│   ├── AnchorDomain
│   ├── CrewDomain
│   ├── CombatDomain
│   ├── BoardingDomain
│   └── BuildableDomain
├── StrategicSimulation
├── EconomyDomain
└── PresentationDomain
```

`GameRoot` только собирает системы и передаёт зависимости.

---

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Состояние забега и паузы | `GameFlowController` |
| Время активного забега | `RunClock` |
| Направление и сила ветра | `WindSystem` |
| Позиция и скорость платформы | `PlatformController` |
| Доступность рулевого ввода | `SteeringInputProvider`, управляемый `CrewRoleManager` |
| Состояния четырёх якорей | `AnchorRuntimeStore` |
| Очереди операций якорей | `AnchorOperationQueue` |
| Активные маршруты абордажа | вычисляются `AnchorSystem`, публикуются `AnchorPathRegistry` |
| Реестр физических врагов | `BoardingEnemyRegistry` |
| Состояние отдельного врага | его `BoardingEnemyController` |
| Таймер атаки отдельной сущности | её `MeleeAttackComponent` |
| Роли и переходы защитников | `CrewRoleManager` |
| Занятость рабочих постов | `RoleStationRegistry` |
| Реестр защитников | `CrewManager` |
| Здоровье сущности | её `HealthComponent` |
| Активный энергетический контакт | `OrbContactSystem` |
| Прочность пяти секций | `ShieldSystem` |
| Геометрия пяти шаров | `GroundOrbCatalog` через `GroundOrbRegistry` |
| Стратегические группы | `StrategicWaveSystem` |
| Занятость клеток объектами | `BuildableGrid` |
| Монеты забега | `RunEconomy` |
| Цена и выбор улучшений | `UpgradeSystem` |

UI и визуальные узлы могут хранить только восстанавливаемый кэш отображения.

---

## 5. GameFlowDomain

### GameFlowController

Состояния:

```text
BOOT
START_DELAY
RUNNING
CARD_SELECTION
MANUAL_PAUSE
GAME_OVER
```

Владеет началом забега, полной паузой, экраном карточек, завершением и причиной поражения.

### ShieldFailureController

Завершает забег при разрушении любой секции.

### CrewFailureController

Завершает забег при нуле живых защитников.

### RunClock

Планируемый компонент активного времени забега.

---

## 6. PlatformDomain

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

### PlatformController

Владеет горизонтальной позицией и скоростью. Применяет рулевое усилие, ветер, сопротивление, предел скорости, мировые границы и якорные ограничения.

### SteeringInputProvider

Возвращает рулевую ось только при активном рулевом. Одновременное удержание двух направлений считается активным вводом с нулевой осью.

### WindSystem

Владеет направлением, уровнем 1–3, фактическим усилием и расписанием изменений.

### PlatformVisualController

Рисует временную платформу, клетки, посты и шар.

### Ресурсы

- `PlatformBalance` — размеры, посты, силы движения и границы.
- `WindBalance` — уровни ветра, интервалы и колебания.

---

## 7. OrbDomain и ShieldDomain

```text
GroundOrbCatalog
GroundOrbRegistry
OrbContactSystem
GroundOrbVisualController

ShieldBalance
ShieldSystem
ShieldRechargeController
ShieldFailureController
ShieldDebugInput
```

- `GroundOrbCatalog` — пять позиций, высота земли и контактная геометрия.
- `GroundOrbRegistry` — запросы координат, зон и точек крепления.
- `OrbContactSystem` — единственный владелец активного контакта.
- `ShieldSystem` — единственный владелец прочности пяти секций.
- `ShieldRechargeController` — преобразует контакт в восстановление.
- `GroundOrbVisualController` — только отображение.

---

## 8. AnchorDomain

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

- `AnchorSystem` — координатор и публичный фасад.
- `AnchorRuntimeStore` — состояния якорей и привязка к шару.
- `AnchorCommandController` — проверка команд.
- `AnchorOperationQueue` — текущая установка и очередь.
- `AnchorGeometry` — точки, конечная длина и границы.
- `AnchorConstraintProvider` — диапазон платформы.
- `AnchorOverloadController` — перегрузка и срыв.
- `AnchorVisualController` — отображение.

### Публичная граница для абордажа

`AnchorSystem` создаёт неизменяемый `AnchorPathSnapshot`:

```text
anchor_id
side
orb_id
ground_point
platform_point
```

BoardingDomain не получает доступ к внутреннему `AnchorRuntimeStore`.

---

## 9. CrewDomain

```text
CrewManager
CrewRoleManager
RoleStationRegistry
CrewCombatCoordinator

Defender
├── HealthComponent
├── DefenderMovement
├── MeleeAttackComponent
├── DefenderCombatController
└── DefenderVisual
```

### CrewManager

Владеет реестром защитников и предоставляет живых либо ближайшего живого защитника.

### CrewRoleManager

Владеет текущей ролью, целевой ролью и состоянием перехода:

```text
ACTIVE
WAITING_FOR_ACTION
MOVING
DEAD
```

Переход ждёт:

- отпускания рулевого ввода;
- завершения текущей установки якоря;
- завершения начатого взмаха;
- уничтожения врагов, находящихся непосредственно рядом с защитником.

Защитник с ожидающей командой не ищет дальние цели. После очистки непосредственной зоны он начинает переход.

### RoleStationRegistry

Владеет резервированием постоянных постов.

### CrewCombatCoordinator

Передаёт защитникам зависимости боя, собственного состояния не хранит.

### DefenderCombatController

- Рулевой не использует меч.
- Якорщик сражается только возле поста.
- Свободный защитник может выбирать любую цель на платформе.
- При ожидающем переназначении обрабатываются только враги в непосредственном радиусе.
- Полное преследование далёкой цели свободным защитником пока не реализовано.

---

## 10. CombatDomain

```text
HealthComponent
MeleeAttackComponent
DefenderCombatController
BoardingEnemyController
```

### MeleeAttackComponent

Владеет фазами:

```text
READY
WINDUP
COOLDOWN
```

Правила:

- цель фиксируется в начале взмаха;
- начатый удар не перенаправляется;
- погибшая цель превращает удар в промах;
- урон применяется через `HealthComponent`;
- защитник атакует быстрее базового врага.

---

## 11. BoardingDomain

```text
AnchorPathRegistry
BoardingSpawnDirector
BoardingEnemyRegistry
BoardingEnemyContainer

BoardingEnemy
├── HealthComponent
├── MeleeAttackComponent
├── BoardingEnemyController
└── BoardingEnemyVisual
```

### AnchorPathRegistry

Читает публичные снимки якорей, публикует открытие и закрытие маршрута и выбирает ближайший путь. При приблизительном равенстве выбор случайный.

### BoardingSpawnDirector

- Не создаёт новых врагов без якорей.
- Выбирает сторону независимо 50/50.
- Ограничивает количество врагов, которые ещё находятся на земле.
- Враги на тросах и платформе не занимают наземный лимит.
- Использует `BoardingBalance`.

### BoardingEnemyRegistry

Владеет реестром врагов и отдельно считает наземных, карабкающихся и поднявшихся.

### BoardingEnemyController

Состояния:

```text
WAITING_WITHOUT_PATH
RUNNING_TO_ANCHOR
CLIMBING
ON_PLATFORM
FIGHTING
DEAD
```

Правила:

- враг выбирает ближайший путь и фиксирует его;
- новый более близкий якорь не меняет цель;
- закрытие пути на земле заставляет выбрать другой;
- закрытие пути во время подъёма убивает врага;
- поднявшийся враг переживает снятие якоря;
- без пути враг следует по земле за платформой и безвреден;
- на платформе атакует ближайшего живого защитника.

### Пока не реализовано

- физическое разделение и пробки;
- минимальная дистанция на тросе;
- прыжок через защитника;
- типы врагов;
- монеты за убийства;
- рост наземного лимита от сложности.

---

## 12. StrategicWaveDomain

Планируются `StrategicWaveDirector`, `StrategicWaveSystem` и `MinimapRenderer`. Стратегические враги будут агрегированными данными.

---

## 13. BuildableDomain

Планируются `BuildableInventory`, `BuildableGrid`, `MedicalStationSystem` и `TurretSystem`.

---

## 14. EconomyDomain

- `RunEconomy` — монеты забега.
- `UpgradeSystem` — стоимость и выбор карточек.
- `UpgradeCatalog` — data-driven определения.

---

## 15. PresentationDomain

HUD, миникарта, указатели, визуалы, анимации, звук и эффекты. Presentation не изменяет доменное состояние.

---

## 16. Ресурсы данных

```text
resources/balance/
├── platform_balance.tres
├── wind_balance.tres
├── anchor_balance.tres
├── crew_balance.tres
├── shield_balance.tres
├── boarding_balance.tres
├── turret_balance.tres
└── difficulty_curve.tres

resources/definitions/
├── ground_orb_catalog.tres
├── enemies/
├── upgrades/
├── roles/
└── buildables/
```

---

## 17. Обязательные тестовые границы

- контакт заряжает только связанную секцию;
- разрушение секции завершает забег;
- ноль живых защитников завершает забег;
- конечная длина троса работает в обе стороны;
- без якорей физический спавн запрещён;
- наземный лимит не включает поднявшихся врагов;
- враг фиксирует маршрут;
- снятие убивает врага на тросе;
- поднявшийся враг переживает снятие;
- враг атакует ближайшего защитника;
- начатый удар не перенаправляется;
- защитник с ожидающей командой очищает непосредственную зону;
- лимит 600 строк не нарушен.

---

## 18. Следующая итерация

1. независимые таймеры замены защитников;
2. движение свободного защитника к ближайшему врагу;
3. физическое разделение врагов;
4. массовый подъём по одному тросу;
5. прыжок через защитника;
6. монеты за физические убийства;
7. начало стратегических волн.

---

## 19. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец игровых данных.
- Дублирование роли вне `CrewRoleManager`.
- Доступ BoardingDomain к `AnchorRuntimeStore`.
- Дублирование здоровья вне `HealthComponent`.
- Дублирование геометрии шаров вне `GroundOrbCatalog`.
- Дублирование прочности секций вне `ShieldSystem`.
- Зависимость симуляции от визуала.
- Один большой скрипт для ролей, врагов или карточек.
- Балансные значения, разбросанные по логике.
- Архитектурное изменение без обновления этого файла.
