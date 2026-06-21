# Upgrade UI and Diagnostics

## Scope

This document describes the presentation boundary for issue #40. The upgrade UI displays the current offer, forwards a selected stable card ID and exposes read-only diagnostics. It does not generate offers, calculate weights, validate prerequisites or apply effects.

## Ownership

| State or decision | Owner |
|---|---|
| Current offer, offer number and cost | `UpgradeSystem` |
| Selected cards, repeat counts and specializations | `UpgradeRuntime` |
| Ordinary availability reason IDs | `UpgradeDrawGenerator` through `UpgradeSystem` |
| Specialization-event availability | `UpgradeSystem` |
| Domain effect application | `UpgradeEffectApplier` |
| Human-readable presentation data | `UpgradePresentationBuilder` |
| Buttons, labels and input forwarding | `UpgradeSelectionPanel` |

## Read-only card model

`UpgradePresentationBuilder` converts an immutable `UpgradeDefinition` plus runtime state into `UpgradeCardViewData`:

```text
card_id
branch label
card type label
title and description
effect summary
requirements summary
repeat progress
specialization warning
unavailability reason ID and text
```

The view model contains no command methods and cannot mutate gameplay state.

## Selection flow

```text
UpgradeSystem opens offer
→ UpgradeSelectionPanel reads current card IDs
→ presentation builder creates view data
→ player selects card
→ panel sends card_id to UpgradeSystem
→ UpgradeSystem validates, spends coins and applies effect
→ runtime records the card
→ next offer is generated or card selection ends
```

The panel records the displayed offer number. A delayed or repeated click from an older offer is rejected before sending a command. While the synchronous command is in progress, all card buttons are disabled.

## Ordinary offers

The panel supports one to three unique cards. It does not assume that cards belong to different branches; all three cards may come from one branch. Repeatable cards show their current count and maximum, for example `2/5` or `2/3`.

## Specialization events

A specialization offer is visually marked separately from an ordinary offer. All three cards show the specialization type and explicitly warn which alternative specialization cards will be closed by the selection.

The UI does not decide which branch is ready. It only reads `UpgradeSystem.is_specialization_offer()` and `get_specialization_offer_branch()`.

## Diagnostics

Diagnostics iterate over catalog definitions and request a reason ID from `UpgradeSystem`. `UpgradePresentationBuilder` converts stable reason IDs into readable text. The filtering rules remain in the upgrade domain.

Examples:

```text
missing_prerequisite
missing_repeat_count
branch_not_specialized
branch_line_not_completed
repeat_limit_reached
specialization_closed
```

## Pause boundary

`GameFlowController` owns card-selection pause. Sequential affordable purchases replace the offer without returning to active simulation. The panel does not pause or resume the world directly.

## Tests

- `upgrade_presentation_scenarios.gd` validates labels, effects, requirements, repeat counters and diagnostic text.
- `upgrade_specialization_view_scenarios.gd` validates the three specialization presentations and alternative-lock warnings.
- `upgrade_ui_scenarios.gd` validates three buttons, diagnostics, continuous pause and rejection of a stale repeated selection.
