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
- `CrewFailureController` немедленно завершает забег при нуле живых защитников, даже если идут кулдауны замен.

## 6. EconomyDomain

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

## 7. UpgradeDomain

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

После двадцатой покупки стоимость умножается на `post_linear_multiplier`.

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
проверка индекса и CARD_SELECTION
    ↓
RunEconomy.spend_coins(current_cost)
    ↓
_completed_purchases += 1
    ↓
достаточно монет?
    ├── да: новая выдача без снятия паузы
    └── нет: возврат в RUNNING
```

### Режим заглушек Prototype 1.1

- Все карточки используют один заголовок и одно описание.
- `choose_card()` не применяет игровой эффект.
- Выбор только списывает стоимость и увеличивает число покупок.
- Каталог, уровни, повторы, случайный выбор и применение эффектов отсутствуют намеренно.
- Будущий каталог подключается отдельным компонентом, а не разрастается внутри `UpgradeSystem`.

### UpgradeSelectionPanel

Отдельная сцена `scenes/ui/upgrade_selection_panel.tscn`.

Панель создаёт кнопки из `get_card_count()`, читает текст через `UpgradeSystem` и вызывает только `choose_card(index)`. Она не списывает монеты, не считает стоимость и не применяет эффекты.

## 8. PlatformDomain

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

## 9. OrbDomain и ShieldDomain

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

## 10. AnchorDomain

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

## 11. CrewDomain

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

## 12. CombatDomain

```text
HealthComponent
MeleeAttackComponent
DefenderCombatController
BoardingEnemyController
```

`MeleeAttackComponent` использует `READY`, `WINDUP`, `COOLDOWN`. Цель фиксируется в начале взмаха, начатая атака не перенаправляется. Боевые компоненты не начисляют монеты напрямую.

## 13. BoardingDomain

```text
AnchorPathRegistry
BoardingSpawnDirector
BoardingEnemyRegistry
BoardingMovementResolver
BoardingJumpPlanner
BoardingEnemyContainer
```

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

## 14. StrategicWaveDomain

Планируются:

```text
RunDifficulty
StrategicWaveDirector
StrategicWaveSystem
MinimapRenderer
```

Стратегические враги не создаются как `BoardingEnemy`, не регистрируются в `BoardingEnemyRegistry`, не дают монет и хранятся как агрегированные данные.

## 15. BuildableDomain

Планируются:

```text
BuildableInventory
BuildableGrid
MedicalStationSystem
TurretSystem
```

Будущая турель наносит обычный физический урон. Смерть физического врага с причиной `combat` использует существующий reward flow.

## 16. PresentationDomain

HUD, миникарта, указатели, визуалы, анимации, звук и эффекты не изменяют доменное состояние. HUD читает монеты из `RunEconomy`, а число покупок и стоимость — из `UpgradeSystem`. Копии этих значений в UI запрещены.

## 17. Обязательные тестовые границы

### Экономика

- Новый забег начинает экономику со `starting_coins`.
- `combat` и `anchor_path_closed` начисляют награду один раз.
- Технические и стратегические причины награды не дают.
- Неуспешное списание не меняет сумму.

### Карточки

- Первая стоимость 5, двадцатая 100, затем 200, 400, 800.
- Предложение открывается только при достаточных монетах и в `RUNNING`.
- Во время предложения мир полностью остановлен.
- Неверный индекс не списывает монеты.
- Обе временные карточки имеют одинаковое содержимое.
- Выбор не применяет игровой эффект.
- При достаточном остатке следующая выдача появляется без снятия паузы.
- При недостаточном остатке игра возвращается в `RUNNING`.
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

## 18. Следующая итерация

1. `RunDifficulty` как единый параметр сложности забега.
2. Плавный рост общего наземного лимита врагов.
3. Уменьшение интервала физического спавна со временем.
4. Начало стратегических волн.
5. Постоянно видимая миникарта.

Различные эффекты карточек остаются отложенными до отдельного проектирования каталога улучшений.

## 19. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец монет, стоимости или прогресса карточек.
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
- Один большой скрипт для ролей, врагов, экономики или карточек.
- Архитектурное изменение без обновления этого файла.
