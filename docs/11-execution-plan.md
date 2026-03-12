# 11. Execution Plan

## 1. Delivery target

이번 delivery target은 **지원할 핵심기능에 대해 `screen-doc -> ScreenSpec -> validate -> generate -> review -> integrate` 를 최종 완성 수준으로 닫는 것** 이다.

여기서 핵심기능은 아래 여섯 축으로 정의한다.

1. `screen-doc` 에서 starter spec과 completion report를 만드는 authoring path
2. 상태, 액션, 네비게이션, asset, preview state를 담는 explicit `ScreenSpec`
3. unresolved/ambiguous semantics를 generation 전에 차단하는 semantic validation
4. SwiftUI / Compose / HTML이 같은 contract 의미를 유지하는 deterministic generation
5. declared preview state 전체를 보여주는 HTML review path
6. generated adapter만으로 host app에 연결 가능한 integration path

가장 중요한 acceptance path는 아래 여섯 항목이다.

```text
login screen-doc -> starter spec -> completed ScreenSpec -> validate -> generate -> review -> integrate
product-detail screen-doc -> starter spec -> completed ScreenSpec -> validate -> generate -> review -> integrate
swift test
swift run ds-doc-sync sync --project-root . --json
swift run dsctl audit --project-root . --json
swift run dsctl generate --config examples/configs/dsctl.config.json --screen-id login --json
```

## 2. Baseline and implementation delta

- SwiftPM package, CLI, MCP, doc-sync, validator, generator baseline은 이미 존재한다.
- `login`, `product-detail` 는 현재 baseline slice를 보여주지만, final completion contract를 닫기에는 authoring semantics가 아직 충분히 explicit하지 않다.
- 현재 baseline은 compile/validate/generate/audit path를 증명했다.
- 다음 단계는 그 baseline 위에 **starter-spec authoring, complete-spec validation, multi-state review, host integration evidence** 를 올리는 것이다.
- 전체 master plan은 `11`, `12`, `20` 이 담당하고, authoritative-source 전용 workstream은 `24`, `25` annex로 관리한다.

## 3. Core completion contract

이번 cycle에서 completion으로 인정하는 결과는 아래와 같다.

- `screen-doc` 는 사람의 intent를 담고, `compile-screen-doc` 는 deterministic starter spec과 completion report를 낸다.
- authoritative `ScreenSpec` 은 core interactive screen에 필요한 상태, 액션, 네비게이션, asset, preview state를 explicit하게 담는다.
- validator는 unresolved node, broken binding, invalid route, missing asset, invalid token alias를 generation 전에 막는다.
- generator는 complete `ScreenSpec` 에 대해서만 SwiftUI / Compose / HTML artifact를 만든다.
- HTML review bundle은 declared preview state 전부를 사람이 확인할 수 있게 보여준다.
- iOS / Android host는 generated adapter를 통해 state/actions/navigation을 연결하고 generated file을 직접 수정하지 않는다.

## 4. Observable done condition

아래 조건이 모두 참이어야 이번 plan을 완료로 본다.

1. `ScreenSpec` schema/model/docs/examples가 `login` 과 `product-detail` 의 핵심 흐름을 heuristic placeholder 없이 표현한다.
2. `compile-screen-doc` 는 starter spec과 completion report를 내고, unresolved authoring gap은 validator/generator 단계로 흘러가지 않는다.
3. `validate` 는 state/action/binding/route/asset/token/catalog completeness를 강제한다.
4. `generate` 는 enriched `ScreenSpec` 에서 SwiftUI / Compose / HTML preview를 deterministic하게 생성한다.
5. HTML review bundle이 declared preview state를 모두 노출하고 review 신호를 남긴다.
6. iOS / Android host integration smoke path가 generated adapter만으로 연결된다.
7. runtime/governance/doc-sync/audit 문서와 source가 확장된 contract/evidence set을 모두 반영한다.
8. `login`, `product-detail` 두 vertical slice가 fresh evidence와 함께 end-to-end acceptance를 통과한다.

## 5. Critical path

<!-- GENERATED:BEGIN execution-plan-critical-path -->
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
<!-- GENERATED:END execution-plan-critical-path -->

## 6. Decision gates

<!-- GENERATED:BEGIN execution-plan-decision-gates -->
| Gate | Check | Pass condition | On fail |
|---|---|---|---|
| G1 Final contract gate | target schema/model covers the supported core screens without heuristic placeholders | docs, schema, and examples can express `login` and `product-detail` states/actions/navigation/assets explicitly | stop generator expansion and finish the contract model first |
| G2 Authoring gate | `screen-doc` to starter-spec path is deterministic and completion rules are explicit | `compile-screen-doc` emits starter spec + completion report and unresolved items cannot reach generation | keep compile/report work in front of validator/generator until authoring gaps are sealed |
| G3 Semantic validation gate | validator blocks unresolved or ambiguous semantics before code generation | incomplete specs fail with actionable errors and complete specs validate cleanly | extend validation before adding more renderer behavior |
| G4 Generator and review gate | enriched contract renders consistently across SwiftUI / Compose / HTML | preview states, actions, navigation labels, and media primitives are preserved across all outputs | hold host integration until platform parity is proven |
| G5 Integration gate | generated state/action/navigation adapters connect to host code without editing generated files | iOS / Android smoke integration compiles using generated adapters only | fix integration packaging before claiming completion |
| G6 Governance gate | runtime/governance/docs/audit all reflect the expanded contract and evidence set | `ds-doc-sync`, `audit`, and authoritative-source annex docs stay fresh with new evidence keys and inventories | freeze release until source-of-truth and evidence converge |
| G7 Acceptance gate | two canonical slices prove the product is complete for core scope | `login` and `product-detail` pass compile, validate, generate, review, integrate, and verification evidence gates | keep remaining tasks open and do not claim final completion |
<!-- GENERATED:END execution-plan-decision-gates -->

## 7. Verification map

<!-- GENERATED:BEGIN execution-plan-verification-map -->
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
<!-- GENERATED:END execution-plan-verification-map -->

## 8. Plan package structure

- `11`: 전체 execution contract와 critical path
- `12`: stable task/status ledger
- `20`: requirement-to-task-to-evidence traceability
- `24`: authoritative-source 전용 completion annex
- `25`: authoritative-source 전용 workstream task matrix

## 9. Document sync rules

아래 변화가 생기면 문서도 함께 업데이트한다.

- authoring contract 변경: `03`, `06`, `08`, `11`, `12`, `20`, `23`, `24`, `25`, `schemas/*`, `examples/*`
- CLI / MCP / exit code / contract path 변경: `07`, `11`, `20`, `23`, `24`, `25`, `meta/runtime/contracts.cue`
- governance source / evidence / fragment 변경: `11`, `12`, `20`, `23`, `24`, `25`, `meta/governance/contracts.cue`, `meta/views/governance.fragments.json`, `meta/views/fragments/*`
- host integration contract 변경: `17`, `18`, `11`, `12`, `20`, `24`, `25`
- acceptance baseline 변경: `18`, `21`, `22`, `ALL_DOCS_COMBINED.md`, `audit/integrity-report.json`
