# GloryProtect — архитектура проекта

Этот файл — единственный источник правды для архитектуры. Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md).

## 1. Основные правила

- Godot 4.6.2 stable, строго типизированный GDScript.
- Максимум 600 строк на поддерживаемый файл; с 450 строк файл оценивается на разделение.
- Каждое изменяемое состояние имеет одного владельца.
- Настройки и баланс находятся в типизированных `Resource`.
- UI читает состояние и отправляет команды, но не реализует механику.
- Представление не изменяет симуляцию.
- Архитектурное изменение обновляет этот файл в том же наборе изменений.

## 2. Направление зависимостей

```text
Input / UI
    ↓ команды
Domain systems
    ↓ события и неизменяемые снимки
Presentation
```

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
├── ShieldCriticalAlertController
├── Input adapters
├── World
│   ├── OrbDomain
│   ├── StrategicWaveDomain
│   ├── AnchorDomain
│   ├── BoardingDomain
│   ├── BuildableGrid
│   ├── MedicalStationSystem
│   └── Platform
│       ├── PlatformVisualController
│       ├── BuildableGridVisual
│       ├── CrewManager
│       ├── CrewRoleManager
│       └── Camera2D
└── CanvasLayer
    ├── PrototypeHUD
    ├── StrategicMinimap
    ├── ShieldCriticalAlertPresenter
    ├── UpgradeSelectionPanel
    └── GameOverPanel
