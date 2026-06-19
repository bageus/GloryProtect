# Instructions for coding agents

Before changing code or scenes, read:

1. [`PROJECT_RULES.md`](PROJECT_RULES.md) — mandatory engineering rules.
2. [`ARCHITECTURE.md`](ARCHITECTURE.md) — canonical architecture and ownership boundaries.
3. Relevant gameplay documentation in `docs/`.

These requirements are mandatory:

- Do not create monolithic classes, scenes, managers, or utility files.
- No source file may exceed 600 lines.
- At approximately 450 lines, split the file before adding substantial new behavior.
- Every mutable state must have exactly one owner.
- Do not duplicate state in UI, visual nodes, or neighboring systems.
- Minimize or eliminate hardcoded gameplay and balance values.
- Put tunable values in typed Godot `Resource` data.
- Implement mechanics as systems or focused components.
- UI sends commands and displays events; it does not own gameplay logic.
- Follow the dependency directions and domain boundaries in `ARCHITECTURE.md`.
- Update `ARCHITECTURE.md` in the same change whenever architectural boundaries change.
- Do not add temporary architectural shortcuts that contradict the documented design.
- Use Godot 4.6.2 stable and GDScript-compatible APIs.
- Preserve the confirmed gameplay rules in `docs/02_GAMEPLAY_RULES.md`.

Before committing, run the checklist in `PROJECT_RULES.md`.
