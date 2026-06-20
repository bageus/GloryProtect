# GloryProtect — архитектура проекта

Этот файл является **единственным источником правды для архитектуры проекта**.

Обязательные ограничения находятся в [`PROJECT_RULES.md`](PROJECT_RULES.md). Изменение владельцев состояния, границ систем или направления зависимостей должно обновлять этот файл в том же наборе изменений.

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

---

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Состояние забега и паузы | `GameFlowController` |
| Монеты текущего забега | `RunEconomy` |
| Количество завершённых покупок | `UpgradeSystem` |
| Состояние текущей выдачи карточек | `UpgradeSystem` |
| Формула стоимости карточек | `UpgradeBalance` |
| Направление и сила ветра | `WindSystem` |
| Позиция и скорость платформы | `PlatformController` |
| Доступность рулевого ввода | `SteeringInputProvider`, управляемый `CrewRoleManager` |
| Состояния четырёх якорей | `AnchorRuntimeStore` |
| Очереди операций якорей | `AnchorOperationQueue` |
| Активные пути абордажа | вычисляет `AnchorSystem`, публикует `AnchorPathRegistry` |
| Реестр физических врагов | `BoardingEnemyRegistry` |
| Состояние, координаты и прогресс прыжка врага | его `BoardingEnemyController` |
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
| Стратегические группы | будущий `StrategicWaveSystem` |
| Занятость клеток объектами | будущий `BuildableGrid` |

Stateless-компоненты не дублируют состояние владельцев. К ним относятся `BoardingMovementResolver`, `BoardingJumpPlanner`, `BoardingRewardController` и UI-панели.

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

`CARD_SELECTION` использует:

```gdscript
get_tree().paused = true
```

Поэтому выбор карточки останавливает весь игровой мир. `UpgradeSystem` и `UpgradeSelectionPanel` используют `PROCESS_MODE_ALWAYS`, чтобы оставаться доступными во время паузы.

### ShieldFailureController

Завершает забег при разрушении любой секции.

### CrewFailureController

Немедленно завершает забег при нуле живых защитников, даже если замены ожидают кулдауна.

---

## 6. EconomyDomain

```text
EconomyBalance
RunEconomy
BoardingRewardController
```

### EconomyBalance

Единственный источник параметров экономики:

```text
starting_coins
boarding_enemy_base_reward
rewarded_boarding_death_reasons
```

Текущие награждаемые причины:

```text
combat
anchor_path_closed
```

### RunEconomy

Единственный владелец суммы монет текущего забега.

Публичный интерфейс:

```text
get_coins()
can_afford(cost)
add_coins(amount, source)
spend_coins(cost, source)
reset_for_run()
```

Правила:

- сумма не может стать отрицательной;
- нулевые и отрицательные начисления игнорируются;
- неуспешная покупка не изменяет состояние;
- валюта сбрасывается при новом забеге;
- `RunEconomy` не знает о врагах, карточках или HUD.

### BoardingRewardController

Поток события:

```text
BoardingEnemy.kill(reason)
    ↓
BoardingEnemyRegistry.enemy_removed(enemy_id, reason)
    ↓
BoardingRewardController
    ↓
RunEconomy.add_coins(amount, reason)
```

Стратегические враги миникарты не используют этот поток и не дают монет.

---

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

Стоимость рассчитывается по количеству уже завершённых покупок:

```text
completed 0  → 5
completed 1  → 10
...
completed 19 → 100
completed 20 → 200
completed 21 → 400
completed 22 → 800
```

После двадцатой покупки стоимость последовательно умножается на `post_linear_multiplier`.

### UpgradeSystem

Единственный владелец:

- `_completed_purchases`;
- `_offer_open`;
- номера текущей выдачи;
- решения об открытии следующей выдачи.

Публичный интерфейс:

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

Поток открытия:

```text
RunEconomy.coins_changed
    ↓
UpgradeSystem проверяет RUNNING и can_afford(current_cost)
    ↓
GameFlowController.begin_card_selection()
    ↓
UpgradeSystem.offer_opened
    ↓
UpgradeSelectionPanel
```

Поток выбора:

```text
UpgradeSelectionPanel.choose_card(index)
    ↓
UpgradeSystem проверяет индекс и состояние
    ↓
RunEconomy.spend_coins(current_cost)
    ↓
_completed_purchases += 1
    ↓
достаточно монет?
    ├── да: новая выдача без снятия паузы
    └── нет: finish_card_selection() и возврат в RUNNING
```

### Текущий режим заглушек

На этапе Prototype 1.1 карточки не имеют разных эффектов.

- Все карточки используют один заголовок.
- Все карточки используют одно описание.
- `choose_card()` не вызывает игровой эффект.
- Выбор только списывает стоимость и увеличивает число завершённых покупок.
- Случайный каталог, уровни, повторы и применение эффектов отсутствуют намеренно.

Будущий каталог улучшений должен подключаться отдельным компонентом, а не разрастаться внутри `UpgradeSystem`.

### UpgradeSelectionPanel

Отдельная сцена:

```text
scenes/ui/upgrade_selection_panel.tscn
```

