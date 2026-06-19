# GloryProtect — архитектура проекта

Этот файл является **единственным источником правды для архитектуры проекта**.

Инженерные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md).

Любое изменение границ систем, владельцев состояния, направления зависимостей или структуры проекта должно сопровождаться обновлением этого файла в том же коммите.

---

## 1. Технологическая база

- Движок: **Godot 4.6.2 stable**.
- Язык: GDScript.
- Основной стиль: композиция сцен и компонентов.
- Игровая симуляция отделена от UI и визуальных эффектов.
- Все балансные параметры должны быть data-driven.
- Ни один исходный файл не может превышать 600 строк.

---

## 2. Архитектурные цели

Архитектура должна обеспечивать:

1. независимую разработку игровых систем;
2. отсутствие монолитного глобального контроллера;
3. один источник правды для каждого состояния;
4. возможность тестировать системы отдельно;
5. замену временного визуала без переписывания симуляции;
6. расширение списка врагов и улучшений через данные;
7. сохранение читаемых зависимостей;
8. возможность постепенно собирать вертикальный срез.

---

## 3. Высокоуровневая схема

```text
GameRoot
├── GameFlow
├── Difficulty
├── World
│   ├── PlatformDomain
│   ├── OrbDomain
│   ├── CrewDomain
│   ├── CombatDomain
│   ├── BoardingDomain
│   └── BuildableDomain
├── StrategicSimulation
│   ├── ShieldDomain
│   └── StrategicWaveDomain
├── Economy
│   ├── RunEconomy
│   └── UpgradeSystem
└── Presentation
    ├── HUD
    ├── Minimap
    ├── Audio
    └── VisualEffects
```

`GameRoot` только собирает зависимости и запускает системы. Он не содержит детальную механику.

---

## 4. Направление зависимостей

Разрешённое направление:

```text
Presentation/Input
        ↓ команды
Application / Domain Systems
        ↓ события состояния
Presentation
```

Доменные системы могут зависеть от:

- собственных ресурсов данных;
- небольших интерфейсов соседнего домена;
- событий более высокого уровня;
- явно переданных ссылок.

Доменные системы не должны зависеть от:

- HUD;
- конкретного визуального узла;
- расположения панели интерфейса;
- глубокой сцены другого домена;
- глобального универсального менеджера.

---

## 5. Владельцы состояния

| Данные | Единственный владелец |
|---|---|
| Состояние забега и паузы | `GameFlowController` |
| Прошедшее время забега | `RunClock` |
| Текущая сложность | `DifficultyDirector` |
| Направление и сила ветра | `WindSystem` |
| Позиция и горизонтальная скорость платформы | `PlatformMovementController` |
| Состояния и операции четырёх якорей | `AnchorSystem` |
| Контакт платформенного и наземного шара | `OrbContactSystem` |
| Прочность пяти секций | `ShieldSystem` |
| Текущая роль каждого защитника | `CrewRoleManager` |
| Здоровье сущности | её `HealthComponent` |
| Текущее неделимое действие защитника | его `DefenderActionController` |
| Состояние физического врага | его `BoardingEnemyStateMachine` |
| Стратегические группы | `StrategicWaveSystem` |
| Занятость клеток объектами | `BuildableGrid` |
| Монеты забега | `RunEconomy` |
| Порядок и стоимость улучшений | `UpgradeSystem` |

UI и визуальные узлы не являются владельцами перечисленных данных.

---

## 6. Корневая сцена

Рекомендуемая композиция:

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

Корневая сцена:

- создаёт подсистемы;
- передаёт явные зависимости;
- запускает забег;
- не реализует движение, бой, спавн, лечение или экономику.

---

## 7. GameFlow

### 7.1. GameFlowController

Владеет состоянием забега:

```text
BOOT
START_DELAY
RUNNING
CARD_SELECTION
MANUAL_PAUSE
GAME_OVER
```

Ответственность:

- начало забега;
- стартовая задержка;
- ручная пауза;
- пауза карточек;
- завершение;
- причина поражения;
- разрешение или запрет игрового ввода.

Не отвечает за:

