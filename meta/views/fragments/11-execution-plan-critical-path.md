| Phase | Status | Objective | Depends On | Exit evidence |
|---|---|---|---|---|
| P0 | Done | baseline runtime, generator, doc-sync, and audit path is re-verified | none | `swift test`, `ds-doc-sync sync`, `dsctl audit`, and `dsctl generate --config ... --screen-id login` succeed on the checked-in baseline |
| P1 | Done | final-completion planning package and authoritative-source annexes are defined | P0 | `11`, `12`, `20`, `23`, `24`, and `25` describe the final core delivery target, not only the baseline |
| P2 | Done | authoring contract and ScreenSpec model are expanded for core interactive screens | P1 | schema, models, docs, and examples express state, action, navigation, asset, and preview semantics explicitly |
| P3 | Done | screen-doc compiler and validator close the starter-spec to complete-spec path | P2 | `compile-screen-doc` emits completion-guided output and incomplete specs fail before generation |
| P4 | Done | generators and HTML review support enriched contract semantics end-to-end | P2, P3 | SwiftUI, Compose, and HTML artifacts preserve the same meaning across preview states and interactions |
| P5 | Done | iOS and Android host integration adapters compile against generated outputs | P4 | generated adapters wire to host smoke projects without hand-editing generated files |
| P6 | Done | runtime/governance/doc-sync/audit cover the expanded contract and evidence set | P2, P3, P4, P5 | contract views, fragments, manifests, audit checks, and annex docs all reflect the final core workflow |
| P7 | Done | login and product-detail pass the full delivery contract | P3, P4, P5, P6 | both slices pass compile, validate, generate, review, integrate, and verification evidence gates |
