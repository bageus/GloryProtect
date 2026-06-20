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
├── GameFlowDomain
├── RunEconomy
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
└── PresentationDomain
```

`GameRoot` только собирает системы и передаёт зависимости.

---

## 4. Владельцы состояния

| Состояние | Единственный владелец |
|---|---|
| Состояние забега и паузы | `GameFlowController` |
| Монеты текущего забега | `RunEconomy` |
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
| Цена и выбор улучшений | будущий `UpgradeSystem` |

`BoardingMovementResolver`, `BoardingJumpPlanner` и `BoardingRewardController` не владеют состоянием персонажей или валюты. Они только вычисляют решение либо преобразуют доменное событие в команду владельцу.

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

## 6. EconomyDomain

```text
EconomyBalance
RunEconomy
BoardingRewardController
```

### EconomyBalance

Единственный источник настраиваемых параметров экономики прототипа:

```text
starting_coins
boarding_enemy_base_reward
rewarded_boarding_death_reasons
```

Текущая базовая награда — одна монета. Значение не зашито в контроллер врага, HUD или боевую систему.

Разрешённые причины физической смерти:

```text
combat
anchor_path_closed
```

Технические причины, очистка тестов и будущие стратегические враги не входят в список.

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
- отрицательные и нулевые начисления игнорируются;
- неуспешная покупка не изменяет состояние;
- валюта сбрасывается при начале нового забега;
- возврат из ручной паузы в стартовый отсчёт не считается новым забегом;
- `RunEconomy` ничего не знает о врагах, якорях, карточках или HUD.

### BoardingRewardController

Stateless-мост между BoardingDomain и `RunEconomy`.

Поток события:

```text
BoardingEnemy.kill(reason)
    ↓
BoardingEnemyRegistry.enemy_removed(enemy_id, reason)
    ↓
BoardingRewardController
    ↓ проверка EconomyBalance
RunEconomy.add_coins(amount, reason)
```

Контроллер:

- не хранит сумму;
- не определяет причину смерти;
- не начисляет награду дважды, потому что реестр удаляет врага до публикации события;
- не слушает стратегические волны миникарты;
- автоматически поддерживает будущую турель, если её убийство использует причину `combat`.

### Presentation

HUD только вызывает `RunEconomy.get_coins()`. Копия суммы в UI запрещена.

---

## 7. PlatformDomain

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

## 8. OrbDomain и ShieldDomain

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

## 9. AnchorDomain

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

Каждый установленный якорь сохраняет исходный шар и наземную точку.

---

## 10. CrewDomain

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

Владеет стабильными слотами `defender_id`. Новый экземпляр замены получает прежний идентификатор и полное здоровье.

### CrewReplacementController

- владеет независимым `CrewReplacementRuntime` для каждой смерти;
- несколько таймеров идут одновременно;
- таймеры останавливаются при полной паузе;
- перед созданием замены запрашивает свободную позицию у `BoardingMovementResolver`;
- замена не появляется внутри врага или зарезервированной точки приземления;
- при `GAME_OVER` таймеры не продвигаются.

### CrewRoleManager

```text
ACTIVE
WAITING_FOR_ACTION
MOVING
DEAD
```

Переход ждёт отпускания рулевого ввода, завершения операции якоря, завершения взмаха и очистки непосредственной боевой зоны.

### DefenderMovement

- владеет целевой координатой;
- приостанавливается боем без потери назначения;
- запрашивает допустимый шаг у `BoardingMovementResolver`;
- игнорирует союзных защитников;
- не проходит сквозь врагов и зарезервированные точки приземления.

### DefenderCombatController

- рулевой не использует меч;
- якорщик атакует возле поста;
- свободный защитник преследует ближайшего поднявшегося врага;
- защитник в переходе останавливается перед врагом, завершает бой и продолжает маршрут;
- начатый взмах не меняет цель;
- после взмаха ближайшая цель выбирается заново.

---

## 11. CombatDomain

### MeleeAttackComponent

```text
READY
WINDUP
COOLDOWN
```

- цель фиксируется в начале взмаха;
- начатый удар не перенаправляется;
- погибшая цель превращает удар в промах;
- обычный успешный удар наносит один урон;
- защитник атакует быстрее базового врага.

Компонент урона не начисляет монеты. Денежная награда возникает только после опубликованной смерти врага.

---

## 12. BoardingDomain

```text
AnchorPathRegistry
BoardingSpawnDirector
BoardingEnemyRegistry
BoardingMovementResolver
BoardingJumpPlanner
BoardingEnemyContainer