- тайминг волн;
- движение;
- урон;
- состояние щита;
- отображение паузы.

### 7.2. RunClock

Отдельно хранит время активного забега и не считает время полной паузы.

---

## 8. DifficultyDomain

### DifficultyDirector

Владеет единым параметром сложности, растущим со временем.

Выдаёт снимки параметров:

```text
DifficultySnapshot
├── strategic_wave_size
├── strategic_spawn_interval
├── strategic_max_groups
├── boarding_spawn_interval
└── boarding_ground_limit
```

Не создаёт врагов самостоятельно.

Потребители:

- `StrategicWaveDirector`;
- `BoardingSpawnDirector`.

---

## 9. PlatformDomain

Домен должен быть разделён минимум на следующие части.

### 9.1. PlatformMovementController

Владеет:

- горизонтальной позицией;
- горизонтальной скоростью;
- применением сил;
- ограничением скорости;
- мировыми границами;
- ограничениями тросами.

Получает данные от:

- `SteeringInputProvider`;
- `WindSystem`;
- `AnchorConstraintProvider`.

Не хранит состояние якорей.

### 9.2. SteeringInputProvider

Преобразует ввод игрока в ось управления только при наличии активного рулевого.

Не изменяет скорость напрямую.

### 9.3. WindSystem

Владеет:

- направлением;
- уровнем силы 1–3;
- фактическим текущим усилием;
- расписанием изменений.

Не двигает платформу напрямую.

### 9.4. PlatformGrid

Описывает фиксированный ряд ячеек платформы.

Используется для:

- рабочих постов;
- размещаемых объектов;
- позиционирования персонажей;
- проверки занятости объектами.

Размер платформы не изменяется во время забега.

---

## 10. AnchorDomain

`AnchorSystem` является владельцем четырёх якорей, но не должен оставаться одним большим файлом.

Рекомендуемое разбиение:

```text
AnchorSystem
├── AnchorRuntimeStore
├── AnchorCommandController
├── AnchorOperationQueue
├── AnchorConstraintProvider
├── AnchorOverloadController
├── AnchorAttachmentGeometry
└── AnchorVisualController
```

### 10.1. AnchorRuntimeStore

Хранит состояния четырёх якорей:

```text
STOWED
QUEUED
INSTALLING
ATTACHED
OVERLOADED
RETURNING
```

### 10.2. AnchorCommandController

Принимает команды:

```text
request_toggle(anchor_id)
request_remove_all()
set_operator_available(side, available)
```

Проверяет допустимость, но не рисует силуэты.

### 10.3. AnchorOperationQueue

Владеет текущей операцией и очередью каждой стороны.

Начатая установка не зависит от жизни защитника после запуска операции.

### 10.4. AnchorConstraintProvider

Предоставляет платформе:

- минимально допустимую координату;
- максимально допустимую координату;
- полную фиксацию;
- фиксированную координату.

Не изменяет позицию платформы самостоятельно.

### 10.5. AnchorOverloadController

Управляет:

- перегрузкой одиночного якоря;
- таймером;
- отменой при ослаблении ветра;
- отменой вторым якорем;
- переходом к возврату.

### 10.6. AnchorVisualController

Отвечает только за:

- тросы;
- силуэты;
- мигание;
- визуал возврата;
- анимации установки и снятия.

---

## 11. OrbDomain и ShieldDomain

### 11.1. GroundOrbRegistry

Хранит определения пяти шаров:

- позицию;
- связанную секцию;
- контактную зону;
- расширенную якорную зону;
- четыре точки крепления.

### 11.2. OrbContactSystem

Определяет текущий контакт платформы с одним наземным шаром.

Публикует:

```text
contact_started(orb_id)
contact_ended(orb_id)
```

Не изменяет прочность щита напрямую.

### 11.3. ShieldSystem

Владеет пятью секциями.

Принимает:

```text
apply_damage(section_id, amount)
restore(section_id, amount)
```

Публикует:

```text
section_changed
section_indicator_changed
section_entered_critical
section_destroyed
```

### 11.4. ShieldRechargeController

