#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
SCENARIO_TIMEOUT_SECONDS="${SCENARIO_TIMEOUT_SECONDS:-90}"
RESULT_DIR="${RESULT_DIR:-test-results/godot}"
mkdir -p "${RESULT_DIR}"

import_log="${RESULT_DIR}/project-import.log"
set +e
timeout --signal=TERM --kill-after=5s 120s \
  "${GODOT_BIN}" --headless --path . --import \
  >"${import_log}" 2>&1
import_status=$?
set -e
if (( import_status != 0 )); then
  echo "Godot project import failed with exit ${import_status}." >&2
  tail -n 120 "${import_log}" >&2
  exit 1
fi

mapfile -t scenario_files < <(
  find tests/unit tests/integration -type f -name '*_scenarios.gd' -print \
    | sort \
    | awk '$0 > "tests/integration/medic_field_action_priority_scenarios.gd"'
)

if (( ${#scenario_files[@]} == 0 )); then
  echo "No Godot scenario files found." >&2
  exit 1
fi

for scenario_file in "${scenario_files[@]}"; do
  log_name="${scenario_file//\//__}"
  log_path="${RESULT_DIR}/${log_name%.gd}.log"
  echo "::group::${scenario_file}"

  set +e
  timeout --signal=TERM --kill-after=5s "${SCENARIO_TIMEOUT_SECONDS}s" \
    "${GODOT_BIN}" \
      --headless \
      --path . \
      --script "res://${scenario_file}" \
    >"${log_path}" 2>&1
  scenario_status=$?
  set -e

  if (( scenario_status != 0 )); then
    if (( scenario_status == 124 || scenario_status == 137 )); then
      echo "Scenario timed out after ${SCENARIO_TIMEOUT_SECONDS}s." >&2
    else
      echo "Scenario failed with exit ${scenario_status}." >&2
    fi
    grep -E -i 'parse error|script error|error:|assert|failed|invalid|not found' \
      "${log_path}" | head -n 160 || true
    echo "--- final output ---"
    tail -n 120 "${log_path}"
    echo "::endgroup::"
    exit 1
  fi

  grep -E -i 'scenarios? passed|warning|error' "${log_path}" | tail -n 40 || true
  echo "::endgroup::"
done

echo "All ${#scenario_files[@]} remaining Godot scenarios passed."
