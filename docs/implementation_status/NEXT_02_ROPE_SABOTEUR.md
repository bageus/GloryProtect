# NEXT-02 — Rope Saboteur Enemy

Status: implemented on `feature/rope-saboteur-enemy`; stacked on `feature/rope-durability-runtime`.

## Implemented

- Shared `BoardingEnemyBehavior` contract for specialized physical enemies.
- Dedicated `RopeSaboteurArchetype`, scene, controller and diagnostic visual.
- Data-driven scene selection through `BoardingEnemyArchetype.enemy_scene`.
- Catalog unlock at normalized difficulty `0.25`.
- Nearest damageable rope selection with target locking.
- Retarget only when the path closes or the rope reaches zero durability.
- Ground-only movement and separation; no climbing, platform boarding or melee.
- Pause-safe arming state.
- Turret targetability only during arming.
- Rope-only explosion through `AnchorSystem.apply_rope_damage(...)`.
- `rope_sabotage` self-death without reward.
- Normal `combat` death and reward when killed before detonation.
- Unit catalog coverage and full integration scenarios.

## Explicit boundary

The saboteur does not close a destroyed path, remove climbing enemies or return the anchor. Those consequences remain in NEXT-03 / issue #16.

## Required validation before merge

```bash
godot --headless --path . --script res://tests/unit/boarding_enemy_catalog_scenarios.gd
godot --headless --path . --script res://tests/integration/rope_saboteur_scenarios.gd
python tools/check_file_sizes.py
```

The current GitHub Actions workflow runs only the file-size guard. Godot scenarios require local execution or a CI extension.