```

`GameRoot` только собирает системы и передаёт зависимости.

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Состояние забега и пауза | `GameFlowController` |
| Активное время и общая сложность | `RunDifficulty` |
| Текущие физические убийства и финальный результат | `RunStatistics` |
| Лучшие результаты текущего запуска | `SessionRecordsStore` |
| Монеты | `RunEconomy` |
| Выдача и число покупок карточек | `UpgradeSystem` |
| Открытое количество размещаемых объектов | `BuildableInventory` |
| Размещённые объекты и занятость клеток | `BuildableGrid` |
| Текущий цикл лечения и выбранная цель | `MedicalStationSystem` |
| Пять значений щита | `ShieldSystem` |
| Активные стратегические группы и маршруты | `StrategicWaveSystem` |
| Таймер и номер волны | `StrategicWaveDirector` |
| Таймер и RNG мутаций групп | `StrategicGroupMutationController` |
| Положение и скорость платформы | `PlatformController` |
| Состояния якорей | `AnchorRuntimeStore` |
| Реестр физических врагов | `BoardingEnemyRegistry` |
| Роли экипажа и занятость постов | `CrewRoleManager` + `RoleStationRegistry` |
| Здоровье сущности | её `HealthComponent` |
| Таймер атаки | её `MeleeAttackComponent` |

## 5. GameFlowDomain

```text
BOOT
START_DELAY
RUNNING
CARD_SELECTION
MANUAL_PAUSE
GAME_OVER
```

`GameFlowController` владеет переходами, полной паузой и причиной поражения.

`restart_run()` разрешён только из `GAME_OVER` и перезагружает текущую сцену. Это гарантирует чистое состояние всех систем без частичного ручного сброса.

## 6. PlatformDomain

```text
PlatformController
PlatformBalance
PlatformVisualController
```

`PlatformController` владеет горизонтальной физикой и является единственным источником геометрии клеток:

```text
get_cell_count()
is_valid_cell(cell_index)
get_cell_local_x(cell_index)
get_nearest_cell_index(local_x)
```

Ни BuildableDomain, ни роли, ни визуал не повторяют формулу положения клетки.

## 7. BuildableDomain

```text
BuildableType
BuildableBalance
BuildableRuntime
BuildableSnapshot
BuildableInventory
BuildableGrid
BuildableDebugInput
BuildableGridVisual
```

### BuildableType

Текущие идентификаторы:

```text
MEDICAL_STATION
TURRET
```

`TURRET` пока является только точкой расширения. Его максимальное доступное количество равно нулю.

### BuildableBalance

Единственный источник:

```text
максимального количества медицинских постов
стартовой выбранной клетки
списка служебных клеток
интервала и величины лечения
радиуса лечения
размеров визуала поста
```

### BuildableInventory

Владеет открытым количеством каждого типа.

```text
unlock(type_id, amount)
get_unlocked_count(type_id)
is_unlocked(type_id)
can_deploy(type_id, deployed_count)
```

Демонтаж не удаляет открытие.

### BuildableGrid

Единственный владелец:

```text
Dictionary[buildable_id, BuildableRuntime]
Dictionary[cell_index, buildable_id]
```

Атомарные операции:

```text
place(type_id, cell_index)
move(buildable_id, cell_index)
demolish(buildable_id)
```

Правила:

- одна клетка содержит максимум один объект;
- служебные клетки недоступны;
- наличие персонажа на клетке не проверяется;
- объекты не создают коллизий;
- количество размещённых объектов не превышает открытое количество;
- наружу выдаются только `BuildableSnapshot`.

### BuildableDebugInput

Временный адаптер прототипа:

```text
, / .    выбрать клетку
B        открыть медицинский пост
M        установить или перенести
Delete   демонтировать
H        назначить выбранного защитника лекарем
```

Он не владеет открытиями, объектами или ролями.

### BuildableGridVisual

Находится внутри `Platform`, читает снимки и рисует:

- выбранную клетку;
- доступность клетки;
- медицинский пост.

Визуальный объект не содержит коллизий и не влияет на симуляцию.

## 8. DynamicRoleStationDomain

`MEDIC` является динамическим фиксированным постом.

`RoleStationRegistry` поддерживает:

```text
set_dynamic_target(role_id, local_x)
clear_dynamic_target(role_id)
has_station(role_id)
reserve(role_id, defender_id)
```

`CrewRoleManager` остаётся единственным владельцем назначений.

При установке поста `MedicalStationSystem` сообщает координату роли через:

```text
set_dynamic_role_station(MEDIC, true, local_x)
```

При переносе:

- новая координата заменяет старую;
- защитник, идущий к посту, получает новую цель;
- текущий цикл лечения не прерывается.

При демонтаже:

- цикл лечения отменяется;
- роль `MEDIC` становится недоступной;
- назначенный или направляющийся лекарь немедленно становится `FREE_FIGHTER`;
- занятость поста освобождается.

## 9. MedicalStationDomain

```text
MedicalStationSystem
BuildableBalance
CrewManager
CrewRoleManager
HealthComponent
```

`MedicalStationSystem` не владеет здоровьем и не изменяет роли напрямую. Он отправляет команды `CrewRoleManager` только при появлении или исчезновении динамического поста.

### Доступность

Без установленного медицинского поста:

- роль `MEDIC` недоступна;
- лечение не выполняется.

### Выбор цели

Из живых защитников выбирается:

1. защитник с минимальным `current_health`;
2. при равенстве — ближайший к лекарю;
3. полностью здоровые цели игнорируются.

Лекарь может лечить себя, если является наиболее раненой целью.

### Цикл лечения

```text
добежать до цели
    ↓
непрерывный контакт heal_interval
    ↓
HealthComponent.heal(heal_amount)
    ↓
