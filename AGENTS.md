# AGENTS.md

## Source of truth
1. `examples/screen-doc/*.md` are the human-authored intent documents.
2. `examples/screens/*.screen.json` are the authoritative machine contracts.
3. `examples/tokens/*.json` hold the design values.
4. Generated outputs are disposable artifacts, not editable sources.

## Mandatory workflow
1. Read `MASTER_BLUEPRINT.md`.
2. Read `examples/catalogs/component-catalog.json`.
3. Read the target `screen-doc`.
4. Create or update exactly one `screen-spec`.
5. Run validation before generation.
6. Generate HTML, SwiftUI, and Compose artifacts.
7. Review the HTML preview first.
8. Fix upstream inputs only.

## Hard constraints
- Do not edit generated SwiftUI, Compose, or HTML files by hand.
- Do not use raw color or spacing literals inside `ScreenSpec`.
- Do not introduce components outside the catalog.
- Keep one `ScreenSpec` focused on one primary intent.
