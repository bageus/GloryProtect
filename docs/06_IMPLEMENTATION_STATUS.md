# GloryProtect — статус реализации

## Целевая версия

Godot **4.6.2 stable**, строго типизированный GDScript.

## Текущая версия

**Prototype 2.0 — data-driven типы физических абордажных врагов.**

---

## 1. Каталог физических врагов

Добавлены:

```text
scripts/boarding/boarding_enemy_archetype.gd
scripts/boarding/boarding_enemy_catalog.gd
resources/enemies/boarding_basic.tres
resources/enemies/boarding_runner.tres
resources/enemies/boarding_brute.tres
resources/enemies/boarding_enemy_catalog.tres
```

`BoardingEnemyArchetype` задаёт:

```text
archetype_id
display_name
max_health
body_radius
body_color
accent_color
ground_move_speed
climb_move_speed
platform_move_speed
attack_damage
attack_windup
attack_cooldown
attack_range
unlock_difficulty
weight_at_unlock
weight_at_max_difficulty
```

`BoardingEnemyCatalog` проверяет уникальность ID, возвращает профиль по ID и выполняет взвешенный выбор по текущей нормализованной сложности.

---

## 2. Текущие архетипы

### basic

```text
Название: Базовый абордажник
Здоровье: 1
Радиус: 12
Земля: 125
Трос: 105
Платформа: 90
Открывается: 0%
Вес: 1.00 → 0.75
```

### runner

```text
Название: Быстрый абордажник
Здоровье: 1
Радиус: 10
Земля: 175
Трос: 150
Платформа: 135
Подготовка атаки: 0.35 секунды
Открывается: 15%
Вес: 0.25 → 1.40
```

### brute

```text
Название: Тяжёлый абордажник
Здоровье: 3
Радиус: 16
Земля: 85
Трос: 70
Платформа: 62
Подготовка атаки: 0.80 секунды
Открывается: 45%
Вес: 0.15 → 0.90
```

При нулевой сложности автоматический спавн выбирает только `basic`. К концу шкалы сложности доступны все три типа.

---

## 3. Конфигурация экземпляра

`BoardingEnemy.configure(...)` теперь получает `BoardingEnemyArchetype`.

Из архетипа настраиваются:

- `HealthComponent`;
- `MeleeAttackComponent`;
- `BoardingEnemyVisual`;
- скорости `BoardingEnemyController`;
- дальность начала атаки.

Экземпляр предоставляет:

```text
get_archetype_id()
get_archetype_name()
get_body_radius()
```

Конфигурация выполняется до регистрации в `BoardingEnemyRegistry`.

---

## 4. Общая машина поведения

Все три текущих типа используют одну машину состояний:

```text
WAITING_WITHOUT_PATH
RUNNING_TO_ANCHOR
CLIMBING
ON_PLATFORM
FIGHTING
JUMPING
DEAD
```

`BoardingEnemyController` не содержит проверок:

```text
if archetype_id == "runner"
if archetype_id == "brute"
```

Он читает числовые параметры из назначенного ресурса. Это позволяет добавлять простые варианты здоровья, размера и скорости без копирования сцены или контроллера.

---

## 5. Сложность и спавн

`BoardingSpawnDirector`:

1. читает нормализованную сложность из `RunDifficulty`;
2. передаёт её в `BoardingEnemyCatalog`;
3. получает выбранный архетип;
4. создаёт общий `boarding_enemy.tscn`;
5. конфигурирует экземпляр;
6. регистрирует готового врага.

Для точных тестов добавлены:

```text
spawn_debug_archetype(archetype_id, side)
spawn_debug_on_platform(local_x, archetype_id)
```

Каталог подключён через `BoardingBalance`, поэтому `game_root.tscn` не перечисляет типы вручную.

---

## 6. Физическое разделение разных размеров

`BoardingMovementResolver` больше не использует один радиус для всех врагов.

Для пары врагов минимальный разрыв равен:

```text
max(global_spacing, first.body_radius + second.body_radius)
```

Правило применяется:

- при движении по земле;
- при поиске точки появления;
- при входе в очередь на тросе;
- при подъёме по одному тросу;
- при выходе на платформу;
- при движении на платформе;
- при поиске свободной точки принудительного абордажа.

Разрыв врага и защитника равен сумме их радиусов.

