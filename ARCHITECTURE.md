# GloryProtect — архитектура проекта

Этот файл является **единственным источником правды для архитектуры проекта**.

Обязательные инженерные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md).
Любое изменение владельцев состояния, границ систем или направления зависимостей должно обновлять этот файл в том же коммите.

---

## 1. Технологическая база

- Godot **4.6.2 stable**.
- GDScript.
- Композиция сцен и компонентов.
- Симуляция отделена от UI и визуального слоя.
- Баланс хранится в типизированных `Resource`.
- Ни один исходный файл не превышает 600 строк.
- При приближении к 450 строкам файл оценивается на разделение.

---

## 2. Основные принципы

1. Один класс имеет одну ответственность.
2. Каждое изменяемое состояние имеет одного владельца.
3. UI отображает состояние и отправляет команды, но не реализует механику.
4. Доменные системы публикуют события после изменения состояния.
5. Зависимости передаются явно.
6. Настраиваемые значения не хранятся в игровой логике.
7. Новая механика добавляется в существующий домен либо требует изменения этого документа.
8. Временные прототипные решения не должны становиться постоянными архитектурными обходами.

---

## 3. Высокоуровневая схема

```text
GameRoot
├── GameFlowDomain
├── DifficultyDomain
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

`GameRoot` создаёт системы, передаёт зависимости и запускает забег. Он не реализует движение, бой, спавн, лечение, якорную физику или экономику.

---

## 4. Направление зависимостей

```text
Input / UI
    ↓ команды
Domain Systems
    ↓ события и снимки состояния
UI / Visual / Audio
```

Доменные системы могут зависеть от:

- собственных ресурсов данных;
- явно переданных ссылок;
- небольших публичных интерфейсов соседних систем;
- событий верхнего уровня.

Доменные системы не зависят от HUD, спрайтов, расположения UI, глубоких путей чужих сцен или универсального глобального менеджера.

---

## 5. Единственные владельцы состояния

| Состояние | Владелец |
|---|---|
| Состояние забега и паузы | `GameFlowController` |
| Время активного забега | `RunClock` |
| Текущая сложность | `DifficultyDirector` |
| Направление и сила ветра | `WindSystem` |
| Позиция и скорость платформы | `PlatformMovementController` |
| Состояния четырёх якорей | `AnchorRuntimeStore` |
| Очереди якорных операций | `AnchorOperationQueue` |
| Контакт шаров | `OrbContactSystem` |
| Прочность пяти секций | `ShieldSystem` |
| Роли защитников | `CrewRoleManager` |
| Здоровье сущности | её `HealthComponent` |
| Текущее действие защитника | `DefenderActionController` |
| Состояние физического врага | его state machine |
| Стратегические группы | `StrategicWaveSystem` |
| Занятость клеток объектами | `BuildableGrid` |
| Монеты забега | `RunEconomy` |
| Цена и выбор улучшений | `UpgradeSystem` |

UI и визуальные узлы могут иметь только восстанавливаемый кэш отображения.

---

## 6. Корневая сцена

```text
GameRoot
├── GameFlowController
├── RunClock
├── DifficultyDirector
├── World
│   ├── LevelBounds
│   ├── GroundOrbContainer
│   ├── BoardingEnemyContainer
│   └── Platform
├── StrategicSimulation
│   ├── ShieldSystem
│   └── StrategicWaveSystem
├── Economy
│   ├── RunEconomy
│   └── UpgradeSystem
└── UI
    └── GameHUD
