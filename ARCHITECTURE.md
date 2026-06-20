# GloryProtect — архитектура проекта

Этот файл — **единственный источник правды для архитектуры проекта**. Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md). Изменение владельцев состояния, границ систем или направления зависимостей должно обновлять этот файл в том же наборе изменений.

## 1. Базовые принципы

- Godot **4.6.2 stable** и строго типизированный GDScript.
- Композиция небольших сцен и компонентов.
- Максимум 600 строк на поддерживаемый файл; с 450 строк файл оценивается на разделение.
- Каждое изменяемое состояние имеет одного владельца.
- Баланс хранится в типизированных `Resource`.
- UI читает состояние и отправляет команды, но не реализует механику.
- Визуальные компоненты не изменяют доменное состояние.
- Зависимости передаются явно через сцену, `NodePath`, ресурс или небольшой интерфейс.

## 2. Направление зависимостей

```text
Input / UI
    ↓ команды
Domain Systems
    ↓ события и снимки
Presentation
```

Доменные системы не зависят от HUD, спрайтов, расположения панелей или универсального глобального менеджера.

## 3. Высокоуровневая композиция

```text
GameRoot
├── GameFlowController
├── RunDifficulty
├── RunEconomy
├── UpgradeSystem
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
│   ├── BoardingRewardController
│   └── BuildableDomain
├── StrategicSimulation
└── CanvasLayer
    ├── PrototypeHUD
    └── UpgradeSelectionPanel
```

`GameRoot` только собирает системы и передаёт зависимости.

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Забег и пауза | `GameFlowController` |
| Активное время и нормализованная сложность | `RunDifficulty` |
| Кривая общей сложности | `RunDifficultyBalance` |
| Монеты забега | `RunEconomy` |
| Число покупок и открытая выдача | `UpgradeSystem` |
| Формула стоимости карточек | `UpgradeBalance` |
| Ветер | `WindSystem` |
| Позиция и скорость платформы | `PlatformController` |
| Доступность рулевого ввода | `SteeringInputProvider`, управляемый `CrewRoleManager` |
| Состояния якорей | `AnchorRuntimeStore` |
| Очереди операций якорей | `AnchorOperationQueue` |
| Активные пути абордажа | вычисляет `AnchorSystem`, публикует `AnchorPathRegistry` |
| Реестр физических врагов | `BoardingEnemyRegistry` |
| Состояние и координаты врага | его `BoardingEnemyController` |
| Координаты защитника | `DefenderMovement` |
| Здоровье сущности | её `HealthComponent` |
| Таймер атаки | её `MeleeAttackComponent` |
| Слоты экипажа | `CrewManager` |
| Роли и переходы | `CrewRoleManager` |
| Занятость постов | `RoleStationRegistry` |
| Кулдауны замен | `CrewReplacementController` |
| Энергетический контакт | `OrbContactSystem` |
| Пять значений щита | `ShieldSystem` |
| Геометрия шаров | `GroundOrbCatalog` через `GroundOrbRegistry` |
| Стратегические группы | будущий `StrategicWaveSystem` |
| Занятость клеток объектами | будущий `BuildableGrid` |

Stateless-компоненты не дублируют состояние владельцев. К ним относятся `BoardingMovementResolver`, `BoardingJumpPlanner`, `BoardingRewardController` и UI-панели.

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

Владеет началом забега, полной паузой и причиной поражения. `CARD_SELECTION` включает `SceneTree.paused`. `UpgradeSystem` и `UpgradeSelectionPanel` используют `PROCESS_MODE_ALWAYS`, чтобы работать во время паузы.

### Контроллеры поражения

- `ShieldFailureController` завершает забег при разрушении любой секции.
- `CrewFailureController` завершает забег при нуле живых защитников, даже если идут кулдауны замен.

## 6. DifficultyDomain

```text
RunDifficultyBalance
RunDifficulty
```

### RunDifficultyBalance

Единственный источник общей кривой:

```text
seconds_to_max_difficulty
growth_exponent
```

Он преобразует активное время в значение `0.0…1.0`. Кривая не знает о врагах, волнах, щите или экономике.

### RunDifficulty

Единственный владелец:

```text
_elapsed_seconds
_normalized_difficulty
```

Публичный интерфейс:

```text
get_elapsed_seconds()
get_normalized()
get_percent()
reset_for_run()
```

Правила:

- время растёт только в `RUNNING`;
- `START_DELAY`, `CARD_SELECTION`, `MANUAL_PAUSE` и `GAME_OVER` не увеличивают сложность;
- новый забег сбрасывает время и значение;
- максимальное значение ограничено `1.0`;
- система не знает, как конкретный домен использует сложность.

Потребители читают нормализованное значение и применяют собственный data-driven диапазон. Физический абордаж использует `BoardingBalance`; будущие стратегические волны будут использовать `StrategicWaveBalance`.

## 7. EconomyDomain

```text
EconomyBalance
RunEconomy
BoardingRewardController
```

### EconomyBalance

Единственный источник:

```text
starting_coins
boarding_enemy_base_reward
rewarded_boarding_death_reasons
```

