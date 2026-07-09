# Upgrade asset overlay standard

This document defines the single accepted path for platform upgrade assets.

## Single owner

`PlatformUpgradeAssetOverlay` is the only owner of common platform upgrade asset presentation. It may read domain systems and draw recoverable visuals, but it must not mutate gameplay state.

Specialized subclasses such as `PlatformUpgradeAssetOverlayStabilityFixed` may adjust layout for already supported visuals. They must not introduce a second rendering pipeline for new platform upgrade assets.

## Adding a platform upgrade asset

A new platform upgrade asset must use the same sequence as the existing steering/control asset:

1. Define the visual identity in the common overlay asset list.
2. Add one visibility predicate that reads the owning domain runtime.
3. Add one draw method that calls the common centered texture draw helper.
4. Add the asset id to the common visible-asset test list.
5. Add an integration guard for the visibility predicate, center, size, and active-state behavior.

Do not add a separate scene node, z-index layer, or presentation controller for the same upgrade unless `ARCHITECTURE.md` is updated with a new ownership boundary.

## Safety rule

A new asset must not make existing platform upgrade assets disappear when it fails. If a new texture import, path, or alpha crop is uncertain, first add a narrow validation change or a dedicated asset-loading wrapper instead of wiring it directly into the common overlay renderer.

## Rejected patterns

- A separate `Node2D` that renders a platform upgrade while other platform upgrades are rendered by `PlatformUpgradeAssetOverlay`.
- Drawing the same upgrade in both a base overlay and a subclass.
- Adding a new asset by copying an existing draw path into a sibling script.
- Fixing visibility only with z-index changes when the asset is not using the common overlay flow.

## Review checklist

Before merging a platform upgrade asset PR, confirm:

- Existing ids such as `control`, `speed`, `stability`, and core overlays still appear in `get_visible_asset_ids_for_tests()` under their original conditions.
- New asset visibility depends only on the owning domain runtime.
- The PR does not create a second owner for the same visual state.
- The common overlay file remains below the hard 600-line limit and is evaluated for splitting after 450 lines.
