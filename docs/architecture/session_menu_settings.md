# Session shell, settings, and screen shake

Issue #192 introduces an application shell around the existing gameplay scene.

## Scene ownership

`AppShell` is the application entry scene. It owns only high-level scene presentation:

- showing the main menu before the first run;
- instantiating the gameplay scene after `Новая игра`;
- showing the pause menu;
- replacing the gameplay scene for a run restart;
- requesting application shutdown.

`GameFlowController` remains the owner of run state. The shell opens the pause menu by requesting `MANUAL_PAUSE` through `toggle_manual_pause()` and resumes through the same API. Gameplay systems continue to read `is_world_simulation_active()`.

The game-over panel still requests `GameFlowController.restart_run()`. When an application shell exists, its `restart_requested` signal replaces the gameplay node. Standalone test scenes without the shell retain the legacy `reload_current_scene()` fallback.

## Settings ownership

`AppSettingsService` is an autoload named `AppSettingsRuntime`. It owns the version-independent user values stored in `user://settings.cfg`:

- overall Effects volume;
- overall Music/Soundtrack volume;
- one test trim for each connected gameplay effect;
- keyboard bindings for production and currently exposed debug actions.

`AppSettings` is a static typed proxy used by UI and tests. It resolves the runtime service through `/root/AppSettingsRuntime`, avoiding direct dependencies on an autoload identifier during isolated script compilation.

The settings UI only sends commands to this service. It does not write files or edit `InputMap` directly.

## Audio routing

`AppSettingsService` creates `Effects` and `Music` buses if they are absent. The general sliders change those buses. `GameAudioController` routes all current gameplay effects through `Effects` and applies the per-sound test trim on each player.

The Music bus exists before a soundtrack is added, so future soundtrack players can use it without changing the settings format.

## Input routing

Gameplay input handlers read named `InputMap` actions. Rebinding replaces the keyboard event for one action and immediately saves it. The settings screen captures the next physical keyboard key. Reset restores the documented defaults.

The platform steering provider also accepts the old `ui_left` and `ui_right` actions as a regression compatibility fallback for existing focused tests and embedded prototype scenes. Production rebinding uses `gp_move_left` and `gp_move_right`.

## Tension-break shake

`WorldShakeController` listens to `AnchorSystem.anchor_recovery_started` and reacts only when the source is `wind_overload`.

The effect changes the viewport canvas transform for a short decaying shake. It does not change world-node positions, velocities, collision state, or anchor geometry. CanvasLayer UI remains fixed. Manual removal and durability destruction by enemies do not trigger this effect.

## Headless behavior

Settings and InputMap tests do not require an audio device. Screen shake has deterministic test hooks. Menus are generated with standard Control nodes and can be exercised without rendering textures.
