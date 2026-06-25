# Fixed platform service-cell layout

Issue #139 replaces the previous movable medical-station rule with a fixed service layout for the 18-cell platform.

## Cell ownership

Cells are zero-based in code and one-based in player-facing text.

- `0–1`: left anchor system.
- `2–5`: normal buildable cells.
- `6–7`: the only medical-station footprint.
- `8–9`: replacement portal footprint.
- `10–11`: driver console footprint.
- `12–15`: normal buildable cells.
- `16–17`: right anchor system.

All service cells remain reserved even while the corresponding optional object is not installed.

## Medical station

The medical station has one logical buildable ID and one placement anchor (`6`), but occupies both cells `6` and `7`. Both cells resolve to the same buildable ID for selection and demolition. Its world position is the average center of the two cells.

The station can be demolished and installed again, but it cannot be moved or installed outside this footprint. Placement validation and footprint occupancy belong to `BuildableGrid`; UI code only reads the result.

## Anchor systems

The four anchor attachment points align with the centers of the two edge cells on each side. This keeps anchor gameplay geometry and the visible winches inside their reserved service cells.

## Compatibility

Legacy balance resources may still serialize the old medical anchor value. Runtime placement uses the fixed layout methods on `BuildableBalance`, so old serialized values cannot reopen normal buildable cells for the medical station.
