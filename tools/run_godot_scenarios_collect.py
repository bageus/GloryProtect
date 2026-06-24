from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
RESULTS = ROOT / "test-results" / "godot"
RESULTS.mkdir(parents=True, exist_ok=True)

scenarios = sorted(
    list((ROOT / "tests" / "unit").glob("*_scenarios.gd"))
    + list((ROOT / "tests" / "integration").glob("*_scenarios.gd"))
)
failures: list[str] = []

for scenario in scenarios:
    relative = scenario.relative_to(ROOT).as_posix()
    log_name = relative.replace("/", "__").removesuffix(".gd") + ".log"
    log_path = RESULTS / log_name
    try:
        result = subprocess.run(
            [
                "godot",
                "--headless",
                "--path",
                str(ROOT),
                "--script",
                f"res://{relative}",
            ],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=90,
            check=False,
        )
        log_path.write_text(result.stdout, encoding="utf-8")
        if result.returncode != 0:
            failures.append(f"{relative} status={result.returncode}")
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        log_path.write_text(output, encoding="utf-8")
        failures.append(f"{relative} status=timeout")

(RESULTS / "failures.txt").write_text(
    "\n".join(failures) + ("\n" if failures else ""),
    encoding="utf-8",
)

for failure in failures:
    print(failure)

sys.exit(1 if failures else 0)
