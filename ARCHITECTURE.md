# GloryProtect — архитектура проекта

Этот файл является **единственным источником правды для архитектуры проекта**.

Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md). Любое изменение владельцев состояния, границ систем или направления зависимостей должно обновлять этот файл в том же наборе изменений.

---

## 1. Базовые принципы

- Godot **4.6.2 stable**.
- Строго типизированный GDScript.
- Композиция небольших сцен и компонентов.
- Максимум 600 строк на поддерживаемый файл.
- Начиная с 450 строк файл оценивается на разделение.
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

Доменные системы не зависят от HUD, спрайтов, расположения панелей или универсального глобального менеджера.

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
| Состояние и координаты отдельного врага | его `BoardingEnemyController` и корневой `BoardingEnemy` |
| Координаты защитника | корневой `Defender` через `DefenderMovement` |
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

`BoardingMovementResolver` **не владеет координатами**. Он только вычисляет допустимый шаг или свободную позицию, а итоговую координату записывает владелец конкретного персонажа.

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

- Новый экземпляр замены получает прежний идентификатор.
- Старый экземпляр удаляется только при создании замены.
- Новый защитник появляется с полным здоровьем.
- Базовый максимум хранится в `CrewBalance`.

### CrewReplacementController

- Владеет независимым `CrewReplacementRuntime` для каждой смерти.
- Несколько таймеров идут одновременно.
- Таймеры останавливаются при полной паузе.
- Перед созданием замены запрашивает ближайшую свободную позицию у `BoardingMovementResolver`.
- Замена не может появиться внутри врага.
- При `GAME_OVER` таймеры не продвигаются.

### CrewRoleManager

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

Замена получает роль `FREE_FIGHTER` и не восстанавливает старое назначение.

### DefenderMovement

- Владеет целевой координатой движения защитника.
- Может быть приостановлен боем без потери назначения.
- Запрашивает допустимую координату у `BoardingMovementResolver`.
- Игнорирует других защитников.
- Не позволяет пройти сквозь врага.

### DefenderCombatController

- Рулевой не использует меч.
- Якорщик атакует возле своего поста.
- Свободный защитник преследует ближайшего поднявшегося врага.
- Защитник, идущий к новому посту, останавливается перед блокирующим врагом, завершает бой и продолжает прежний маршрут.

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
BoardingMovementResolver
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
- Точка спавна корректируется через `BoardingMovementResolver`, поэтому враги не появляются друг внутри друга.

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
- Итоговые координаты остаются собственностью контроллера врага.

### BoardingMovementResolver

Статeless-сервис расчёта движения. Он читает реестры и баланс, но не записывает позиции самостоятельно.

Отвечает за:

- минимальную дистанцию между наземными врагами;
- безопасные наземные точки спавна;
- допуск следующего врага на трос;
- минимальное расстояние между врагами на одном тросе;
- ожидание у верхнего конца троса, пока место на платформе занято;
- минимальную дистанцию между врагами на платформе;
- взаимное блокирование защитника и врага;
- свободную позицию появления замены.

Правила разделения:

- защитники проходят сквозь защитников;
- враги не проходят сквозь врагов;
- защитники и враги не проходят друг сквозь друга;
- задний враг ждёт, пока передний освободит место;
- враг у верхнего конца троса остаётся в состоянии `CLIMBING` и погибает при снятии якоря;
- значения дистанций находятся только в `BoardingBalance` и `CrewBalance`.

### Пока не реализовано

- прыжок врага через защитника;
- перенаправление после прыжка;
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
- Замена не появляется внутри врага.
- Без якорей физический спавн запрещён.
- Наземные враги сохраняют минимальную дистанцию.
- Враги на одном тросе сохраняют минимальную дистанцию.
- Верхний враг ждёт свободного места на платформе.
- Враги на платформе не накладываются друг на друга.
- Защитник и враг не проходят друг сквозь друга.
- Защитники могут проходить сквозь защитников.
- Защитник продолжает маршрут роли после устранения блокирующего врага.
- Начатый удар не перенаправляется.
- Лимит 600 строк не нарушен.

---

## 17. Следующая итерация

1. прыжок врага через защитника при выполнении условий;
2. проверка свободного места за спиной защитника;
3. уязвимость прыгающего врага для турели в будущем;
4. монеты за физические убийства;
5. рост наземного лимита от сложности;
6. начало стратегических волн;
7. полноценная миникарта.

---

## 18. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец игровых данных.
- Дублирование роли вне `CrewRoleManager`.
- Дублирование таймеров замены вне `CrewReplacementController`.
- Дублирование координат персонажа внутри `BoardingMovementResolver`.
- Физические дистанции, разбросанные по контроллерам вместо ресурсов баланса.
- Доступ BoardingDomain к `AnchorRuntimeStore`.
- Дублирование здоровья вне `HealthComponent`.
- Дублирование геометрии шаров вне `GroundOrbCatalog`.
- Зависимость симуляции от визуала.
- Один большой скрипт для ролей, врагов или карточек.
- Архитектурное изменение без обновления этого файла.
