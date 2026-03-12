# AGENTS.md

## Source of truth
1. `contracts/*` are the human-authored authoritative contracts.
2. `schemas/current/*.schema.json` are the active schema boundaries.
3. `PreviewApp/*` is the review/evidence shell boundary, not source of truth.
4. `HostApps/*` is the native runtime proof boundary, not source of truth.
5. Generated outputs are disposable artifacts, not editable sources.

## Mandatory workflow
1. Read `MASTER_BLUEPRINT.md`.
2. Read `docs/adr/0001-authoritative-contracts.md`.
3. Read `docs/PLAN.md`.
4. Read `docs/ARCHITECTURE.md`.
5. Read `docs/RUNBOOK.md`.
6. Read `contracts/README.md`.
7. Read the target contract under `contracts/*`.
8. Run validation before generation.
9. Review the HTML/PreviewApp output first.
10. Fix upstream contracts only.

## Hard constraints
- Do not edit generated SwiftUI, Compose, HTML, adapter payloads, or evidence artifacts by hand.
- Do not use raw color or spacing literals inside source-owned contracts.
- Do not introduce registry items outside the declared registry contract.
- Keep one contract file focused on one primary responsibility.
