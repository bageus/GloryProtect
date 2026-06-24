# Combat anchor scenario coverage

Run the focused scenarios from the repository root:

```bash
godot --headless --path . --script res://tests/unit/combat_anchor_runtime_scenarios.gd
godot --headless --path . --script res://tests/unit/combat_anchor_catalog_scenarios.gd
godot --headless --path . --script res://tests/integration/combat_anchor_operation_scenarios.gd
godot --headless --path . --script res://tests/integration/combat_anchor_upgrade_routing_scenarios.gd
```

They cover typed runtime/reset behavior, catalog prerequisites and specialization locking, production effect routing, overload/install modifiers, the rope-durability ownership boundary, and the difference between ordinary and instant emergency removal while preserving atomic installations.
