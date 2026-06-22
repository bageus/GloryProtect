# Anchorless control branch

NEXT-13 keeps `PlatformController` and `WindSystem` as the only owners of horizontal movement and wind force. Upgrade cards never write positions, velocities, anchor state, or shield values directly.

## Runtime ownership

`AnchorlessControlSystem` owns one `AnchorlessControlUpgradeRuntime` for the current run. The runtime stores additive base-line modifiers, the selected specialization, and specialization-extra flags. `AnchorlessUpgradeCoordinator` routes `anchorless_*` effect definitions through `UpgradeEffectApplier` into this domain owner.

A new run resets the domain runtime, flight/contact timers, remembered anchor points, platform modifiers, and wind modifiers. Manual pause does not reset state.

## Movement integration

`PlatformController` still resolves movement in this order:

1. read the assigned driver's input;
2. calculate steering force and wind force;
3. integrate velocity and drag;
4. clamp maximum speed;
5. apply world and anchor constraints.

The branch only supplies typed multipliers. Simultaneous left/right input remains neutral, and enhanced post-input damping is applied only when no steering action is held. Anchor constraints and world bounds keep final priority. No card creates temporary anchorless fixation.

`WindSystem` applies the additive wind-reduction ratio to its existing force. Automatic steering suppresses only strength-1 wind; it does not assign a driver, move toward an orb, cancel inertia, or bypass constraints.

## Contact and specialization events

`OrbContactSystem` preserves contact state while simulation is paused, preventing synthetic disconnect/connect events on pause transitions.

- Precise stabilization increases post-input damping. Its extra card asks `ShieldRechargeController` for a multiplier and returns `1.25` only inside the typed central sub-zone.
- Speed flight raises acceleration and maximum speed, requests a sharp velocity brake on contact, tracks qualifying movement time outside contact, applies one 10% section restore on the first eligible connection, and resolves front-edge ground-enemy sweeps.
- Powerful stabilization remembers the most recent attached anchor ground point per side. Contact starts produce the base anchor-point discharges. Its two extra cards resolve ground-core and platform-core pulses on contact start/end with explicit target filters.

Thresholds and radii that were not numerically fixed by the design issue are isolated in `AnchorlessControlBalance` for playtesting rather than hidden in card or UI code.
