# Mouse buildable placement UI

NEXT-19 replaces production keyboard placement with a mouse-driven command layer while keeping domain ownership unchanged.

## Ownership

- `BuildablePlacementController` owns only UI state: selected type, selected buildable, placement/move mode, hover cell, and feedback.
- `BuildableGrid` remains the only owner of buildable occupancy and validates every place, move, and demolish command.
- `PlatformController` remains the only source of platform cell geometry and converts local pointer positions to cell indices.
- `BuildablePlacementPanel` sends high-level commands to the controller and never mutates inventory, grid dictionaries, or role stations.
- `MedicalStationSystem` and `TurretSystem` continue reacting to grid signals, so relocation is immediate while assigned operators receive a new physical destination.

## Command blocking

Placement commands are accepted only in `GameFlowController.RUNNING`. Manual pause, card selection, start delay, and game over preserve the visible UI but disable mutations.

## Cell feedback

The grid exposes stable unavailability reason ids for invalid cells, unsupported cells, occupied cells, locked buildables, and deployment limits. The controller maps these ids to player-facing feedback while the platform visual uses the same validation result for color coding.

## Production compatibility

The old debug input nodes remain in the inherited prototype scene for legacy tests, but the production scene disables their processing and wires the visual/HUD to `BuildablePlacementController`. The crew command panel also defers platform clicks to the placement controller when it is present.
