# GloryProtect — архитектура проекта

Этот файл является **единственным источником правды для архитектуры проекта**.

Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md). Изменение владельцев состояния, границ систем или направления зависимостей должно обновлять этот файл в том же коммите.

---

## 1. База и принципы

- Godot **4.6.2 stable** и GDScript.
- Композиция сцен и небольших компонентов.
- Симуляция отделена от UI и визуала.
- Баланс хранится в типизированных `Resource`.
- Максимум 600 строк на поддерживаемый файл; с 450 строк требуется оценка разделения.
- Каждое изменяемое состояние имеет ровно одного владельца.
- UI отображает состояние и отправляет команды, но не реализует механику.
- Визуальные компоненты не меняют доменное состояние.
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

Доменные системы могут зависеть от своих ресурсов, явно переданных ссылок и публичных интерфейсов соседних доменов.

Запрещены зависимости симуляции от HUD, спрайтов, расположения UI, глубоких путей чужих сцен и универсального глобального менеджера.

---

## 3. Высокоуровневая структура

```text
GameRoot
├── GameFlowDomain
├── DifficultyDomain
├── InputAdapters
├── World
│   ├── PlatformDomain
│   ├── AnchorDomain
│   ├── OrbDomain
│   ├── CrewDomain
│   ├── CombatDomain
│   ├── BoardingDomain
│   └── BuildableDomain
├── StrategicSimulation
│   ├── ShieldDomain
│   └── StrategicWaveDomain
├── EconomyDomain
└── PresentationDomain
```

`GameRoot` собирает системы и передаёт зависимости. Он не реализует движение, бой, спавн, лечение, якорную физику или экономику.

---

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Состояние забега и паузы | `GameFlowController` |
| Время активного забега | `RunClock` |
| Текущая сложность | `DifficultyDirector` |
| Направление и сила ветра | `WindSystem` |
| Позиция и скорость платформы | `PlatformController` |
| Доступность рулевого ввода | `SteeringInputProvider`, управляемый `CrewRoleManager` |
| Состояния четырёх якорей | `AnchorRuntimeStore` |
| Очереди операций якорей | `AnchorOperationQueue` |
| Роли и переходы защитников | `CrewRoleManager` |
| Занятость рабочих постов | `RoleStationRegistry` |
| Реестр защитников | `CrewManager` |
| Здоровье сущности | её `HealthComponent` |
| Контакт энергетических шаров | `OrbContactSystem` |
| Прочность пяти секций | `ShieldSystem` |
| Физический враг | его state machine |
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

Отвечает за начало забега, полную паузу, экран карточек, завершение и причину поражения. Не отвечает за движение, роли, урон или визуал.

### RunClock

Планируемый компонент. Считает только активное время и останавливается на полной паузе.

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

Владеет горизонтальной позицией и скоростью. Применяет рулевое усилие, ветер, сопротивление, предел скорости, мировые границы и ограничения якорей.

Получает данные от:

- `SteeringInputProvider`;
- `WindSystem`;
- публичного интерфейса `AnchorSystem`;
- `PlatformBalance`.

Не читает клавиатуру и не рисует платформу.

### SteeringInputProvider

Возвращает рулевую ось только при активном рулевом. Сообщает, удерживается ли хотя бы одна кнопка. Одновременное удержание двух направлений считается активным вводом с нулевой осью.

### WindSystem

Владеет направлением, уровнем 1–3, фактическим усилием и расписанием изменений. Использует `WindBalance` и не двигает платформу напрямую.

### PlatformVisualController

Рисует временную платформу, клетки, посты и шар. Не изменяет движение или роли.

### Ресурсы

- `PlatformBalance` — размеры, посты, силы движения и границы.
- `WindBalance` — уровни ветра, интервалы и колебания.

---

## 7. AnchorDomain

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
- `AnchorRuntimeStore` — состояния `STOWED`, `QUEUED`, `INSTALLING`, `ATTACHED`, `OVERLOADED`, `RETURNING`.
- `AnchorCommandController` — проверка и маршрутизация команд.
- `AnchorOperationQueue` — текущая установка, очередь сторон и отложенное экстренное снятие.
- `AnchorGeometry` — точки крепления, конечная длина и геометрические границы.
- `AnchorConstraintProvider` — допустимый диапазон платформы или полная фиксация.
- `AnchorOverloadController` — таймер перегрузки, сброс и срыв.
- `AnchorVisualController` — силуэты, тросы, предупреждения и возврат.
- `AnchorBalance` — единственный источник настраиваемых параметров якорей.

Начатая установка завершается после потери оператора. Ещё не начатые команды отменяются. Каждый трос имеет конечную длину в обоих направлениях.

---

## 8. CrewDomain

```text
CrewManager
├── Defender 1
├── Defender 2
└── Defender 3

CrewRoleManager
└── RoleStationRegistry

Defender
├── HealthComponent
├── DefenderMovement
└── DefenderVisual
```

### CrewManager

Владеет реестром защитников. Создаёт стартовый экипаж, выдаёт идентификаторы, предоставляет ссылки и сообщает о смерти. Позднее владеет независимыми таймерами замены.

### CrewRoleManager

Владеет текущей ролью, целевой ролью и состоянием перехода:

```text
ACTIVE
WAITING_FOR_ACTION
MOVING
DEAD
```

Правила:

- рулевой уходит после отпускания обеих кнопок;
- якорщик уходит после текущей установки;
- старый пост отключается при начале перехода;
- новая роль включается только после прибытия;
- роль не хранится внутри `Defender`.

### RoleStationRegistry

Владеет занятостью и резервированием постов. Предоставляет:

