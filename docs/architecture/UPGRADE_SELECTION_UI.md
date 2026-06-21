# Upgrade Selection UI

Issue #40 replaces the placeholder two-card screen with a read-only three-card presentation layer.

## Ownership

`UpgradeSystem` owns the current offer, runtime state, costs, diagnostics, specialization events and command validation. `UpgradeSelectionPanel` never generates cards, changes weights, applies effects or decides specialization readiness.

The panel receives an offer through `offer_opened`, reads card definitions through read-only accessors and sends a command containing:

- stable `card_id`;
- the offer number that produced the button.

`UpgradeSystem.choose_card_for_offer()` rejects commands from stale offers. This prevents a queued double click from buying the same repeatable card from the next offer.

## Presentation

Each card displays:

- title;
- branch;
- card type;
- description;
- base effect summary;
- prerequisites and their current state;
- repeat count when `repeat_limit > 1`;
- alternatives closed by a specialization.

Normal offers and specialization events use different mode headings. The panel supports one, two or three cards without creating duplicates or placeholder copies.

## Sequential purchases and pause

Card selection uses `GameFlowController.RunState.CARD_SELECTION`, so the scene tree remains paused while the panel runs with `PROCESS_MODE_ALWAYS`.

When enough coins remain, `UpgradeSystem` generates and emits the next offer before leaving card-selection state. The panel rebuilds in place and the world never receives an intermediate running frame.

## Diagnostics

`F9` toggles a read-only diagnostic list. Reasons are obtained from `UpgradeSystem.get_card_unavailability_reason()` and translated by `UpgradeCardFormatter`. The UI does not reproduce filtering rules.

## Shield display

`ShieldSystem.get_display_health_percent()` clamps presentation values to `0–100%`. Gameplay calculations continue to use `get_health_percent()`.

## Tests

- `tests/unit/upgrade_card_formatter_scenarios.gd`
- `tests/integration/upgrade_selection_panel_scenarios.gd`

The scenarios cover three cards from one branch, fewer than three unique options, specialization presentation, repeat counters, prerequisite marks, stale-command rejection, exact single coin charge and uninterrupted pause during sequential purchases.
