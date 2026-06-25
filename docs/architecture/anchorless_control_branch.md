# Anchorless control branch

NEXT-13 keeps `PlatformController` and `WindSystem` as the only owners of horizontal movement and wind force. Upgrade cards never write positions, velocities, anchor state, or shield values directly.

## Integration base

NEXT-11 is merged into `main`. This implementation extends its canonical upgrade catalog, production scene, effect router, and active-catalog scenarios without replacing shooter cards, role wiring, or effect validation.

## Runtime ownership

`AnchorlessControlSystem` owns one `AnchorlessControlUpgradeRuntime` for the current run. The runtime stores additive base-line modifiers, the selected specialization, and specialization-extra flags. `AnchorlessUpgradeCoordinator` routes `anchorless_*` effect definitions through `UpgradeEffectApplier` into this domain owner.

A new run resets the domain runtime, flight/contact timers, remembered anchor points, platform modifiers, and wind modifiers. Manual pause does not reset state. Contact is preserved during pauses. A new run clears stale contact without emitting the gameplay `contact_ended` event.

## Movement integration

`PlatformController` still resolves movement in this order:

1. read the assigned driver's input;
2. calculate steering force and wind force;
3. integrate velocity and drag;
4. clamp maximum speed;
5. apply world and anchor constraints.

The branch only supplies typed multipliers. Simultaneous left/right input remains neutral, and enhanced post-input damping is applied only when no steering action is held. Anchor constraints and world bounds keep final priority. No card creates temporary anchorless fixation.

`WindSystem` applies the additive wind-reduction ratio to its existing force. Automatic steering suppresses only strength-1 wind; it does not assign a driver, move toward an orb, cancel inertia, or bypass constraints.

Speed-flight contact braking wins for the contact frame and produces zero velocity. Normal wind and steering resume on the following frame, so this remains a brake rather than hidden fixation.

## Contact and specialization events

`OrbContactSystem` preserves contact state while simulation is paused, preventing synthetic disconnect/connect events on pause transitions.

- Precise stabilization increases post-input damping. Its extra card asks `ShieldRechargeController` for a multiplier and returns `1.25` only inside the typed central sub-zone.
- Speed flight raises acceleration and maximum speed, requests a one-frame sharp velocity brake on contact, tracks continuous qualifying movement time outside contact, applies one 10% section restore on the first eligible connection, and sweeps qualifying ground enemies in front of the moving platform without an invented minimum-speed gate. Long-flight qualification starts only after its extra card is acquired; movement completed before acquisition cannot be used retroactively. A sweep uses the established physical-enemy removal path, so incoming-damage modifiers cannot prevent the result and the normal reward is issued exactly once.
- Powerful stabilization remembers the most recent attached anchor ground point per side. Contact starts produce the radius-limited anchor-point discharges required by the word “near”. Ground-core and platform-core pulses instead use the complete target domains from the catalog: all physical ground enemies for the ground core, and boarded or true air-domain enemies for the platform core. Climbing enemies are excluded from both core domains.

Only values needed to operationalize qualitative rules remain in `AnchorlessControlBalance`: the central contact sub-zone, continuous-flight duration and speed, anchor “nearby” radius, and the front-edge spatial envelope.

## Validation boundary

Unit and integration scenarios cover runtime gating, production-scene effect routing, movement, wind, contact, pause, reset, anchor constraints, world bounds, real anchor-point capture, specialization target domains at long distance, connect/disconnect pulses, non-retroactive long-flight activation, actual center/edge recharge, guaranteed sweep rewards, and multi-enemy low-speed sweep behavior. Repository Actions currently terminate before checkout under infrastructure issue #83, so these scenarios still require an executable Godot run before the PR can be marked ready.
