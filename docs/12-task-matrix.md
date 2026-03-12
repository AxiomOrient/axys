# 12. Task Matrix

현재 저장소는 baseline 구현을 이미 가진다.
이 matrix는 **이미 확보한 baseline evidence** 와 **최종 핵심기능 completion work** 를 한 ledger로 유지해 stable task ID를 잃지 않도록 만든다.
structured row는 hand-edit 대상이 아니라 `meta/views/governance.fragments.json` source를 렌더링한 generated view다.

Status 의미는 아래 세 가지로 닫는다.

- `Done`: checked-in repo와 fresh evidence로 이미 확인된 작업
- `In Progress`: 현재 critical path에서 바로 닫고 있는 작업
- `Planned`: dependency가 남아 있어 아직 닫지 않은 작업

## 1. Task rows

<!-- GENERATED:BEGIN task-matrix-task-rows -->
| Task ID | Status | Priority | Action | Depends On | Done when | Evidence required |
|---|---|---|---|---|---|---|
| BASE-01 | Done | P0 | runtime, generator, CLI, MCP, doc-sync, audit baseline을 fresh evidence로 다시 고정한다 | none | 현재 baseline path가 명령과 테스트로 다시 확인된다 | `swift test`, `ds-doc-sync sync`, `dsctl audit`, `dsctl generate` output |
| PLAN-01 | Done | P0 | active planning package를 final core completion 기준으로 재작성한다 | BASE-01 | `11`, `12`, `20`, `23`, `24`, `25`, `18`, `MASTER_BLUEPRINT` 가 final target과 baseline을 함께 설명한다 | updated docs, fragment export, reread checklist |
| MODEL-01 | Done | P0 | `ScreenSpec` schema/model을 core interactive screen에 맞게 확장한다 | PLAN-01 | 상태, 액션, 네비게이션, asset, preview state, binding contract가 explicit field로 정의된다 | schema diff, model tests, updated examples |
| DOC-01 | Done | P1 | `03`, `06`, `08`, `17` 과 example specs/docs를 final contract 기준으로 승격한다 | MODEL-01 | source-of-truth, data model, generation, integration docs가 확장된 contract와 충돌하지 않는다 | updated docs, example diff, link scan |
| AUTHOR-01 | Done | P0 | `compile-screen-doc` 를 starter spec + completion report path로 재정의한다 | MODEL-01 | authoring output이 deterministic하고 unresolved item이 명시적으로 보고된다 | compile tests, starter-spec snapshots, report schema |
| AUTHOR-02 | Done | P1 | `login`, `product-detail` screen-doc에 필요한 structured section과 deterministic mapping을 닫는다 | AUTHOR-01 | 두 example 모두 completion report 기준으로 authoritative spec 완성이 가능하다 | example docs, compile snapshots, acceptance checklist |
| VALIDATE-01 | Done | P0 | validator가 unresolved, state/action/binding/route/asset/token/catalog completeness를 강제한다 | MODEL-01, AUTHOR-01 | incomplete spec은 fail하고 complete spec은 clean pass 한다 | validator tests, negative fixtures, JSON reports |
| GENERATE-01 | Done | P0 | SwiftUI / Compose / HTML generator를 explicit state/action/navigation/media semantics로 확장한다 | MODEL-01, VALIDATE-01 | 세 플랫폼 출력이 같은 contract 의미를 유지한다 | golden tests, generated artifacts, manifest diff |
| REVIEW-01 | Done | P1 | HTML review bundle에 preview state coverage와 review signal을 추가한다 | GENERATE-01 | declared preview state 전체가 HTML에서 review 가능하다 | generated preview bundle, review checklist |
| INTEGRATE-01 | Done | P1 | iOS host integration pack과 smoke path를 만든다 | GENERATE-01 | generated state/action/navigation adapter가 host app에서 compile-backed smoke로 검증된다 | host compile log, compile-backed smoke tests, integration guide update |
| INTEGRATE-02 | Done | P1 | Android host integration pack과 smoke path를 만든다 | GENERATE-01 | generated state/action/navigation adapter가 host app에서 compile-backed smoke로 검증된다 | host compile log, compile-backed smoke tests, integration guide update |
| GOV-01 | Done | P0 | runtime/governance contracts, doc-sync manifest, audit evidence를 final core workflow 기준으로 확장한다 | MODEL-01, AUTHOR-01, VALIDATE-01, GENERATE-01 | expanded contract/evidence set이 source-owned view와 audit check에 반영된다 | contract view export, audit JSON, manifest diff |
| ASOT-01 | Done | P1 | authoritative-source annex(`24`, `25`)와 master ledger 사이의 workstream sync를 닫는다 | GOV-01 | annex task와 master task가 같은 source/evidence 경로를 가리킨다 | annex docs, traceability rows, reread checklist |
| E2E-01 | Done | P0 | `login` 최종 acceptance path를 닫는다 | AUTHOR-02, VALIDATE-01, GENERATE-01, REVIEW-01, INTEGRATE-01, INTEGRATE-02 | default/loading/error, field binding, submit action, review/integration evidence가 모두 통과한다 | login acceptance report, generated artifacts, host smoke |
| E2E-02 | Done | P0 | `product-detail` 최종 acceptance path를 닫는다 | AUTHOR-02, VALIDATE-01, GENERATE-01, REVIEW-01, INTEGRATE-01, INTEGRATE-02 | media/card/content/CTA/navigation or purchase flow가 review/integration evidence와 함께 통과한다 | product-detail acceptance report, generated artifacts, host smoke |
| VERIFY-01 | Done | P0 | 최종 completion evidence suite를 다시 통과시킨다 | DOC-01, GOV-01, ASOT-01, E2E-01, E2E-02 | tests, doc-sync, audit, generation, host smoke, docs evidence가 모두 fresh 하다 | fresh command outputs, integration smoke logs, audit JSON |
<!-- GENERATED:END task-matrix-task-rows -->

