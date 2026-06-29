# Persistent run records

NEXT-22 keeps three scopes of statistics separate:

- `RunStatistics` owns mutable values for the active run and creates the final `RunStatisticsSnapshot`;
- `SessionRecordsStore` owns records for the current application process only;
- `PersistentRecordsService` owns records stored between application launches.

## Finalization flow

`RunStatistics` updates neither record store while a run is active. When `GameFlowController.run_ended` is received, it creates one immutable snapshot and then:

1. registers the snapshot in `SessionRecordsStore`;
2. registers the same snapshot in `PersistentRecordsService` through the typed `PersistentRecords` proxy;
3. emits `run_finalized` for the game-over UI.

This ordering guarantees that the result screen reads already-updated session and persistent values. Starting or restarting a run resets only `RunStatistics`.

## Storage

`PersistentRecordsService` is the `PersistentRecordsRuntime` autoload. It loads `user://run_records.json` on startup and writes after every finalized run.

Format version `1` stores only plain values:

```json
{
  "format_version": 1,
  "completed_runs": 0,
  "best_survival_seconds": 0.0,
  "best_physical_kills": 0
}
```

No scene nodes, resources, or runtime object references are serialized.

## Compatibility and recovery

- Missing files produce empty records.
- Invalid JSON produces empty in-memory records without blocking startup.
- A later completed run replaces a damaged file with valid versioned data.
- Unversioned legacy dictionaries are migrated from either the current key names or the aliases `best_time_seconds` and `best_kills`.
- Unsupported future versions are safely reset instead of being interpreted as the current format.

A score record is intentionally not stored yet because NEXT-17 has not defined a final score formula. The format can be migrated when that formula is approved.

## UI

The game-over panel keeps the current run values in their existing rows. The record rows explicitly label session and all-time values so they cannot be confused.
