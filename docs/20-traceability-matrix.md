# 20. Traceability Matrix

이 표는 요구사항이 어느 계약 문서, 예시, 실행 태스크, 검증 증거에 연결되는지 보여준다.
Task ID는 [12-task-matrix.md](12-task-matrix.md)를 기준으로 유지한다.
overall execution authority는 `11/12/20` 이고, `24/25` 는 authoritative-source workstream annex로 참조된다.
structured row source는 `meta/views/governance.fragments.json` 이고, 이 문서는 generated traceability view다.

<!-- GENERATED:BEGIN traceability-matrix-rows -->
| Requirement ID | Contract | Docs | Schema / Example | Primary Tasks | Verification Evidence |
|---|---|---|---|---|---|
| `REQ-01` | `ScreenSpec` 는 supported core screen을 explicit하게 표현하는 authoritative contract여야 한다. | `03`, `06`, `11`, `23` | `schemas/screen-spec.schema.json`, `examples/screens/*.screen.json` | `MODEL-01`, `DOC-01`, `VALIDATE-01` | schema diff, model tests, validation reports |
| `REQ-02` | `screen-doc` 는 사람의 intent source이고 `compile-screen-doc` 는 starter spec + completion report를 생성해야 한다. | `03`, `11`, `18` | `examples/screen-doc/*.md`, compile report shape | `AUTHOR-01`, `AUTHOR-02`, `E2E-01`, `E2E-02` | compile tests, starter-spec snapshots, completion reports |
| `REQ-03` | generation 전에 unresolved/ambiguous semantics를 반드시 차단해야 한다. | `11`, `13`, `20` | validation fixtures, enriched spec examples | `VALIDATE-01`, `VERIFY-01` | negative fixtures, validation JSON, smoke checks |
| `REQ-04` | SwiftUI / Compose / HTML은 상태, 액션, 네비게이션, media semantics를 같은 의미로 유지해야 한다. | `08`, `11`, `17` | enriched ScreenSpec examples | `GENERATE-01`, `REVIEW-01`, `INTEGRATE-01`, `INTEGRATE-02` | golden tests, generated artifacts, parity review |
| `REQ-05` | HTML preview는 declared preview state 전체의 canonical review surface여야 한다. | `09`, `11`, `18` | preview-enabled example specs | `REVIEW-01`, `E2E-01`, `E2E-02` | preview bundle, review checklist, acceptance report |
| `REQ-06` | generated file은 disposable이고 host logic은 generated adapter를 통해 연결되어야 한다. | `10`, `17`, `23` | generated adapter contract, host package layout | `INTEGRATE-01`, `INTEGRATE-02`, `VERIFY-01` | host compile logs, compile-backed smoke tests, guide reread |
| `REQ-07` | runtime/governance/doc-sync/audit는 확장된 contract와 evidence set의 authoritative source여야 한다. | `11`, `21`, `23`, `24`, `25` | `meta/runtime/contracts.cue`, `meta/governance/contracts.cue`, `meta/views/*.json` | `GOV-01`, `ASOT-01`, `VERIFY-01` | contract export verify, audit JSON, fragment freshness |
| `REQ-08` | `login` slice는 최종 form-flow completion을 증명해야 한다. | `11`, `18`, `22` | `examples/screen-doc/login.md`, `examples/screens/login.screen.json` | `E2E-01`, `VERIFY-01` | login acceptance report, generated artifacts, host smoke |
| `REQ-09` | `product-detail` slice는 최종 content/action completion을 증명해야 한다. | `11`, `18`, `22` | `examples/screen-doc/product-detail.md`, `examples/screens/product-detail.screen.json` | `E2E-02`, `VERIFY-01` | product-detail acceptance report, generated artifacts, host smoke |
| `REQ-10` | docs / schema / examples / prompts / audit artifact는 contract 변화와 함께 움직여야 한다. | `11`, `12`, `20`, `21`, `22`, `24`, `25` | 전체 문서 패키지, schemas, examples | `DOC-01`, `GOV-01`, `VERIFY-01` | integrity audit, doc-sync verify, updated artifacts, link scan |
| `REQ-11` | canonical execution plan은 하나여야 하며 workstream annex는 그 계획에 종속되어야 한다. | `11`, `12`, `18`, `20`, `24`, `25` | `meta/views/governance.fragments.json`, annex docs | `PLAN-01`, `ASOT-01` | rendered docs, reread checklist, link scan |
| `REQ-12` | final completion은 fresh end-to-end evidence로만 주장할 수 있어야 한다. | `11`, `12`, `21`, `22` | acceptance specs, audit artifacts | `VERIFY-01`, `E2E-01`, `E2E-02` | tests, audit JSON, doc-sync sync, host smoke logs |
<!-- GENERATED:END traceability-matrix-rows -->

## 사용법

contract나 completion plan이 바뀌면 아래를 반드시 업데이트한다.

1. `meta/views/governance.fragments.json` 의 relevant source row
2. 관련 task source row와 status
3. 관련 docs, schemas, examples, annex docs, verification evidence
4. `ds-doc-sync sync` 결과
5. `ALL_DOCS_COMBINED.md` 와 `audit/integrity-report.json` 갱신 여부
