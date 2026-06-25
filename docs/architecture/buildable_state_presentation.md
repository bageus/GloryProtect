# Buildable state presentation

NEXT-20 keeps anchor, turret, and medical gameplay state inside their existing domain systems. Visual controllers only read snapshots, public query methods, and emitted signals.

## Anchor presentation

`AnchorVisualController` reads `AnchorRuntimeStore` and `AnchorGeometry`.

- `STOWED` shows the hanging anchor and installation silhouette when available.
- `QUEUED` and `INSTALLING` show the target clamp and installation progress.
- `ATTACHED` shows the complete chain and durability meter.
- `OVERLOADED` adds a warning pulse without changing overload state.
- `RETURNING` interpolates the anchor back to the winch.
- damaged and critical durability are represented by increasingly urgent chain tint and pulse.

## Turret presentation

`TurretVisualController` reads `TurretSystem`, `BuildableGrid`, and `TurretVisualRuntime`.

- missing operator uses the inactive asset alpha and red status indicator;
- operational readiness uses full asset opacity;
- shot windup uses the domain shot progress;
- shot completion produces recoil, muzzle flash, and tracer presentation;
- cooldown uses the domain cooldown timer;
- relocation during an active shot preserves the old shot origin until the current shot resolves.

## Medical presentation

`BuildableGridVisual` listens to `MedicalStationSystem` signals.

- `healing_started` enables the active glow;
- `healing_progress` drives the progress ring;
- `segment_restored` produces a short completion flash;
- `healing_stopped` clears the active state while allowing the completion flash to finish;
- grid reset clears all presentation-only timers.

The visual layer never selects a healing target, changes health, moves an operator, or owns the healing timer.

## Pause and headless behavior

Presentation timers use normal inherited process mode. Manual tree pause therefore freezes pulses and completion flashes. Domain simulation and tests do not read presentation state, so headless gameplay remains independent from visual transitions.
