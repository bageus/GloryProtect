# NEXT-02 — Rope Saboteur Enemy

Status: implemented on `feature/rope-saboteur-enemy`; stacked on `feature/rope-durability-runtime`.

## Implemented

- Shared `BoardingEnemyBehavior` contract for specialized physical enemies.
- Dedicated `RopeSaboteurArchetype`, scene, controller and diagnostic visual.
- Data-driven scene selection through `BoardingEnemyArchetype.enemy_scene`.
- Data-driven spawn requirement `DAMAGEABLE_ROPE`.
- Catalog unlock at normalized difficulty `0.25`.
- Automatic spawn excludes the saboteur when every open rope is already destroyed.
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

The stacked PR targets a feature branch, while the current workflow listens only to pull requests targeting `main`; therefore no GitHub Actions run is expected until the PR is retargeted after #41. Godot scenarios still require local execution or CI extension.