повторная оценка всех целей
```

Текущие параметры:

```text
heal_interval = 5.0 seconds
heal_amount = 1 segment
heal_range = 18
```

Если цель выходит из радиуса, таймер непрерывного цикла сбрасывается. При паузе, карточках и `GAME_OVER` таймер не меняется.

### Переназначение

`CrewRoleManager` спрашивает:

```text
MedicalStationSystem.is_healing_cycle_active(defender_id)
```

Если цикл уже начат:

- новое назначение переходит в `WAITING_FOR_ACTION`;
- лекарь завершает восстановление одного сегмента;
- после завершения цикла начинается переход к новой роли;
- новый цикл лечения не запускается.

### Бой

`DefenderCombatController` не разрешает ближний бой роли `MEDIC`. Во время перехода к роли защитник по общим правилам может остановиться и сразиться с врагом; после активации роли лекарь больше не атакует.

## 10. CrewDomain

```text
CrewManager
CrewRoleManager
RoleStationRegistry
CrewReplacementController
Defender
HealthComponent
DefenderMovement
DefenderCombatController
```

`CrewManager` владеет стабильными `defender_id`. `CrewRoleManager` владеет текущей и целевой ролью. `HealthComponent` остаётся единственным владельцем здоровья.

## 11. StrategicWaveDomain

`StrategicWaveSystem` — единственный владелец агрегированных групп.

Поддерживаются:

- движение и удары по секциям;
- объединение;
- разделение;
- перенаправление;
- сохранение количества врагов;
- миникарта по неизменяемым снимкам.

Стратегические враги не участвуют в физическом бою, экономике или статистике убийств.

## 12. Statistics, Economy и Upgrade

- `RunDifficulty` владеет активным временем.
- `RunStatistics` владеет физическими убийствами и финальным снимком.
- `RunEconomy` владеет монетами.
- `UpgradeSystem` владеет выдачей и числом покупок.
- Карточки пока одинаковы и не применяют эффекты.

## 13. ShieldCriticalAlertDomain

`ShieldSystem.section_entered_critical` проходит через `ShieldCriticalAlertController`, который объединяет секции одного кадра в одно событие. Presenter показывает одно сообщение и воспроизводит один процедурный сигнал.

## 14. Обязательные тестовые границы

### BuildableGrid

- Закрытый объект нельзя установить.
- Служебную клетку нельзя занять.
- На клетке может находиться максимум один объект.
- Второй медицинский пост запрещён.
- Перенос освобождает старую клетку и занимает новую.
- Демонтаж освобождает клетку, но не удаляет открытие.
- Координата снимка совпадает с `PlatformController.get_cell_local_x()`.

### MedicalStationSystem

- Роль `MEDIC` недоступна без поста.
- После установки выбранный защитник физически прибывает к посту.
- Выбирается наиболее раненая цель.
- При равенстве выбирается ближайшая.
- Карточки останавливают таймер лечения.
- Один завершённый цикл восстанавливает один сегмент.
- Переназначение ждёт завершения текущего цикла.
- После завершения цикла новый цикл при ожидающем назначении не начинается.
- Перенос поста не отменяет текущий цикл.
- Демонтаж немедленно освобождает лекаря.
- Лекарь не использует ближний бой.

### Общие

- Здоровье изменяется только через `HealthComponent`.
- UI не владеет размещением или лечением.
- Карточки полностью останавливают симуляцию.
- Лимит 600 строк не нарушен.

## 15. Следующая итерация

1. Базовая турель как размещаемый объект.
2. Несколько турелей на разных клетках.
3. Отдельный оператор каждой турели.
4. Стрельба по физическим врагам в радиусе.
5. Урон турели через существующий физический combat/reward flow.
6. Перенос и демонтаж турели.

Карточки остаются заглушками до отдельного проектирования каталога улучшений.

## 16. Запрещённые решения

- Второй владелец занятости клеток.
- Хранение размещённых объектов в визуальном компоненте.
- Повторение формулы координаты клетки вне `PlatformController`.
- Изменение здоровья напрямую вне `HealthComponent`.
- Подсчёт таймера лечения в `CrewRoleManager` или HUD.
- Ближний бой активного лекаря.
- Прерывание уже начатого цикла обычным переназначением.
- Сохранение роли `MEDIC` после демонтажа поста.
- Установка объектов на служебные клетки.
- Физическая коллизия размещаемого поста с персонажами.
- Реализация турели внутри медицинской системы.
- Глобальный менеджер всех объектов и ролей.
- Архитектурное изменение без обновления этого файла.