BoardingEnemy
├── HealthComponent
├── MeleeAttackComponent
├── BoardingEnemyController
└── BoardingEnemyVisual
```

### BoardingEnemyRegistry

- выдаёт стабильный `enemy_id`;
- хранит активных физических врагов;
- удаляет запись при первой смерти;
- публикует `enemy_removed(enemy_id, reason)` ровно один раз;
- не знает о монетах.

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

- фиксирует выбранный путь;
- погибает с причиной `anchor_path_closed`, если путь закрыт во время подъёма;
- враг на платформе переживает снятие якоря;
- после приземления заново выбирает ближайшего защитника;
- координаты и прогресс прыжка остаются собственностью контроллера.

### BoardingMovementResolver

Stateless-сервис допустимого движения:

- разделение на земле;
- безопасный спавн;
- очередь и интервал на тросе;
- ожидание выхода на платформу;
- разделение на платформе;
- взаимное блокирование врагов и защитников;
- свободная позиция замены;
- резервирование позиции прыжка.

### BoardingJumpPlanner

Возвращает `BoardingJumpPlan` только при пробке перед защитником, свободной позиции за его спиной, допустимой длине и нахождении точки внутри платформы. Сам планировщик состояние врага не меняет.

### Правила разделения

- защитники проходят сквозь защитников;
- враги не проходят сквозь врагов;
- защитники и враги не проходят друг сквозь друга;
- задний враг ждёт переднего;
- враг на тросе погибает при закрытии пути;
- враг на платформе переживает снятие якоря.

---

## 13. StrategicWaveDomain

Планируются `StrategicWaveDirector`, `StrategicWaveSystem` и `MinimapRenderer`.

Стратегические враги:

- не создаются как `BoardingEnemy`;
- не регистрируются в `BoardingEnemyRegistry`;
- не публикуют `enemy_removed`;
- не дают монет.

---

## 14. BuildableDomain

Планируются `BuildableInventory`, `BuildableGrid`, `MedicalStationSystem` и `TurretSystem`.

Будущая турель наносит обычный физический урон. Если физический враг погибает с причиной `combat`, существующий reward flow начисляет награду без зависимости экономики от турели.

---

## 15. PresentationDomain

HUD, миникарта, указатели, визуалы, анимации, звук и эффекты. Presentation не изменяет доменное состояние.

---

## 16. Обязательные тестовые границы

- Новый забег начинает экономику со `starting_coins`.
- Разрешённая физическая смерть начисляет базовую награду один раз.
- `combat` начисляет монеты.
- `anchor_path_closed` начисляет монеты.
- `test_cleanup` не начисляет монеты.
- Неизвестная или стратегическая причина не начисляет монеты.
- Повторный вызов смерти одного врага не начисляет вторую награду.
- Неуспешное списание не меняет сумму.
- Монеты сбрасываются при перезапуске забега.
- Контакт заряжает только связанную секцию.
- Разрушение секции завершает забег.
- Ноль живых защитников завершает забег немедленно.
- Каждый погибший защитник получает независимый кулдаун.
- Без якорей физический спавн запрещён.
- Наземные враги и враги на тросе сохраняют дистанцию.
- Защитник и враг не проходят друг сквозь друга.
- Без переднего врага прыжок не начинается.
- Занятая точка за защитником запрещает прыжок.
- После приземления враг переоценивает ближайшего защитника.
- Лимит 600 строк не нарушен.

---

## 17. Следующая итерация

1. `UpgradeSystem` как владелец последовательности выдач и стоимости.
2. Формула стоимости 5, 10, …, 100, затем удвоение.
3. Полная пауза при выборе двух карточек.
4. Автоматическая следующая выдача при достаточном остатке монет.
5. Минимальный временный каталог карточек для проверки цикла.
6. Рост наземного лимита от сложности.
7. Начало стратегических волн.

---

## 18. Запрещённые решения

- Глобальный объект, управляющий всей игрой.
- UI как владелец монет или игровых данных.
- Изменение суммы монет вне `RunEconomy`.
- Начисление монет непосредственно внутри врага, оружия, якоря или HUD.
- Дублирование списка награждаемых причин вне `EconomyBalance`.
- Дублирование роли вне `CrewRoleManager`.
- Дублирование таймеров замены вне `CrewReplacementController`.
- Дублирование координат или прогресса прыжка внутри planner/resolver.
- Физические дистанции и параметры прыжка, разбросанные по контроллерам.
- Доступ BoardingDomain к `AnchorRuntimeStore`.
- Дублирование здоровья вне `HealthComponent`.
- Дублирование геометрии шаров вне `GroundOrbCatalog`.
- Зависимость симуляции от визуала.
- Один большой скрипт для ролей, врагов или карточек.
- Архитектурное изменение без обновления этого файла.
