# Scene upgrade overlay runtime note

`PlatformUpgradeAssetOverlay` must be part of the base gameplay scene, not only a specialized inherited scene.

`PlatformVisualController` draws the platform body, portal, driver console, and platform core. Platform upgrade visuals such as speed engines, control/steering mechanism, stability units, shield-core overlays, and wind compensator use `PlatformUpgradeAssetOverlay`.

If `PlatformVisualController` is present but `PlatformUpgradeAssetOverlay` is missing, the platform, portal, and driver console can still appear while all upgrade assets are absent. This is a scene composition bug, not an asset-positioning bug.

Scene rule:

- `scenes/game/game_root.tscn` owns `World/Platform/PlatformUpgradeAssetOverlay`.
- inherited gameplay scenes may override its properties if needed;
- inherited gameplay scenes must not create a second overlay node with the same responsibility.
