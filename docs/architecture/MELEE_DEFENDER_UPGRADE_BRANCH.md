# Melee Defender Upgrade Branch

Issue #23 adds run-scoped melee upgrades without moving combat state into the UI or card definitions.

## Ownership

`CrewManager` owns one `MeleeDefenderUpgradeRuntime` for the current run. Upgrade effects with a `melee_` target ID are routed through the public crew-domain API:

- `apply_melee_scalar()`;
- `apply_melee_flag()`.

The manager reapplies the shared runtime to every current defender and passes it to newly added or replacement defenders.

## Modular catalog

`melee_defender_upgrade_catalog.tres` contains only the melee branch. `active_game_upgrade_catalog.tres` composes it with the existing common and turret catalog through `UpgradeCatalog.included_catalogs`.

Draw generation, specialization events and diagnostics read `get_all_definitions()`, so branch catalogs can remain below the project file-size limit and retain stable card IDs.

## Base lines

The branch contains three independent basic-to-advanced pairs:

- sword damage `+1`, then another `+1`;
- attack cooldown `×0.85`, then another `×0.85`;
- maximum health `+1`, then another `+1`.

Individual cards remain unavailable until at least one advanced melee card has been selected.

## Durability

`DefenderDurabilityComponent` owns armor and the one-use lethal guard. Incoming damage is resolved in this order:

1. armor absorbs as much damage as possible;
2. a ready lethal guard can reduce lethal health damage so the defender remains at `1` health;
3. remaining damage is applied through `HealthComponent`;
4. `depleted` is emitted only after the previous steps.

Ordinary healing calls only `HealthComponent.heal()` and never restores armor. Increasing maximum armor adds only the newly granted armor and does not refill previously lost armor.

The lethal guard is life-scoped. Buying unrelated cards after it has been consumed does not restore it. A replacement defender receives a fresh guard, and a new run resets all life-scoped state.

## Specializations

### Heavy

- maximum health `+1`;
- only heavy defenders block enemy jump plans through themselves;
- optional shield grants `+2` armor;
- optional fifth shield hit damages up to two enemies behind the primary target and knocks survivors back.

### Duelist

- attack cooldown `×0.75`;
- optional isolated-target bonus damage;
- optional second hit against the same locked target;
- optional immediate counterattack after melee damage, including a hit absorbed entirely by armor.

### Assault

- splash damage to up to three enemies behind the primary target;
- optional extra forward hit and one rear hit when surrounded;
- optional one-use lethal guard.

## Locked actions

`DefenderCombatController` stores the enemy instance when a normal melee windup starts. Secondary effects resolve against that same primary target and never retarget the begun attack. The stored instance remains valid through deferred enemy removal, allowing splash and rear effects to resolve even if the primary hit was lethal.

## Pause and roles

The existing combat controller remains the authority for role eligibility, local combat zones, moving assignments and world-pause checks. Specialization resolution runs only from a completed normal melee hit or a tagged incoming melee hit.

## Tests

- `tests/unit/defender_durability_scenarios.gd`;
- `tests/unit/melee_defender_upgrade_runtime_scenarios.gd`;
- `tests/unit/melee_defender_catalog_scenarios.gd`;
- `tests/unit/active_upgrade_catalog_scenarios.gd`;
- `tests/integration/melee_defender_replacement_scenarios.gd`.
