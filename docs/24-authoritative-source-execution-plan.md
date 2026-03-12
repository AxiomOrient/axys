# 24. Authoritative Source Completion Plan

## 1. Status

이 문서는 `11-execution-plan.md` 에 종속된 active workstream annex다.
전체 우선순위와 completion gate는 `11/12/20` 이 소유하고, 이 문서는 authoritative-source 축의 세부 실행 경로를 정의한다.

## 2. Workstream objective

목표는 간단하다.
최종 핵심기능에서 필요한 모든 계약과 증거가 **source-owned artifact** 로 존재하게 만드는 것이다.

즉, 아래 네 가지를 prose가 아니라 source로 닫는다.

1. authoring contract
2. runtime command/evidence contract
3. governance inventory/evidence contract
4. planning/task/traceability ledger

## 3. Observable done condition

1. authoring contract roots가 상태, 액션, 네비게이션, asset, preview state semantics를 명시적으로 가진다.
2. runtime root가 final core workflow에 필요한 command/evidence/output contract를 모두 가진다.
3. governance root가 generated docs, annex docs, acceptance artifacts, evidence refs를 모두 가진다.
4. `11`, `12`, `20`, `23` 의 generated section과 annex docs가 같은 source/evidence set을 본다.
5. audit와 doc-sync가 새 contract/evidence set을 자동으로 검증한다.
6. `login`, `product-detail` acceptance evidence가 governance path에서 추적 가능하다.

## 4. Phases

<!-- GENERATED:BEGIN authoritative-source-execution-plan-phases -->
| Phase | Status | Objective | Depends On | Exit evidence |
|---|---|---|---|---|
| A0 | Done | baseline authoritative roots와 final target 간 gap을 동결한다 | none | source inventory와 gap list가 `11/12/20/23/24/25`에 반영된다 |
| A1 | Done | authoring contract roots를 final core semantics에 맞게 확장한다 | A0 | schema/docs/examples가 state/action/navigation/asset/preview contract를 명시한다 |
| A2 | Done | runtime/governance roots를 expanded evidence/output contract로 확장한다 | A1 | exported contract views와 audit checks가 새 fields/evidence key를 가진다 |
| A3 | Done | planning fragments, generated docs, annex docs를 같은 source 체계로 정렬한다 | A2 | `11`, `12`, `20`, `23`, `24`, `25` 가 같은 terms/task/evidence를 사용한다 |
| A4 | Done | host integration evidence를 source-owned artifact로 편입한다 | A2 | iOS/Android integration smoke evidence가 governance inventory에 등록되고 compile-backed smoke로 검증된다 |
| A5 | Done | canonical slice acceptance evidence를 freeze 한다 | A3, A4 | `login`, `product-detail` acceptance artifact가 traceability와 audit에 연결되고 pass 상태로 유지된다 |
<!-- GENERATED:END authoritative-source-execution-plan-phases -->

## 5. Coordination rules

- schema/model 작업은 `MODEL-01` 과 동기화한다.
- compile/report 작업은 `AUTHOR-01`, `AUTHOR-02` 와 동기화한다.
- audit/doc-sync/evidence 작업은 `GOV-01` 과 동기화한다.
- annex task는 `12` 의 master task를 복제하지 않고, source/evidence 전용 세부 단위만 가진다.

## 6. Current residual

- planning package reread evidence는 `audit/evidence/planning/reread-checklist.json` 에 source-owned artifact로 남긴다.
- 현재 checked-in baseline은 `audit/evidence/runtime/doctor.json` 기준 `android_host_smoke=true` 를 만족하고, Android compile-backed host smoke evidence도 `pass` 상태로 고정돼 있다.
- host integration evidence와 canonical acceptance evidence는 모두 source-owned artifact로 등록되어 있고 현재 `pass` 상태다.

## 7. Final rule

authoritative-source workstream은 문서를 더 예쁘게 만드는 작업이 아니다.
최종 completion claim이 source와 evidence로 재현 가능하도록 만드는 작업이다.