```

---

## 7. GameFlowDomain

### GameFlowController

Владеет состояниями:

```text
BOOT
START_DELAY
RUNNING
CARD_SELECTION
MANUAL_PAUSE
GAME_OVER
```

Отвечает за запуск, полную паузу, выбор карточек и завершение забега.

### RunClock

Считает только активное время забега и останавливается при полной паузе.

---

## 8. DifficultyDomain

### DifficultyDirector

Владеет единым параметром сложности и публикует `DifficultySnapshot`:

```text
strategic_wave_size
strategic_spawn_interval
strategic_max_groups
boarding_spawn_interval
boarding_ground_limit
```

Потребители — `StrategicWaveDirector` и `BoardingSpawnDirector`. Сам директор сложности врагов не создаёт.

---

## 9. PlatformDomain

### PlatformMovementController

Владеет горизонтальной позицией и скоростью платформы.

Получает:

- рулевую ось;
- усилие ветра;
- ограничения якорей;
- границы уровня.

Не хранит состояния якорей и не читает UI.

### SteeringInputProvider

Возвращает рулевую ось только при активном рулевом.

### WindSystem

Владеет направлением, уровнем 1–3, фактическим усилием и расписанием изменений. Не двигает платформу напрямую.

### PlatformGrid

Описывает фиксированный ряд ячеек для постов, объектов и позиционирования персонажей.

---

## 10. AnchorDomain

Текущая реализованная композиция:

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

### AnchorSystem

Тонкий координатор. Собирает компоненты, перенаправляет публичные команды и повторно публикует события. Не хранит runtime-состояния якорей.

### AnchorRuntimeStore

Единственный владелец состояний:

```text
STOWED
QUEUED
INSTALLING
ATTACHED
OVERLOADED
RETURNING
```

### AnchorCommandController

Проверяет и маршрутизирует:

```text
request_toggle(anchor_id)
request_remove_all()
set_operator_available(side, available)
```

### AnchorOperationQueue

Владеет текущей установкой, очередью каждой стороны и ожиданием экстренного снятия. Начатая установка продолжается после потери оператора.

### AnchorGeometry

Вычисляет точки крепления, позиции креплений на платформе, конечную длину троса и геометрические границы движения.

### AnchorConstraintProvider

Предоставляет платформе минимальную и максимальную координаты либо полную фиксацию. Каждый трос имеет конечную длину в обоих направлениях.

### AnchorOverloadController

Владеет таймером перегрузки. Перегрузка определяется реальным натяжением троса и направлением ветра, а не только стороной якоря.

### AnchorVisualController

Рисует тросы, силуэты, предупреждения и возврат, не меняя доменное состояние.

### AnchorBalance

Типизированный ресурс с длиной троса, длительностями операций, зоной установки, растяжением при перегрузке и геометрическими отступами.

---

## 11. OrbDomain и ShieldDomain

### GroundOrbRegistry

Хранит пять определений шаров: позицию, связанную секцию, контактную зону, якорную зону и четыре точки крепления.

### OrbContactSystem

Публикует `contact_started` и `contact_ended`. Не изменяет щит напрямую.

### ShieldSystem

Владеет пятью секциями и принимает `apply_damage` и `restore`.

### ShieldRechargeController

Преобразует активный контакт в команды восстановления `ShieldSystem`.

---

## 12. CrewDomain

```text
Defender
├── HealthComponent
├── DefenderMovement
├── DefenderStateMachine
├── DefenderActionController
├── TargetSelector
├── MeleeAttackComponent
└── DefenderVisual
```

### CrewManager

Владеет реестром защитников, смертями, таймерами замены и созданием новых защитников.

### CrewRoleManager

Владеет назначениями ролей, резервированием постов и активацией роли после физического прибытия.

### RoleStation

Общий интерфейс рабочего места:

```text
can_accept(defender_id)
reserve(defender_id)
activate(defender_id)
release(defender_id)
```

### DefenderActionController

Владеет текущим неделимым действием: взмахом, рулевым вводом, лечебным циклом или выстрелом.

---

## 13. CombatDomain

```text
HealthComponent
TargetSelector
MeleeAttackComponent
RangedAttackComponent
CombatResolver
DeathComponent
```

`HealthComponent` — единственный владелец здоровья. `CombatResolver` применяет завершённые попадания. Начатая атака не перенаправляется после смерти цели.

---

## 14. BoardingDomain

```text
BoardingSpawnDirector
GroundEnemyRegistry
AnchorPathRegistry
BoardingEnemyStateMachine
```

`BoardingSpawnDirector` владеет интервалом спавна, общим наземным лимитом и выбором стороны. Без установленных якорей новых врагов не создаёт.

`AnchorPathRegistry` предоставляет доступные маршруты. Враг фиксирует маршрут до его недоступности.

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

## 15. StrategicWaveDomain

Стратегические враги представлены агрегированными данными.

`StrategicWaveDirector` создаёт волны на основе `DifficultySnapshot`.

`StrategicWaveSystem` владеет группами:

```text
StrategicGroup
├── enemy_count
├── normalized_position
├── target_section_id
├── speed
└── damage_per_enemy
```

`MinimapRenderer` только отображает группы и секции.

---

## 16. BuildableDomain

### BuildableInventory

Владеет полученными, но не установленными объектами.

### BuildableGrid

Владеет занятостью клеток объектами. Персонажи не блокируют установку.

### MedicalStationSystem

Владеет единственным медицинским постом. Выбор пациента и лечебный цикл реализуются отдельными компонентами.

### TurretSystem

Каждая турель имеет runtime и оператора. Выбор цели, кулдаун, выстрел и урон разделены.

---

## 17. EconomyDomain

`RunEconomy` — единственный владелец монет текущего забега.

`UpgradeSystem` владеет номером выдачи, стоимостью, двумя карточками и цепочкой покупок.

`UpgradeCatalog` хранит определения карточек в данных. Эффекты не реализуются одним большим `match`.

---

## 18. PresentationDomain

Содержит HUD, миникарту, указатели, визуалы, анимации, звук и эффекты.

Presentation читает публичные снимки, подписывается на события и отправляет команды. Доменные данные напрямую не изменяет.

---

## 19. Ресурсы данных

```text
resources/balance/
├── platform_balance.tres
├── wind_balance.tres
├── anchor_balance.tres
├── shield_balance.tres
├── boarding_balance.tres
├── crew_balance.tres
├── turret_balance.tres
└── difficulty_curve.tres

resources/definitions/
├── enemies/
├── upgrades/
├── roles/
└── buildables/
```

---

## 20. Команды и события

Команды описывают намерение:

```text
request_assign_role
request_toggle_anchor
request_remove_all_anchors
request_place_buildable
request_move_buildable
request_demolish_buildable
request_select_upgrade
apply_damage
add_coins
```

События описывают уже произошедшее изменение:

```text
run_state_changed
run_ended
wind_changed
anchor_state_changed
anchor_broken
orb_contact_started
shield_section_changed
defender_role_changed
defender_died
boarding_enemy_died
coins_changed
upgrade_selection_requested
```

---

## 21. Структура каталогов

```text
res://
├── scenes/
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
└── docs/
```

---

## 22. Следующая архитектурная итерация

Перед полноценным экипажем необходимо:

1. вынести параметры платформы и ветра в `Resource`;
2. отделить рулевой ввод от движения;
3. заменить тестовый щит полноценным `ShieldSystem`;
4. заменить `PrototypeWorld` реестром шаров и отдельным визуальным слоем;
5. добавить `CrewManager`, `CrewRoleManager` и `RoleStation`.

---

## 23. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец игровых данных.
- Дублирование состояния.
- Зависимость симуляции от визуала.
- Один огромный скрипт для ролей, врагов или карточек.
- Балансные значения, разбросанные по логике.
- Глубокие пути между независимыми сценами.
- Физическая сцена на каждого стратегического врага.
- Архитектурное изменение без обновления этого файла.
