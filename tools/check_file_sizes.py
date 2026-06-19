#!/usr/bin/env python3
"""Fail when manually maintained project files exceed the line limit."""

from __future__ import annotations

from pathlib import Path
import sys

MAX_LINES = 600
WARNING_LINES = 450
CHECKED_SUFFIXES = {
    ".gd",
    ".godot",
    ".tscn",
    ".tres",
    ".md",
    ".json",
    ".py",
    ".yml",
    ".yaml",
}
IGNORED_DIRECTORIES = {".git", ".godot", "builds", "exports"}


def iter_checked_files(root: Path):
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if any(part in IGNORED_DIRECTORIES for part in path.parts):
            continue
        if path.suffix.lower() not in CHECKED_SUFFIXES:
            continue
        yield path


def count_lines(path: Path) -> int:
    with path.open("r", encoding="utf-8") as source:
        return sum(1 for _ in source)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    violations: list[tuple[Path, int]] = []
    warnings: list[tuple[Path, int]] = []

    for path in iter_checked_files(root):
        line_count = count_lines(path)
        relative_path = path.relative_to(root)
        if line_count > MAX_LINES:
            violations.append((relative_path, line_count))
        elif line_count >= WARNING_LINES:
            warnings.append((relative_path, line_count))

    for path, line_count in sorted(warnings):
        print(f"WARNING: {path} has {line_count} lines; consider splitting it.")

    for path, line_count in sorted(violations):
        print(f"ERROR: {path} has {line_count} lines; maximum is {MAX_LINES}.")

    if violations:
        return 1

    print("File size guard passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
