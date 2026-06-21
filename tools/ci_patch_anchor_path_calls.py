from pathlib import Path

for path in (
    Path("scripts/boarding/boarding_enemy_controller.gd"),
    Path("scripts/boarding/rope_saboteur_behavior.gd"),
):
    source = path.read_text(encoding="utf-8")
    updated = source.replace(".get_path(selected_anchor_id)", ".get_anchor_path(selected_anchor_id)")
    if updated == source:
        raise SystemExit(f"Expected anchor path call was not found in {path}")
    path.write_text(updated, encoding="utf-8")
