# Character and enemy animation presentation

Issue #31 adds a presentation-only animation layer for defenders and boarding enemies.

## Ownership

`CharacterAnimationController` owns only visual state, frame index, elapsed frame time and facing direction. It does not select targets, move actors, apply damage, heal, stun or decide when an action is complete.

Domain systems remain authoritative:

- `DefenderMovement` owns defender movement;
- `MeleeAttackComponent` and `RangedAttackComponent` own attack windup, impact and cooldown;
- `MedicalStationSystem` and `Defender` own the healing action;
- `BoardingEnemyController` and special enemy behaviors own enemy movement states;
- health components and enemy/defender lifetimes remain gameplay state.

The visual layer reads these states and maps them to `idle`, `run`, `attack`, `climb`, `jump`, `heal`, `flying`, `landing` and `death` presentation states.

## Windup synchronization

Attack frames are selected from normalized domain windup progress. No animation callback applies damage. The impact still occurs only when the corresponding attack component resolves its windup.

## Assets and fallbacks

The existing warrior PNG sequences remain the defender asset source for idle, run, attack and death. The medic uses its existing static role asset with a small procedural healing/movement motion until dedicated frame sets are available. The driver stays hidden while assigned to the combined captain/platform asset.

The existing `visual/enemies/Enemy1` atlases are used by the basic boarding enemy:

- six-frame idle, run, attack and jump strips;
- the first three frames of the climb/fall strip for climbing;
- three death frames;
- the jump strip in reverse for landing.

The repository does not yet contain separate frame sets for every enemy archetype. Runner, brute, rope saboteur and flyer therefore use animated procedural fallbacks with different silhouettes. Adding dedicated frame sets later changes only presentation asset selection; gameplay controllers do not need to change.

## Death lifetime

Enemy gameplay lifetime still ends immediately when `BoardingEnemy.kill()` runs. The visual node detaches before the gameplay node is freed and completes a short presentation-only death animation. Detached visuals are not registered as enemies, cannot be targeted and cannot affect collisions or rewards.

## Pause and headless behavior

Animation time advances through normal `_process`. A paused scene tree therefore freezes frames. Domain tests do not require textures or animation completion to advance combat, healing, movement or death.