## 2. Decision gates

<!-- GENERATED:BEGIN task-matrix-decision-gates -->
| Gate | Trigger tasks | Pass condition | On fail |
|---|---|---|---|
| DG-01 Final contract | MODEL-01, AUTHOR-01 | authoring contract와 `ScreenSpec` model이 core screens를 explicit하게 담는다 | schema/model부터 다시 닫는다 |
| DG-02 Authoring completeness | AUTHOR-02, VALIDATE-01 | starter-spec path가 deterministic하고 unresolved item은 generation 전에 모두 차단된다 | compile/report/validator를 먼저 고친다 |
| DG-03 Generator parity | GENERATE-01, REVIEW-01 | SwiftUI / Compose / HTML이 같은 의미를 유지하고 preview state review가 가능하다 | platform parity를 닫기 전에는 integration으로 넘어가지 않는다 |
| DG-04 Host integration | INTEGRATE-01, INTEGRATE-02 | generated adapter가 host code에 연결되고 generated file hand-edit가 필요 없다 | packaging/adapter contract를 먼저 수정한다 |
| DG-05 Governance convergence | GOV-01, ASOT-01 | runtime/governance/doc-sync/audit와 annex docs가 같은 source/evidence set을 따른다 | source-of-truth와 audit evidence를 다시 맞춘다 |
| DG-06 Final acceptance | E2E-01, E2E-02, VERIFY-01 | 두 canonical slice와 final verification suite가 모두 fresh pass 한다 | completion claim을 보류하고 남은 workstream을 유지한다 |
<!-- GENERATED:END task-matrix-decision-gates -->

## 3. Task maintenance rules

1. Task ID는 이번 completion program 동안 바꾸지 않는다.
2. status 변경은 task를 renumber 하지 않고 source row에서만 갱신한다.
3. 새 태스크는 markdown 표를 직접 수정하지 말고 `meta/views/governance.fragments.json` source row를 갱신한 뒤 `ds-doc-sync export-fragments` 와 `ds-doc-sync render` 로 반영한다.
4. `MODEL-01`, `AUTHOR-01`, `VALIDATE-01`, `GENERATE-01`, `GOV-01` 은 각각 schema/model, compile/report, validator, generator, governance evidence를 반드시 함께 가리켜야 한다.
5. `E2E-01`, `E2E-02`, `VERIFY-01` 완료 전에는 어떤 row도 “final completion achieved” 의미의 `Done` 으로 간주하지 않는다.