Получает активный контакт и применяет восстановление через публичный интерфейс `ShieldSystem`.

---

## 12. CrewDomain

Рекомендуемая композиция защитника:

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

### 12.1. CrewManager

Владеет:

- реестром защитников;
- живым или мёртвым состоянием;
- таймерами замены;
- созданием нового защитника из двери.

Не реализует конкретные роли.

### 12.2. CrewRoleManager

Владеет текущими назначениями.

Принимает:

```text
request_assignment(defender_id, role_target_id)
release_assignment(defender_id)
```

Учитывает:

- занятость поста;
- физическое прибытие;
- ожидание завершения неделимого действия;
- демонтаж объекта;
- смерть защитника.

### 12.3. RoleStation

Общий интерфейс рабочего места:

```text
can_accept(defender_id)
reserve(defender_id)
activate(defender_id)
release(defender_id)
```

Конкретные реализации:

- рулевой пост;
- левый якорный пост;
- правый якорный пост;
- медицинский пост;
- турель.

### 12.4. DefenderActionController

Владеет текущим неделимым действием:

- взмах меча;
- рулевая команда;
- лечебный цикл;
- выстрел;
- операция якоря до передачи её `AnchorOperationQueue`.

---

## 13. CombatDomain

Компоненты:

```text
HealthComponent
DamageCommand
TargetSelector
MeleeAttackComponent
RangedAttackComponent
CombatResolver
DeathComponent
```

### 13.1. HealthComponent

Единственный владелец здоровья сущности.

### 13.2. CombatResolver

Применяет завершённые попадания.

Начатая атака хранит стабильную цель и не перенаправляется после смерти цели.

### 13.3. TargetSelector

Каждый тип поведения имеет собственную политику выбора:

- защитник у поста — ближайший в локальной зоне;
- свободный защитник — ближайший враг на платформе;
- враг — ближайший живой защитник;
- турель — ближайший враг в круговом радиусе.

---

## 14. BoardingDomain

Рекомендуемое разделение:

```text
BoardingSpawnDirector
GroundEnemyRegistry
AnchorPathRegistry
BoardingEnemy
└── BoardingEnemyStateMachine
```

### 14.1. BoardingSpawnDirector

Владеет:

- интервалом спавна;
- общим наземным лимитом;
- выбором стороны появления;
- остановкой спавна при отсутствии всех якорей.

### 14.2. AnchorPathRegistry

Предоставляет список доступных маршрутов и их позиции.

Враг фиксирует выбранный маршрут до его недоступности.

### 14.3. BoardingEnemyStateMachine

Состояния:

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

### 14.4. GroundEnemyRegistry

Считает всех врагов на земле для общего лимита обеих сторон.

---

## 15. StrategicWaveDomain

Стратегические враги представлены агрегированными данными, а не отдельными физическими сценами.

### 15.1. StrategicWaveDirector

Создаёт волны на основе `DifficultySnapshot`.

### 15.2. StrategicWaveSystem

Владеет группами:

```text
StrategicGroup
├── enemy_count
├── normalized_position
├── target_section_id
├── speed
└── damage_per_enemy
```

Отвечает за:

- движение;
- объединение;
- разделение;
- отдельные импульсы урона;
- удаление опустевших групп.

### 15.3. MinimapRenderer

Только отображает группы и секции. Не владеет количеством врагов.

---

## 16. BuildableDomain

### 16.1. BuildableInventory

Владеет полученными, но не установленными объектами.

### 16.2. BuildableGrid

Владеет занятостью ячеек объектами.

Персонаж на клетке не делает её занятой для установки объекта.

### 16.3. MedicalStationSystem

Владеет единственным медицинским постом и его текущей позицией.

Логика выбора пациента находится в `MedicalTargetSelector`, а лечебный цикл — в `HealingAction`.

### 16.4. TurretSystem

Каждая турель имеет собственный runtime и оператора.

Стрельба разделяется на:

- выбор цели;
- кулдаун;
- неделимое действие выстрела;
- применение урона через `CombatResolver`.

---

## 17. EconomyDomain

### 17.1. RunEconomy

Единственный владелец монет текущего забега.

