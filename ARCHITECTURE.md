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

Слушает разрушение секции и завершает забег с причиной `shield_section_destroyed`.

### CrewFailureController

Слушает смерти защитников и при нуле живых завершает забег с причиной `all_defenders_dead`.

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

Не читает клавиатуру и не рисует платформу.

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

### GroundOrbCatalog

Единственный источник пяти позиций, высоты земли, контактной зоны и временных визуальных размеров.

### GroundOrbRegistry

Предоставляет координаты шаров, поиск контактной и якорной зоны и четыре точки крепления каждого шара.

### OrbContactSystem

Единственный владелец `active_orb_id`. Публикует начало и окончание контакта, но не изменяет щит.

### ShieldSystem

Единственный владелец прочности пяти секций. Принимает `apply_damage`, `restore` и `set_health`; публикует изменение, критическое состояние и разрушение.

### ShieldRechargeController

Преобразует активный контакт в непрерывные команды восстановления связанной секции.

### GroundOrbVisualController

Рисует землю, пять шаров, прочность и энергетический луч.

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

- `AnchorSystem` — тонкий координатор и публичный фасад.
- `AnchorRuntimeStore` — состояния якорей и привязка к конкретному шару.
- `AnchorCommandController` — проверка и маршрутизация команд.
- `AnchorOperationQueue` — активная установка, очередь и отложенное экстренное снятие.
- `AnchorGeometry` — точки крепления, конечная длина и границы.
- `AnchorConstraintProvider` — допустимый диапазон платформы.
- `AnchorOverloadController` — перегрузка, сброс и срыв.
- `AnchorVisualController` — силуэты, тросы и предупреждения.

### Публичная граница для абордажа

`AnchorSystem` не отдаёт внутренний `AnchorRuntimeStore`. Он создаёт `AnchorPathSnapshot`:

```text
anchor_id
side
orb_id
ground_point
platform_point
```

Доступны запросы:

```text
get_active_path_count()
is_path_available(anchor_id)
get_path_snapshot(anchor_id)
get_active_path_snapshots()
```

---

## 9. CrewDomain

```text
CrewManager
├── Defender 1
├── Defender 2
└── Defender 3

CrewRoleManager
└── RoleStationRegistry

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
- завершения начатого взмаха меча.

### RoleStationRegistry

Владеет резервированием постоянных постов. Геометрия берётся из `PlatformBalance`.

### CrewCombatCoordinator

Передаёт каждому защитнику ссылки на реестр врагов, менеджер ролей и параметры боя. Собственного игрового состояния не хранит.

### DefenderCombatController

- Рулевой не использует меч.
- Якорщик атакует только в зоне своего поста.
- Свободный защитник может выбирать любую цель на платформе.
- В текущем срезе защитник не преследует далёкую цель, но атакует врага, вошедшего в радиус.

---

## 10. CombatDomain

```text
HealthComponent
MeleeAttackComponent
DefenderCombatController
BoardingEnemyController
```

### HealthComponent

Единственный владелец здоровья сущности.

### MeleeAttackComponent

Владеет фазами:

```text
READY
WINDUP
COOLDOWN
```

Правила:

- цель фиксируется при начале взмаха;
- начатый удар не перенаправляется;
- если цель погибла, удар проходит впустую;
- успешный удар применяет фиксированный урон через `HealthComponent`;
- защитник атакует быстрее базового врага.

Визуальные компоненты урон не наносят.

---

## 11. BoardingDomain

Текущая композиция:

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

- Читает только публичные снимки `AnchorSystem`.
- Публикует открытие и закрытие маршрута.
- Выбирает ближайший путь.
- При приблизительном равенстве выбирает случайно.

### BoardingSpawnDirector

- Новые враги появляются только при наличии якоря.
- Сторона появления выбирается независимо 50/50.
- Используется общий лимит активных врагов.
- Параметры находятся в `BoardingBalance`.

### BoardingEnemyRegistry

Единственный владелец реестра физических врагов. Предоставляет общее количество, группы по состоянию и ближайшего поднявшегося врага.

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

- на земле враг выбирает ближайший путь и фиксирует его;
- новый более близкий якорь не меняет выбранную цель;
- закрытие пути до подъёма возвращает врага к выбору пути;
- закрытие пути во время подъёма убивает врага;
- враг на платформе переживает снятие якоря;
- без пути враг следует по земле за платформой и остаётся безвредным;
- на платформе выбирается ближайший живой защитник;
- обычный успешный удар снимает один сегмент.

### Пока не реализовано

- физическое разделение врагов и пробки;
- несколько врагов с минимальной дистанцией на тросе;
- прыжок через защитника;
- типы врагов;
- накопление монет за убийства;
- плавно растущий лимит от сложности.

---

## 12. StrategicWaveDomain

Планируемая композиция:

```text
StrategicWaveDirector
StrategicWaveSystem
MinimapRenderer
```

Стратегические враги будут представлены агрегированными данными, а не отдельными сценами.

---

## 13. BuildableDomain

```text
BuildableInventory
BuildableGrid
MedicalStationSystem
TurretSystem
```

`BuildableGrid` будет единственным владельцем занятости клеток объектами.

---

## 14. EconomyDomain

- `RunEconomy` — монеты текущего забега.
- `UpgradeSystem` — номер выдачи, стоимость, две карточки и цепочка покупок.
- `UpgradeCatalog` — data-driven определения.

---

## 15. PresentationDomain

Содержит HUD, миникарту, указатели, визуалы, анимации, звук и эффекты. Presentation не изменяет доменное состояние.

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

- пять секций создаются со 100%;
- контакт заряжает только связанную секцию;
- 0% любой секции завершает забег;
- ноль живых защитников завершает забег;
- установленный якорь сохраняет исходный `orb_id`;
- конечная длина троса работает в обоих направлениях;
- без якорей физический спавн запрещён;
- враг фиксирует выбранный маршрут;
- снятие якоря убивает врага на тросе;
- враг на платформе переживает снятие;
- враг атакует ближайшего защитника;
- начатый удар не перенаправляется;
- рулевой и якорщик завершают неделимые действия;
- лимит 600 строк не нарушен.

---

## 18. Следующая итерация

1. реализовать независимые таймеры замены защитников;
2. добавить движение свободного защитника к ближайшему врагу;
3. добавить физическое разделение врагов;
4. реализовать массовый подъём по каждому тросу;
5. добавить прыжок через защитника;
6. добавить монеты за физические убийства;
7. начать стратегические волны и миникарту.

---

## 19. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец игровых данных.
- Дублирование роли в `Defender` и `CrewRoleManager`.
- Доступ BoardingDomain к внутреннему `AnchorRuntimeStore`.
- Дублирование здоровья вне `HealthComponent`.
- Дублирование геометрии шаров вне `GroundOrbCatalog`.
- Дублирование прочности секций вне `ShieldSystem`.
- Зависимость симуляции от визуала.
- Один большой скрипт для ролей, врагов или карточек.
- Балансные значения, разбросанные по логике.
- Архитектурное изменение без обновления этого файла.