```text
reserve(role_id, defender_id)
release(role_id, defender_id)
get_owner(role_id)
get_target_x(role_id, defender_id)
```

Геометрия постов читается из `PlatformBalance`, а не дублируется в `CrewBalance`.

### Defender

Тонкий корень композиции. Делегирует здоровье, движение и визуал компонентам.

### DefenderMovement

Владеет целью движения конкретного защитника и сообщает о прибытии.

### HealthComponent

Единственный владелец здоровья сущности.

### DefenderVisual

Рисует временный корпус и сегменты здоровья. Не меняет роль или здоровье.

### CrewDebugInput

Временный адаптер прототипа. Отправляет команды `CrewRoleManager` и не хранит назначения.

### CrewBalance

Содержит стартовое количество, здоровье, скорость движения и временные визуальные размеры.

---

## 9. CombatDomain

Текущая реализация содержит `HealthComponent`.

Целевая композиция:

```text
DefenderActionController
TargetSelector
MeleeAttackComponent
RangedAttackComponent
CombatResolver
DeathComponent
```

- `CombatResolver` применяет завершённые попадания.
- Начатая атака не перенаправляется.
- Выбор цели отделён от выполнения атаки.
- Визуал не наносит урон.

---

## 10. OrbDomain и ShieldDomain

Целевая композиция:

```text
GroundOrbRegistry
OrbContactSystem
ShieldSystem
ShieldRechargeController
```

- `GroundOrbRegistry` хранит пять шаров, секции, зоны и крепления.
- `OrbContactSystem` владеет текущим контактом и публикует начало/конец.
- `ShieldSystem` владеет пятью секциями и принимает `apply_damage`/`restore`.
- `ShieldRechargeController` преобразует контакт в команды восстановления.

`PrototypeWorld` и `PrototypeShieldSystem` являются временными компонентами и должны быть заменены этим доменом.

---

## 11. BoardingDomain

```text
BoardingSpawnDirector
GroundEnemyRegistry
AnchorPathRegistry
BoardingEnemy
└── BoardingEnemyStateMachine
```

`BoardingSpawnDirector` владеет интервалом, общим наземным лимитом и стороной появления. Без якорей новых врагов не создаёт.

`AnchorPathRegistry` предоставляет маршруты. Враг фиксирует путь до его недоступности.

Состояния врага:

```text
SPAWNING_OFFSCREEN
RUNNING_TO_ANCHOR
WAITING_WITHOUT_PATH
CLIMBING
ENTERING_PLATFORM
FIGHTING
JUMPING
DEAD
```

---

## 12. StrategicWaveDomain

Стратегические враги представлены агрегированными данными.

```text
StrategicWaveDirector
StrategicWaveSystem
MinimapRenderer
```

`StrategicWaveSystem` владеет количеством, целью, движением, объединением, разделением и отдельными импульсами урона. `MinimapRenderer` только отображает.

---

## 13. BuildableDomain

```text
BuildableInventory
BuildableGrid
MedicalStationSystem
TurretSystem
```

`BuildableGrid` — единственный владелец занятости клеток объектами. Медицинский пост и турели используют обычные свободные клетки и не блокируют персонажей.

---

## 14. EconomyDomain

- `RunEconomy` — монеты текущего забега.
- `UpgradeSystem` — номер выдачи, стоимость, две карточки и цепочка покупок.
- `UpgradeCatalog` — data-driven определения; запрещён один большой `match` эффектов.

---

## 15. PresentationDomain

Содержит HUD, миникарту, указатели, визуалы, анимации, звук и эффекты.

Presentation читает публичные снимки, подписывается на события и отправляет команды. Доменные данные напрямую не изменяет.

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
├── enemies/
├── upgrades/
├── roles/
└── buildables/
```

---

## 17. Структура каталогов

```text
res://
├── scenes/
│   ├── game/
│   ├── platform/
│   ├── crew/
│   ├── enemies/
│   ├── orbs/
│   ├── buildables/
│   └── ui/
├── scripts/
│   ├── game_flow/
│   ├── difficulty/
│   ├── platform/
│   ├── anchors/
│   ├── shield/
│   ├── orbs/
│   ├── crew/
│   ├── combat/
│   ├── boarding/
│   ├── strategic/
│   ├── buildables/
│   ├── economy/
│   └── ui/
├── resources/
├── tests/
├── tools/
└── docs/
```

---

## 18. Обязательные тестовые границы

- конечная длина троса в обоих направлениях;
- перегрузка одиночного натянутого якоря;
- устойчивость пары якорей;
- параметры платформы и ветра читаются из ресурсов;
- отсутствие рулевого обнуляет ввод;
- рулевой не уходит при активной кнопке;
- управление отключено во время перехода;
- управление включается после прибытия;
- якорщик завершает текущую установку;
- лимит 600 строк не нарушен.

---

## 19. Следующая итерация

1. заменить тестовую секцию полноценным `ShieldSystem`;
2. добавить `GroundOrbRegistry` и `OrbContactSystem`;
3. добавить `DefenderActionController`;
4. реализовать базовый ближний бой;
5. связать гибель всего экипажа с поражением;
6. добавить независимые таймеры замены;
7. добавить базового физического врага и его state machine.

---

## 20. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец игровых данных.
- Дублирование роли в `Defender` и `CrewRoleManager`.
- Дублирование геометрии постов в ресурсах.
- Зависимость симуляции от визуала.
- Один огромный скрипт для ролей, врагов или карточек.
- Балансные значения, разбросанные по логике.
- Глубокие пути между независимыми сценами.
- Физическая сцена на каждого стратегического врага.
- Изменение архитектуры без обновления этого файла.
