# Special Enemy Behavior Framework

Этот документ фиксирует архитектурную границу специальных физических врагов из issue #17.

## Назначение

Обычные `basic`, `runner` и `brute` продолжают использовать `BoardingEnemyController` и общий цикл:

```text
земля → якорь → подъём → платформа → ближний бой
```

Специальный враг остаётся экземпляром `BoardingEnemy`, но получает один небольшой `EnemyBehaviorComponent`, подключённый композицией через `attach_special_behavior()`.

## Владение состоянием

- `HealthComponent` остаётся единственным владельцем здоровья.
- `BoardingEnemyRegistry` остаётся владельцем набора активных физических врагов.
- `BoardingEnemy` остаётся общей точкой смерти и публикует `died`.
- Конкретный `EnemyBehaviorComponent` владеет только своей машиной поведения и выбранной целью.
- `GameFlowController` остаётся владельцем паузы; behavior-компонент выполняет `_tick_behavior()` только в `RUNNING`.
- Визуальный слой получает `visual_state_changed`, но не меняет симуляцию.

## Общий контракт цели

`BoardingEnemy` предоставляет поведенчески независимые запросы:

```text
is_targetable_by_turret()
is_counted_as_ground()
is_counted_as_climbing()
is_counted_as_boarded()
```

`BoardingEnemyRegistry` и `TurretTargetSelector` используют только этот контракт и не проверяют `archetype_id` или конкретный класс специального поведения.

## Типы специальных целей

`EnemyBehaviorComponent.TargetDomain` резервирует направления поведения:

- `GROUND` — движение к наземной позиции;
- `AIR` — воздушное движение и атака;
- `DISTANT` — дистанционная атака;
- `OBJECT` — атака игрового объекта, например троса.

Enum описывает назначение компонента и не является общей машиной состояний. Реальное состояние хранит конкретный небольшой компонент будущего врага.

## Подключение

```text
instantiate BoardingEnemy
→ configure common archetype, health and visual data
→ attach_special_behavior(component, game_flow)
→ BoardingEnemyController stops
→ component owns movement/attack behavior
→ register in BoardingEnemyRegistry
```

Будущий специализированный spawn factory может выполнять эти шаги до регистрации. Подписчики `enemy_registered` должны всегда получать полностью настроенного врага.

## Смерть, награды и статистика

Все специальные враги обязаны использовать общий поток:

```text
HealthComponent.depleted
→ BoardingEnemy.kill(reason)
→ EnemyBehaviorComponent.stop()
→ BoardingEnemyRegistry.enemy_removed
→ BoardingRewardController
→ RunEconomy / RunStatistics
```

Запрещено напрямую удалять специального врага или начислять награду из behavior-компонента.

## Турели

`TurretTargetSelector` читает `BoardingEnemyRegistry.get_turret_targets()`. Поэтому воздушный, дистанционный или атакующий объект враг становится целью турели без изменений в `TurretSystem`, если его компонент возвращает `turret_targetable = true`.

## Тестовая граница

`TestSpecialEnemyBehavior` подтверждает:

- подключение композицией;
- отсутствие тиков во время ручной паузы;
- доступность через общий контракт турели;
- независимую классификацию ground/climbing/boarded;
- удаление через общий registry death flow;
- неизменность поведения стандартного абордажника.
