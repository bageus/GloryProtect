# Test scenarios

Run from the repository root with Godot 4.6.2 stable.

## Full suite

```bash
bash tools/run_godot_scenarios.sh
```

The runner imports the project first so a fresh checkout builds the global script-class cache before individual scenarios execute.

## Rope durability and recovery

```bash
godot --headless --path . --script res://tests/unit/anchor_rope_durability_scenarios.gd
godot --headless --path . --script res://tests/integration/anchor_rope_durability_scenarios.gd
godot --headless --path . --script res://tests/integration/rope_break_recovery_scenarios.gd
```

The durability scenarios verify independent values, validation, clamping, one-shot destruction events, reattachment recovery and damage eligibility for every anchor state.

The break-recovery scenario verifies synchronous path closure, removal of enemies on the destroyed rope, survival of boarded enemies, rewarded `anchor_path_closed` deaths, pause-safe return, damage-triggered recovery from `ATTACHED` and `OVERLOADED`, natural wind-overload break recovery and full durability after reinstallation.

## Rope saboteur

```bash
godot --headless --path . --script res://tests/unit/boarding_enemy_catalog_scenarios.gd
godot --headless --path . --script res://tests/integration/rope_saboteur_scenarios.gd
```

The catalog scenario verifies the unlock threshold, specialized archetype and weighted selection. The integration scenario verifies target locking, retargeting, pause behavior, turret targeting, rope-only damage and reward rules.

## Upgrade UI and diagnostics

```bash
godot --headless --path . --script res://tests/unit/upgrade_presentation_scenarios.gd
godot --headless --path . --script res://tests/unit/upgrade_specialization_view_scenarios.gd
godot --headless --path . --script res://tests/integration/upgrade_ui_scenarios.gd
```

The presentation scenarios verify branch/type labels, effect summaries, prerequisite status, repeat counters, diagnostic reason text and specialization lock warnings. The UI integration scenario verifies three-card rendering, diagnostics, continuous card-selection pause and rejection of stale repeated selections.

## Project guard

```bash
python tools/check_file_sizes.py
```

GitHub Actions runs both the file-size guard and the complete Godot scenario suite for pull requests targeting `main`.
