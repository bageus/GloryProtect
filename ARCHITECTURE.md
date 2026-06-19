# GloryProtect — архитектура проекта

Этот файл является **единственным источником правды для архитектуры проекта**.

Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md). Изменение владельцев состояния, границ систем или направления зависимостей должно обновлять этот файл в том же наборе изменений.

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
| Активный энергетический контакт | `OrbContactSystem` |
| Прочность пяти секций | `ShieldSystem` |
| Каталог пяти шаров | `GroundOrbCatalog` через `GroundOrbRegistry` |
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

### ShieldFailureController

Слушает `ShieldSystem.section_destroyed` и завершает забег с причиной `shield_section_destroyed`.

### CrewFailureController

Слушает смерти защитников через `CrewManager`. При нуле живых защитников завершает забег с причиной `all_defenders_dead`.

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

## 7. OrbDomain и ShieldDomain

Текущая композиция:

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

Типизированный ресурс и единственный источник данных для:

- пяти горизонтальных позиций;
- высоты земли;
- ширины контактной зоны;
- визуальных размеров шаров;
- глубины земли.

Идентификатор шара совпадает с идентификатором связанной секции.

### GroundOrbRegistry

Предоставляет публичные запросы:

```text
get_world_x(orb_id)
get_orb_world_position(orb_id)
get_contact_orb_at(platform_x)
get_installation_orb_at(platform_x, half_width)
get_anchor_ground_point(orb_id, anchor_id, offsets)
```

Реестр не хранит активный контакт и не изменяет щит.

### OrbContactSystem

Единственный владелец `active_orb_id`.

- Проверяет горизонтальное положение платформы.
- Выбирает ближайший шар внутри контактной зоны.
- Немедленно завершает контакт после выхода из зоны.
- Публикует `contact_started`, `contact_ended` и `contact_changed`.
- Не восстанавливает щит напрямую.

### ShieldSystem

Единственный владелец прочности пяти секций.

Публичный интерфейс:

```text
apply_damage(section_id, amount)
restore(section_id, amount)
set_health(section_id, value)
get_health(section_id)
get_health_percent(section_id)
is_critical(section_id)
needs_direction_indicator(section_id)
```

Публикует:

```text
section_changed
section_entered_critical
section_left_critical
section_destroyed
```

Все секции создаются со 100% прочности.

### ShieldRechargeController

На каждом активном физическом кадре:

1. читает связанную секцию из `OrbContactSystem`;
2. отправляет команду `restore` в `ShieldSystem`;
3. использует скорость из `ShieldBalance`.

Контакт и восстановление остаются отдельными системами.

### GroundOrbVisualController

Рисует землю, пять шаров, кольца прочности и энергетический луч. Читает публичное состояние, но не изменяет его.

### ShieldDebugInput

Временный адаптер прототипа. F1–F5 выбирают секцию, `Space` отправляет команду урона. Не владеет прочностью.

### Ресурсы

- `ShieldBalance` — число секций, максимальная прочность, скорость зарядки, пороги и цвета.
- `GroundOrbCatalog` — фиксированная геометрия пяти шаров.

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
- `AnchorRuntimeStore` — состояния `STOWED`, `QUEUED`, `INSTALLING`, `ATTACHED`, `OVERLOADED`, `RETURNING`.
- `AnchorCommandController` — проверка и маршрутизация команд.
- `AnchorOperationQueue` — текущая установка, очередь сторон и отложенное экстренное снятие.
- `AnchorGeometry` — точки крепления, конечная длина и геометрические границы.
- `AnchorConstraintProvider` — допустимый диапазон платформы или полная фиксация.
- `AnchorOverloadController` — таймер перегрузки, сброс и срыв.
- `AnchorVisualController` — силуэты, тросы, предупреждения и возврат.
- `AnchorBalance` — единственный источник настраиваемых параметров якорей.

Каждая команда установки фиксирует конкретный `orb_id` и конкретную наземную точку. Установленный трос не меняет шар при движении платформы. Очередь сохраняет исходный шар и отменяется, если платформа покинула его зону до начала операции.

Начатая установка завершается после потери оператора. Каждый трос имеет конечную длину в обоих направлениях.

---

## 9. CrewDomain

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

Владеет занятостью и резервированием постов. Геометрия постов читается из `PlatformBalance`, а не дублируется в `CrewBalance`.

### Defender

Тонкий корень композиции. Делегирует здоровье, движение и визуал компонентам.

### HealthComponent

Единственный владелец здоровья сущности.

### CrewDebugInput

Временный адаптер прототипа. Отправляет команды `CrewRoleManager` и не хранит назначения.

---

## 10. CombatDomain

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

## 11. BoardingDomain

Целевая композиция:

```text
BoardingSpawnDirector
GroundEnemyRegistry
AnchorPathRegistry
BoardingEnemy
└── BoardingEnemyStateMachine
```

`BoardingSpawnDirector` владеет интервалом, общим наземным лимитом и стороной появления. Без якорей новых врагов не создаёт.

`AnchorPathRegistry` предоставляет маршруты. Враг фиксирует путь до его недоступности.

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
├── ground_orb_catalog.tres
├── enemies/
├── upgrades/
├── roles/
└── buildables/
```

---

## 17. Обязательные тестовые границы

- пять секций создаются со 100%;
- каждый шар связан со своей секцией;
- контакт выбирает правильный шар;
- заряжается только активная секция;
- вне зоны зарядка отсутствует;
- при 50% появляется указатель;
- 0% любой секции завершает забег;
- ноль живых защитников завершает забег;
- установленный якорь сохраняет исходный `orb_id`;
- конечная длина троса работает в обоих направлениях;
- рулевой и якорщик завершают неделимое действие;
- лимит 600 строк не нарушен.

---

## 18. Следующая итерация

1. добавить базового физического врага;
2. реализовать `AnchorPathRegistry`;
3. добавить выбор ближайшей цели;
4. добавить `DefenderActionController`;
5. реализовать меч, кулдаун и неделимый взмах;
6. добавить независимые таймеры замены;
7. начать стратегические волны и миникарту.

---

## 19. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец игровых данных.
- Дублирование роли в `Defender` и `CrewRoleManager`.
- Дублирование геометрии шаров вне `GroundOrbCatalog`.
- Дублирование прочности секций вне `ShieldSystem`.
- Дублирование геометрии постов в ресурсах.
- Зависимость симуляции от визуала.
- Один огромный скрипт для ролей, врагов или карточек.
- Балансные значения, разбросанные по логике.
- Изменение архитектуры без обновления этого файла.