Панель:

- создаёт кнопки из `get_card_count()`;
- читает заголовок и описание через `UpgradeSystem`;
- вызывает только `choose_card(index)`;
- не списывает монеты;
- не считает стоимость;
- не применяет эффекты;
- скрывается при закрытии предложения, сбросе забега или `GAME_OVER`.

---

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

`PlatformController` владеет горизонтальной позицией и скоростью. Он применяет рулевое усилие, ветер, сопротивление, предел скорости, мировые границы и якорные ограничения.

`PlatformVisualController` только отображает платформу, клетки, посты, шар и дверь замены.

---

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
- Визуальный контроллер не изменяет доменное состояние.

---

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

---

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

### CrewManager

Владеет стабильными слотами `defender_id`. Замена получает прежний идентификатор и полное здоровье.

### CrewReplacementController

- владеет независимым таймером каждой смерти;
- останавливается при полной паузе;
- запрашивает свободную точку у `BoardingMovementResolver`;
- не создаёт защитника внутри врага или точки приземления.

### CrewRoleManager

Владеет текущими и ожидающими ролями. Переход ждёт завершения неделимого действия и очистки непосредственной боевой зоны.

### DefenderMovement

Владеет целевой координатой, приостанавливается на бой и не проходит сквозь врагов. Союзные защитники друг друга не блокируют.

---

## 12. CombatDomain

```text
HealthComponent
MeleeAttackComponent
DefenderCombatController
BoardingEnemyController
```

`MeleeAttackComponent` использует:

```text
READY
WINDUP
COOLDOWN
```

Цель фиксируется в начале взмаха. Начатая атака не перенаправляется. Боевые компоненты не начисляют монеты напрямую.

---

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

- выдаёт стабильный `enemy_id`;
- хранит активных физических врагов;
- удаляет запись при первой смерти;
- публикует `enemy_removed(enemy_id, reason)` ровно один раз;
- не знает об экономике.

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

Stateless-сервис:

- разделяет врагов на земле и платформе;
- формирует очередь на тросе;
- блокирует пересечение врага и защитника;
- резервирует точки приземления;
- ищет свободную позицию замены.

### BoardingJumpPlanner

Возвращает план прыжка только при пробке перед защитником, свободной точке за спиной и допустимой длине. Состояние врага не меняет.

---

## 14. StrategicWaveDomain

Планируются:

```text
RunDifficulty
StrategicWaveDirector
StrategicWaveSystem
MinimapRenderer
```

Стратегические враги:

- не создаются как `BoardingEnemy`;
- не регистрируются в `BoardingEnemyRegistry`;
- не дают монет;
- хранятся как агрегированные данные.

---

## 15. BuildableDomain

Планируются:

```text
BuildableInventory
BuildableGrid
MedicalStationSystem
TurretSystem
```

Будущая турель наносит обычный физический урон. Смерть физического врага с причиной `combat` использует существующий reward flow.

---

## 16. PresentationDomain

HUD, миникарта, указатели, визуалы, анимации, звук и эффекты не изменяют доменное состояние.

HUD читает:

- монеты из `RunEconomy`;
- число покупок и стоимость из `UpgradeSystem`.

Копии этих значений в UI запрещены.

---

## 17. Обязательные тестовые границы

### Экономика

- Новый забег начинает экономику со `starting_coins`.
- `combat` и `anchor_path_closed` начисляют награду один раз.
- Технические и стратегические причины награды не дают.
- Неуспешное списание не меняет сумму.

### Карточки

- Первая стоимость равна 5.
- Двадцатая стоимость равна 100.
- Следующие стоимости равны 200, 400 и 800.
- Предложение открывается только при достаточных монетах и в `RUNNING`.
- Во время предложения мир полностью остановлен.
- Неверный индекс карточки не списывает монеты.
- Обе текущие карточки имеют одинаковое содержимое.
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
- Условный прыжок требует пробки и свободной точки приземления.
- Лимит 600 строк не нарушен.

---

## 18. Следующая итерация

1. `RunDifficulty` как единый параметр сложности забега.
2. Плавный рост общего наземного лимита врагов.
3. Уменьшение интервала физического спавна со временем.
4. Начало стратегических волн.
5. Постоянно видимая миникарта.

Различные эффекты карточек остаются отложенными до отдельного проектирования каталога улучшений.

---

## 19. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец монет, стоимости или прогресса карточек.
- Изменение монет вне `RunEconomy`.
- Расчёт стоимости вне `UpgradeBalance`.
- Увеличение счётчика покупок вне `UpgradeSystem`.
- Списание монет непосредственно из `UpgradeSelectionPanel`.
- Применение будущих эффектов прямо внутри UI.
- Добавление большого каталога эффектов внутрь `UpgradeSystem`.
- Начисление монет внутри врага, оружия или якоря.
- Дублирование роли вне `CrewRoleManager`.
- Дублирование здоровья вне `HealthComponent`.
- Зависимость симуляции от визуала.
- Один большой скрипт для ролей, врагов, экономики или карточек.
- Архитектурное изменение без обновления этого файла.
