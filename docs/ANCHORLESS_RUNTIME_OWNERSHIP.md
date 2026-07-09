# Anchorless runtime ownership

`AnchorlessControlSystem` is a gameplay domain system and must be scene-owned in the runtime gameplay scene.

The upgrade coordinator must use the scene node through `anchorless_control_system_path`; it must not create this domain system dynamically. Presentation nodes such as `PlatformUpgradeAssetOverlay` read the same scene-owned runtime to decide which platform upgrade assets are visible.

This prevents split ownership where an upgrade is applied to one runtime object while the visual layer watches a different or missing one.
