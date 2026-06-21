# CI runner blocker

The Project guards jobs for PR #81 and PR #82 are ending before any workflow step is created. GitHub returns no job logs and no steps, so the Godot suite and file-size command have not executed. Runtime-dependent pull requests must remain draft until a runner executes the workflow or the same commands run in another Godot 4.6.2 environment.
