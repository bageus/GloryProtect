#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"

mapfile -t scenario_files < <(
  find tests/unit tests/integration -type f -name '*_scenarios.gd' -print | sort
)

if (( ${#scenario_files[@]} == 0 )); then
  echo "No Godot scenario files found." >&2
  exit 1
fi

for scenario_file in "${scenario_files[@]}"; do
  echo "::group::${scenario_file}"
  "${GODOT_BIN}" \
    --headless \
    --path . \
    --script "res://${scenario_file}"
  echo "::endgroup::"
done

echo "All ${#scenario_files[@]} Godot scenarios passed."