Текущие награждаемые причины: `combat` и `anchor_path_closed`.

### RunEconomy

Единственный владелец суммы монет.

```text
get_coins()
can_afford(cost)
add_coins(amount, source)
spend_coins(cost, source)
reset_for_run()
```

Сумма не может стать отрицательной. Нулевые и отрицательные начисления игнорируются. Неуспешная покупка не изменяет состояние. Новый забег сбрасывает валюту. `RunEconomy` не знает о врагах, карточках или HUD.

### BoardingRewardController

```text
BoardingEnemy.kill(reason)
    ↓
BoardingEnemyRegistry.enemy_removed(enemy_id, reason)
    ↓
BoardingRewardController
    ↓
RunEconomy.add_coins(amount, reason)
```

Стратегические враги не используют этот поток и не дают монет.

## 8. UpgradeDomain

```text
UpgradeBalance
UpgradeSystem
UpgradeSelectionPanel
```

### UpgradeBalance

Единственный источник параметров выдачи:

```text
cards_per_offer
linear_offer_count
linear_step_cost
post_linear_multiplier
placeholder_title
placeholder_description
```

Стоимость по числу завершённых покупок:

```text
0 → 5
1 → 10
...
19 → 100
20 → 200
21 → 400
22 → 800
```

### UpgradeSystem

Единственный владелец `_completed_purchases`, `_offer_open`, номера текущей выдачи и решения об открытии следующей выдачи.

```text
get_completed_purchase_count()
get_current_offer_number()
get_current_cost()
get_card_count()
get_card_title(index)
get_card_description(index)
is_offer_open()
choose_card(index)
reset_for_run()
```

Открытие:

```text
RunEconomy.coins_changed
    ↓
проверка RUNNING и can_afford(current_cost)
    ↓
begin_card_selection()
    ↓
offer_opened
```

Выбор:

```text
choose_card(index)
    ↓
RunEconomy.spend_coins(current_cost)
    ↓
_completed_purchases += 1
    ↓
достаточно монет?
    ├── да: новая выдача без снятия паузы
    └── нет: возврат в RUNNING
```

### Режим заглушек

- Все карточки используют один заголовок и описание.
- `choose_card()` не применяет игровой эффект.
- Выбор только списывает стоимость и увеличивает число покупок.
- Каталог, уровни, повторы, случайный выбор и эффекты отсутствуют намеренно.
- Будущий каталог подключается отдельным компонентом, а не разрастается внутри `UpgradeSystem`.

### UpgradeSelectionPanel

Отдельная сцена `scenes/ui/upgrade_selection_panel.tscn`. Панель читает данные через `UpgradeSystem` и вызывает только `choose_card(index)`. Она не списывает монеты, не считает стоимость и не применяет эффекты.

## 9. PlatformDomain

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

`PlatformController` владеет горизонтальной позицией и скоростью, применяет рулевое усилие, ветер, сопротивление, предел скорости, границы мира и якорные ограничения. `PlatformVisualController` только отображает платформу, клетки, посты, шар и дверь замены.

## 10. OrbDomain и ShieldDomain

```text
GroundOrbCatalog
GroundOrbRegistry
OrbContactSystem
GroundOrbVisualController
ShieldBalance
ShieldSystem
ShieldRechargeController
ShieldFailureController
```

- `GroundOrbCatalog` хранит пять позиций и контактную геометрию.
- `GroundOrbRegistry` публикует координаты, зоны и точки крепления.
- `OrbContactSystem` владеет активным контактом.
- `ShieldSystem` владеет пятью значениями прочности.
- `ShieldRechargeController` преобразует контакт в восстановление связанной секции.
- Визуальный контроллер состояние не изменяет.

## 11. AnchorDomain

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

BoardingDomain получает только `AnchorPathSnapshot`:

```text
anchor_id
side
orb_id
ground_point
platform_point
```

Внутренний store наружу не раскрывается.

## 12. CrewDomain

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

- `CrewManager` владеет стабильными `defender_id`; замена получает прежний ID и полное здоровье.
- `CrewReplacementController` владеет независимыми таймерами и не создаёт защитника внутри врага.
- `CrewRoleManager` владеет текущими и ожидающими ролями.
- `DefenderMovement` владеет целевой координатой, приостанавливается на бой и не проходит сквозь врагов.
- Союзные защитники друг друга не блокируют.

## 13. CombatDomain

```text
HealthComponent
MeleeAttackComponent
DefenderCombatController
BoardingEnemyController
```

`MeleeAttackComponent` использует `READY`, `WINDUP`, `COOLDOWN`. Цель фиксируется в начале взмаха, начатая атака не перенаправляется. Боевые компоненты не начисляют монеты напрямую.

## 14. BoardingDomain

```text
AnchorPathRegistry
BoardingSpawnDirector
BoardingEnemyRegistry
BoardingMovementResolver
BoardingJumpPlanner
BoardingEnemyContainer
```

### BoardingSpawnDirector

Получает `RunDifficulty` явной зависимостью и не хранит время забега.

