| Workstream | Verification | Expected signal |
|---|---|---|
| Planning/docs alignment | reread `MASTER_BLUEPRINT`, `11`, `12`, `18`, `20`, `23`, `24`, and `25` together | one overall plan and one authoritative-source annex structure are visible without conflicting authority |
| Authoring contract | schema/example updates, `compile-screen-doc` report tests, and source-of-truth reread | starter-spec path is explicit and no silent heuristic output is treated as final |
| Semantic validation | positive/negative validation tests for state/action/binding/route/asset/token/catalog rules | incomplete specs fail early and complete specs pass cleanly |
| Multi-platform generation | SwiftUI / Compose / HTML golden tests and manifest/report diff checks | all three outputs preserve the same contract semantics deterministically |
| HTML review | generated preview bundle inspection across declared preview states | every declared preview state is visible and reviewable in HTML |
| Host integration | iOS/Android smoke integration, compile-backed host smoke tests, and adapter compile checks | generated adapters link to host code without hand edits to generated files |
| Governance and audit | `ds-doc-sync sync`, contract export checks, and `dsctl audit` | contract views, fragments, generated docs, and evidence refs remain fresh and aligned |
| Vertical slice acceptance | end-to-end runs for `login` and `product-detail` | both slices satisfy compile, validate, generate, review, integrate, and audit gates |