Два тяжёлых врага требуют минимум 32 единицы между центрами, даже если глобальный минимум равен 28.

---

## 7. Прыжок через защитника

`BoardingJumpPlanner` теперь использует:

- радиус прыгающего архетипа;
- радиус врага-блокировщика;
- индивидуальную дальность атаки блокировщика;
- радиус защитника;
- общий дополнительный зазор приземления.

Резерв точки приземления продолжает проходить через `BoardingMovementResolver`.

---

## 8. Диагностический внешний вид

Пока финальные ассеты не готовы, `BoardingEnemyVisual` различает архетипы векторно:

```text
basic  — красный, круглый центральный маркер
runner — фиолетовый, горизонтальный маркер
brute  — коричнево-оранжевый, прямоугольный маркер
```

Размер круга соответствует реальному `body_radius`. Цвета не влияют на симуляцию.

---

## 9. Реестр и HUD

`BoardingEnemyRegistry` получил:

```text
get_archetype_count(archetype_id)
get_archetype_summary()
```

Диагностический HUD показывает состав активного физического абордажа вместе с количеством врагов на земле, тросах и платформе.

Заголовок HUD:

```text
GloryProtect — Prototype 2.0
```

---

## 10. Награды и статистика

Все типы продолжают использовать общий поток:

```text
HealthComponent.depleted
→ BoardingEnemy.kill(reason)
→ BoardingEnemyRegistry.enemy_removed
→ BoardingRewardController
→ RunEconomy / RunStatistics
```

Prototype 2.0 выдаёт одинаковую базовую награду за `basic`, `runner` и `brute`. Враг стратегической миникарты награду не выдаёт.

---

## 11. Новые тесты

### Каталог

```text
tests/unit/boarding_enemy_catalog_scenarios.gd
```

Проверяется:

- валидность каталога;
- наличие трёх ID;
- здоровье и размеры;
- пороги открытия;
- только базовый выбор на нулевой сложности;
- присутствие всех типов при максимальной сложности.

### Интеграция экземпляров

```text
tests/integration/boarding_enemy_archetype_scenarios.gd
```

Проверяется:

- правильный ID созданного экземпляра;
- 1/1/3 сегмента здоровья;
- разные радиусы;
- счётчики реестра;
- фактическое преимущество скорости `runner`;
- разделение двух `brute` по сумме радиусов;
- изоляция проверки скорости от ветра.

Команды:

```bash
godot --headless --path . --script res://tests/unit/boarding_enemy_catalog_scenarios.gd
godot --headless --path . --script res://tests/integration/boarding_enemy_archetype_scenarios.gd
godot --headless --path . --script res://tests/integration/boarding_separation_scenarios.gd
godot --headless --path . --script res://tests/integration/boarding_jump_scenarios.gd
python tools/check_file_sizes.py
```

В среде помощника нет исполняемого Godot, поэтому headless-тесты здесь не запускались.

---

## 12. Совместимость

Старые вызовы:

```text
spawn_debug_on_platform(local_x)
```

по умолчанию создают `basic`, поэтому существующие сценарии прыжка, боя и турелей сохраняют прежние параметры.

В `BoardingBalance` временно сохранены группы `Legacy Base Enemy Defaults`. Runtime врага их больше не читает; они оставлены, чтобы старые тестовые и диагностические обращения не ломались одномоментно.

---

## 13. Сохранённые системы

Продолжают работать:

- мышиный интерфейс экипажа;
- роли и физические переходы;
- лечение;
- несколько турелей;
- награды и статистика;
- якоря, тросовые очереди и прыжки;
- стратегические волны и щит;
- полная пауза карточек.

Карточки остаются одинаковыми заглушками.

---

## 14. Временные ограничения

Пока не реализованы:

- специальные поведения летающего врага;
- дальняя и ядовитая атака;
- атака и прочность троса;
- враг-взрыватель троса;
- финальные спрайты и анимации;
- разные карточки улучшений.

---

## 15. Следующая итерация

1. Прочность каждого установленного троса.
2. Маленький враг-взрыватель, выбирающий доступный трос.
3. Урон тросу после завершения подготовки взрыва.
4. Разрушение пути и падение врагов на тросе.
5. Возврат сорванного якоря и предупреждение о повреждении.