```text
current difficulty
    ↓
BoardingBalance.get_ground_limit_for_difficulty()
BoardingBalance.get_spawn_interval_for_difficulty()
    ↓
текущий общий лимит и интервал
```

Текущие диапазоны:

```text
ground limit: 8 → 20
spawn interval: 3.0 → 0.8 seconds
```

`BoardingBalance` является единственным источником этих диапазонов и формул интерполяции.

### BoardingEnemyRegistry

Выдаёт `enemy_id`, хранит активных физических врагов, удаляет запись при первой смерти и публикует `enemy_removed(enemy_id, reason)` ровно один раз.

### BoardingEnemyController

```text
WAITING_WITHOUT_PATH
RUNNING_TO_ANCHOR
CLIMBING
ON_PLATFORM
FIGHTING
JUMPING
DEAD
```

Владеет состоянием и координатами конкретного врага.

### BoardingMovementResolver

Stateless-сервис разделяет врагов, формирует очередь на тросе, блокирует пересечение врага и защитника, резервирует точки приземления и ищет свободную позицию замены.

### BoardingJumpPlanner

Возвращает план прыжка только при пробке перед защитником, свободной точке за спиной и допустимой длине. Состояние врага не меняет.

## 15. StrategicWaveDomain

Планируются:

```text
StrategicWaveBalance
StrategicWaveDirector
StrategicWaveSystem
MinimapRenderer
```

Будущие стратегические системы получают существующий `RunDifficulty`, но используют собственные параметры размера, интервала и распределения волн. Они не создаются как `BoardingEnemy`, не регистрируются в `BoardingEnemyRegistry`, не дают монет и хранятся как агрегированные данные.

## 16. BuildableDomain

Планируются:

```text
BuildableInventory
BuildableGrid
MedicalStationSystem
TurretSystem
```

Будущая турель наносит обычный физический урон. Смерть физического врага с причиной `combat` использует существующий reward flow.

## 17. PresentationDomain

HUD, миникарта, указатели, визуалы, анимации, звук и эффекты не изменяют доменное состояние.

HUD читает:

- монеты из `RunEconomy`;
- число покупок и стоимость из `UpgradeSystem`;
- время и процент сложности из `RunDifficulty`;
- текущий лимит и интервал из `BoardingSpawnDirector`.

Копии этих значений в UI запрещены.

## 18. Обязательные тестовые границы

### Сложность

- Начальное значение равно `0.0`.
- Половина времени даёт `0.5` при линейной кривой.
- Максимум ограничен `1.0`.
- Сложность растёт только в `RUNNING`.
- Новый забег сбрасывает прогресс.
- Начало, середина и максимум дают лимиты `8`, `14`, `20`.
- Интервалы равны `3.0`, `1.9`, `0.8`.

### Экономика

- Новый забег начинает экономику со `starting_coins`.
- `combat` и `anchor_path_closed` начисляют награду один раз.
- Технические и стратегические причины награды не дают.
- Неуспешное списание не меняет сумму.

### Карточки

- Первая стоимость 5, двадцатая 100, затем 200, 400, 800.
- Предложение открывается только при достаточных монетах и в `RUNNING`.
- Во время предложения мир полностью остановлен.
- Обе временные карточки имеют одинаковое содержимое и не применяют эффект.
- При достаточном остатке следующая выдача появляется без снятия паузы.
- Новый забег сбрасывает число покупок.

### Остальные системы

- Контакт заряжает только связанную секцию.
- Разрушение секции завершает забег.
- Ноль живых защитников завершает забег немедленно.
- Без якорей физический спавн запрещён.
- Враги сохраняют минимальные дистанции.
- Защитник и враг не проходят друг сквозь друга.
- Прыжок требует пробки и свободной точки приземления.
- Лимит 600 строк не нарушен.

## 19. Следующая итерация

1. `StrategicWaveBalance`.
2. `StrategicWaveDirector`.
3. Агрегированные группы стратегических врагов.
4. Случайное распределение волны между секциями.
5. Постоянно видимая миникарта.
6. Масштабирование стратегических волн от существующего `RunDifficulty`.

Различные эффекты карточек остаются отложенными до отдельного проектирования каталога улучшений.

## 20. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- Второй владелец времени или нормализованной сложности забега.
- Хардкод диапазонов сложности внутри `BoardingSpawnDirector`.
- Собственный таймер сложности в физическом или стратегическом спавнере.
- UI как владелец монет, стоимости, прогресса карточек или сложности.
- Изменение монет вне `RunEconomy`.
- Расчёт стоимости вне `UpgradeBalance`.
- Увеличение счётчика покупок вне `UpgradeSystem`.
- Списание монет из `UpgradeSelectionPanel`.
- Применение эффектов прямо внутри UI.
- Большой каталог эффектов внутри `UpgradeSystem`.
- Начисление монет внутри врага, оружия или якоря.
- Дублирование роли вне `CrewRoleManager`.
- Дублирование здоровья вне `HealthComponent`.
- Зависимость симуляции от визуала.
- Один большой скрипт для ролей, врагов, экономики, сложности или карточек.
- Архитектурное изменение без обновления этого файла.