Принимает события смерти физического врага с причиной.

### 17.2. UpgradeSystem

Владеет:

- номером следующей выдачи;
- ценой;
- текущими двумя карточками;
- последовательной цепочкой покупок.

### 17.3. UpgradeCatalog

Содержит data-driven определения карточек.

Эффекты не реализуются одним большим `match`. Используются отдельные обработчики эффектов или композиция модификаторов.

---

## 18. PresentationDomain

Содержит:

- HUD;
- миникарту;
- указатели целей;
- визуал платформы;
- визуал тросов;
- анимации персонажей;
- звук;
- эффекты.

Presentation:

- подписывается на события;
- читает публичные снимки состояния;
- отправляет команды;
- не меняет доменные данные напрямую.

---

## 19. Ресурсы данных

Рекомендуемые ресурсы:

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

Каждый ресурс должен иметь типизированный `Resource`-класс.

---

## 20. Команды и события

### 20.1. Команды

```text
request_assign_role(defender_id, role_target_id)
request_toggle_anchor(anchor_id)
request_remove_all_anchors()
request_place_buildable(buildable_id, cell_id)
request_move_buildable(buildable_id, cell_id)
request_demolish_buildable(buildable_id)
request_select_upgrade(upgrade_id)
apply_damage(section_id, amount)
add_coins(amount, source)
```

### 20.2. События

```text
run_state_changed
run_ended
wind_changed
platform_velocity_changed
anchor_state_changed
anchor_broken
orb_contact_started
orb_contact_ended
shield_section_changed
shield_section_destroyed
defender_role_changed
defender_died
defender_replaced
boarding_enemy_died
strategic_group_changed
coins_changed
upgrade_selection_requested
```

События не должны содержать скрытый запрос на изменение чужого состояния.

---

## 21. Структура каталогов

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
│   ├── balance/
│   └── definitions/
├── tests/
│   ├── unit/
│   └── integration/
└── docs/
```

Общие `utils` допускаются только для чистых, действительно общих функций и не могут становиться складом несвязанной логики.

---

## 22. Ограничение размера и разбиение

Жёсткий предел любого исходного файла — 600 строк.

При приближении к 450 строкам система должна быть оценена на разбиение.

Текущий `AnchorSystem` прототипа уже должен быть разделён перед дальнейшим существенным расширением на:

- runtime store;
- command controller;
- operation queue;
- constraint provider;
- overload controller;
- visual controller.

Новая функциональность не должна бесконечно добавляться в существующий прототипный файл.

---

## 23. Текущая реализация и целевая архитектура

Текущая версия `Prototype 0.2` является ранним вертикальным каркасом.

Существующие временные файлы:

```text
prototype_world.gd
prototype_shield_system.gd
prototype_hud.gd
anchor_system.gd
platform_controller.gd
wind_system.gd
```

Перед добавлением полноценного экипажа необходимо:

1. вынести баланс в ресурсы;
2. разделить якорный прототип по компонентам;
3. отделить ввод рулевого от движения платформы;
4. заменить тестовую секцию полноценным `ShieldSystem`;
5. заменить `PrototypeWorld` реестром шаров и отдельным визуальным слоем.

---

## 24. Изменение архитектуры

Архитектурное изменение допустимо только если:

- существующая граница систем объективно мешает реализации;
- определён новый единственный владелец состояния;
- исключено дублирование;
- описано направление зависимостей;
- обновлён этот файл;
- обновлены связанные тесты и правила при необходимости.

Нельзя вводить архитектурное отклонение как временный хардкод без документации.

---

## 25. Запрещённые архитектурные решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец игровых данных.
- Дублирование состояния между доменами.
- Прямая зависимость симуляции от визуала.
- Один огромный скрипт для всех типов ролей.
- Один огромный скрипт для всех врагов.
- Один `match` для всех карточек улучшений.
- Балансные значения, разбросанные по логике.
- Прямые глубокие пути между независимыми сценами.
- Физическая сцена на каждого стратегического врага миникарты.
- Изменение архитектуры без обновления `ARCHITECTURE.md`.
