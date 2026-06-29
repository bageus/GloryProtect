# Persistent run records

NEXT-22 keeps three scopes of statistics separate:

- `RunStatistics` owns mutable values for the active run and creates the final `RunStatisticsSnapshot`;
- `SessionRecordsStore` owns records for the current application process only;
- `PersistentRecordsService` owns records stored between application launches.

## Finalization flow

`RunStatistics` updates neither record store while a run is active. When `GameFlowController.run_ended` is received, it creates one immutable snapshot and then:

1. registers the snapshot in `SessionRecordsStore`;
2. registers the same snapshot in `PersistentRecordsService` through the typed `PersistentRecords` proxy;
3. reads whether the final score replaced the all-time record;
4. emits `run_finalized` for the game-over UI.

This ordering guarantees that the result screen reads already-updated session and persistent values. Starting or restarting a run resets only `RunStatistics`.

## Score formula

`RunScoreCalculator` is the only owner of the score formula. Formula version `1` uses full survival seconds and all defeated enemies:

```text
base_score = (floor(survival_seconds) + total_kills) * 10
```

Every complete five-minute interval adds a harmonic bonus:

```text
intervals = floor(full_survival_seconds / 300)
bonus = round(1000 * (1/1 + 1/2 + ... + 1/intervals))
score = base_score + bonus
```

Examples of the cumulative time bonus are `1000`, `1500`, `1833`, `2083`, and `2283` points at 5, 10, 15, 20, and 25 minutes.

`total_kills` includes:

- physical enemies removed through the boarding reward flow;
- strategic enemies that reach and collide with shield sections;
- strategic enemies destroyed by shield/core row-destruction effects.

Economy, cards, the end reason, and defender losses do not modify score.

## Defender losses

Every `CrewManager.defender_died` event increments the run loss counter. A defender dying again after revival counts as another loss. The value is stored only in the final run snapshot and displayed on the result screen; it is not a score penalty.

## Storage

`PersistentRecordsService` is the `PersistentRecordsRuntime` autoload. It loads `user://run_records.json` on startup and writes after every finalized run.

Format version `2` stores only plain values:

```json
{
  "format_version": 2,
  "score_formula_version": 1,
  "completed_runs": 0,
  "best_survival_seconds": 0.0,
  "best_physical_kills": 0,
  "best_score": 0
}
```

No scene nodes, resources, or runtime object references are serialized.

A result replaces the score record when its score is greater than or equal to the stored score. Therefore an equal score marks the latest run as the new record, matching the rule that the last equal result wins.

## Compatibility and recovery

- Missing files produce empty records.
- Invalid JSON produces empty in-memory records without blocking startup.
- A later completed run replaces a damaged file with valid versioned data.
- Unversioned legacy dictionaries are migrated from either the current key names or the aliases `best_time_seconds` and `best_kills`.
- Format version `1` preserves completed runs, best time, and best physical kills while initializing `best_score` to `0`.
- A changed score-formula version preserves non-score records and resets only `best_score`.
- Unsupported future storage versions are safely reset instead of being interpreted as the current format.

## UI

The game-over panel displays:

- the domain-provided end reason;
- `НОВЫЙ РЕКОРД` when the score replaced the all-time record;
- score and harmonic time bonus;
- survival time;
- total, physical, and strategic kills;
- defender losses;
- session and all-time score, time, and physical-kill records.

The UI does not calculate score or decide whether a result is a record.
