# GloryProtect — архитектура проекта

Этот файл является **единственным источником правды для архитектуры проекта**.

Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md). Изменение владельцев состояния, границ систем или направления зависимостей должно обновлять этот файл в том же наборе изменений.

---

## 1. База и принципы

- Godot **4.6.2 stable**.
- Строго типизированный GDScript.
- Композиция небольших сцен и компонентов.
- Максимум 600 строк на поддерживаемый файл.
- С 450 строк требуется оценка разделения.
- Каждое изменяемое состояние имеет одного владельца.
- Баланс хранится в типизированных `Resource`.
- UI читает состояние и отправляет команды, но не реализует механику.
- Визуальные компоненты не изменяют доменное состояние.
- Зависимости передаются явно через сцену, `NodePath`, ресурс или небольшой публичный интерфейс.

---

## 2. Направление зависимостей

```text
Input / UI
    ↓ команды
Domain Systems
    ↓ события и снимки
Presentation
```

Доменные системы не зависят от HUD, спрайтов, расположения панелей и универсального глобального менеджера.

---

## 3. Высокоуровневая композиция

```text
GameRoot
├── GameFlowDomain
├── InputAdapters
├── ShieldDomain
├── CrewReplacementController
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
| Направление и сила ветра | `WindSystem` |
| Позиция и скорость платформы | `PlatformController` |
| Доступность рулевого ввода | `SteeringInputProvider`, управляемый `CrewRoleManager` |
| Состояния четырёх якорей | `AnchorRuntimeStore` |
| Очереди операций якорей | `AnchorOperationQueue` |
| Активные пути абордажа | вычисляет `AnchorSystem`, публикует `AnchorPathRegistry` |
| Реестр физических врагов | `BoardingEnemyRegistry` |
| Состояние отдельного врага | его `BoardingEnemyController` |
| Здоровье сущности | её `HealthComponent` |
| Таймер отдельной атаки | её `MeleeAttackComponent` |
| Стабильные слоты экипажа | `CrewManager` |
| Роли и переходы | `CrewRoleManager` |
| Занятость рабочих постов | `RoleStationRegistry` |
| Независимые кулдауны замены | `CrewReplacementController` |
| Активный энергетический контакт | `OrbContactSystem` |
| Прочность пяти секций | `ShieldSystem` |
| Геометрия пяти шаров | `GroundOrbCatalog` через `GroundOrbRegistry` |
| Стратегические группы | `StrategicWaveSystem` |
| Занятость клеток объектами | `BuildableGrid` |
| Монеты забега | `RunEconomy` |
| Цена и выбор улучшений | `UpgradeSystem` |

---

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

Владеет началом забега, полной паузой, экраном карточек и причиной поражения.

### ShieldFailureController

Завершает забег при разрушении любой секции.

### CrewFailureController

Немедленно завершает забег при нуле живых защитников, даже если замены ожидают кулдауна.

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

### PlatformVisualController

Рисует временную платформу, клетки, посты, шар и дверь замены. Координата двери читается из `CrewBalance`.

### Ресурсы

- `PlatformBalance` — размеры, посты, силы движения и границы.
- `WindBalance` — уровни ветра, интервалы и колебания.
- `CrewBalance` — параметры защитников, лимит экипажа, кулдаун и позиция двери.

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
- `GroundOrbRegistry` — координаты, зоны и точки крепления.
- `OrbContactSystem` — единственный владелец активного контакта.
- `ShieldSystem` — единственный владелец пяти значений прочности.
- `ShieldRechargeController` — преобразует контакт в восстановление связанной секции.
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

`AnchorSystem` не раскрывает внутренний store. BoardingDomain получает только `AnchorPathSnapshot`:

```text
anchor_id
side
orb_id
ground_point
platform_point
```

Каждый установленный якорь сохраняет исходный шар и наземную точку.

---

## 9. CrewDomain

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

### CrewManager

Владеет стабильными слотами `defender_id`.

- Стартовые защитники занимают слоты `0..N-1`.
- Мёртвый экземпляр остаётся владельцем слота до завершения кулдауна.
- При замене старый экземпляр удаляется.
- Новый экземпляр создаётся с тем же `defender_id`.
- Здоровье нового экземпляра полностью восстановлено.
- Текущий базовый максимум равен трём, но хранится в `CrewBalance`.

### CrewReplacementController

Владеет словарём независимых `CrewReplacementRuntime`.

- На каждую смерть запускается собственный таймер.
- Несколько таймеров идут одновременно.
- Таймеры останавливаются при полной паузе.
- При завершении вызывается `CrewManager.replace_defender()`.
- Новый защитник появляется в координате двери из `CrewBalance`.
- При `GAME_OVER` таймеры больше не продвигаются.

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
- завершения текущей операции якоря;
- завершения начатого взмаха;
- уничтожения врагов непосредственно рядом.

Замена получает роль `FREE_FIGHTER`, не восстанавливает старое назначение и может быть переназначена игроком.

### CrewCombatCoordinator

Передаёт каждому новому или стартовому защитнику зависимости боя. Собственного игрового состояния не хранит.

### DefenderCombatController

- Рулевой не использует меч.
- Якорщик атакует только возле своего поста.
- Свободный защитник выбирает ближайшего врага на платформе.
- Свободный защитник физически движется к выбранной цели через `DefenderMovement`.
- При входе в радиус атаки движение прекращается и начинается взмах.
- При смерти цели выбирается следующая ближайшая цель.
- Во время ожидающего переназначения дальние цели больше не преследуются.

---

## 10. CombatDomain

```text
HealthComponent
MeleeAttackComponent
DefenderCombatController
BoardingEnemyController
```

### MeleeAttackComponent

```text
READY
WINDUP
COOLDOWN
```

- Цель фиксируется в начале взмаха.
- Начатый удар не перенаправляется.
- Погибшая цель превращает удар в промах.
- Обычный успешный удар наносит один урон.
- Защитник атакует быстрее базового врага.

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

### BoardingSpawnDirector

- Не создаёт врагов без якорей.
- Сторона выбирается независимо 50/50.
- Наземный лимит не включает врагов на тросах и платформе.

### BoardingEnemyController

```text
WAITING_WITHOUT_PATH
RUNNING_TO_ANCHOR
CLIMBING
ON_PLATFORM
FIGHTING
DEAD
```

- Враг фиксирует ближайший путь.
- Новый более близкий якорь не меняет цель.
- Закрытие пути на земле заставляет выбрать другой.
- Закрытие пути во время подъёма убивает врага.
- Поднявшийся враг переживает снятие якоря.
- На платформе атакуется ближайший живой защитник.

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

## 16. Обязательные тестовые границы

- Контакт заряжает только связанную секцию.
- Разрушение секции завершает забег.
- Ноль живых защитников завершает забег немедленно.
- Каждый погибший защитник получает независимый кулдаун.
- Более ранняя смерть восстанавливается раньше более поздней.
- Новый экземпляр сохраняет `defender_id`.
- Замена появляется у двери с полным здоровьем.
- Замена активируется как свободный боец.
- Свободный боец преследует ближайшего поднявшегося врага.
- Без якорей физический спавн запрещён.
- Снятие убивает врага на тросе, но не на платформе.
- Начатый удар не перенаправляется.
- Лимит 600 строк не нарушен.

---

## 17. Следующая итерация

1. физическое разделение врагов на платформе;
2. минимальная дистанция и очередь на тросе;
3. блокирование защитников и врагов друг другом;
4. прыжок врага через защитника;
5. монеты за физические убийства;
6. рост наземного лимита от сложности;
7. начало стратегических волн.

---

## 18. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец игровых данных.
- Дублирование роли вне `CrewRoleManager`.
- Дублирование таймеров замены вне `CrewReplacementController`.
- Изменение слота экипажа вне `CrewManager`.
- Доступ BoardingDomain к `AnchorRuntimeStore`.
- Дублирование здоровья вне `HealthComponent`.
- Дублирование геометрии шаров вне `GroundOrbCatalog`.
- Зависимость симуляции от визуала.
- Один большой скрипт для ролей, врагов или карточек.
- Балансные значения, разбросанные по логике.
- Архитектурное изменение без обновления этого файла.
