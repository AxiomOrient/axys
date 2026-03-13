# Implementation Plan

기준일: 2026-03-13

## 계획 목표

`contracts/*` 와 `schemas/current/*` 를 authoritative input으로 유지하면서, 다음 3개 작업을 실행 가능한 저장소 경계로 완성한다.

1. `PreviewApp` review shell 완성
2. browser evidence driver 추가
3. `HostApps` runtime proof 강화

이 계획은 구현 자체가 아니라 실행 순서, 결정 게이트, 검증 경로를 고정하기 위한 문서다. 실행용 태스크 레저는 [plans/TASKS.md](/Users/axient/repository/axys/plans/TASKS.md)를 따른다.

## 범위

- `PreviewApp/*`
- `HostApps/*`
- `Sources/DSCore/*`
- `Sources/DSCLI/*`
- `Sources/DSMCP*/*`
- `Tests/*`
- 필요 시 관련 `contracts/review/*`

## 비범위

- generated HTML, generated native source, adapter payload hand edit
- 새 authoritative root 추가
- Penpot/Pencil authoring 확장
- 호스트 proof와 무관한 cosmetic cleanup

## 완료 조건

| 조건 | 관측 가능한 증거 |
| --- | --- |
| Preview review shell이 저장소 안에 구조적으로 존재한다 | `PreviewApp/shell/*` 및 연결 문서/스크립트 |
| browser evidence가 renderer와 분리된 driver 경계로 동작한다 | evidence driver 래퍼/스크립트와 실행 절차 |
| HostApps proof가 compile smoke를 넘는 런타임 proof 단계로 정의된다 | iOS/Android harness 구조, mount 규칙, 실행 단계 |
| 실행 태스크가 모두 완료된다 | [plans/TASKS.md](/Users/axient/repository/axys/plans/TASKS.md)의 모든 상태가 `done` |
| 저장소 기본 게이트가 통과한다 | `swift test`, `swift run dsctl audit --project-root . --json` |

## 현재 기준 사실

- `PreviewApp`은 현재 README와 evidence script만 있고 shell 구현 자산은 아직 없다.
- `PreviewApp/evidence/scripts/run-preview-evidence.sh`는 `agent-browser` 호출을 직접 수행하지만 driver 추상화는 아직 없다.
- `HostApps/ios`, `HostApps/android`는 README 경계만 있고 harness/runner 구조는 아직 구체 구현이 보이지 않는다.
- `Sources/DSCore/ProjectService.swift`가 CLI/MCP 공용 orchestration 경계다.

## 크리티컬 패스

`P1-01 Preview shell 구조` → `P1-02 rendered HTML 연결 계약` → `P1-03 review affordance 배치` → `P1-04 shell smoke 경로` → `P2-01 driver 경계 정리` → `P2-02 agent-browser driver 래퍼` → `P2-04 shell 기준 evidence smoke` → `P3-01/P3-02 HostApps harness 구체화` → `P3-03 runtime proof 단계 정리` → `P3-04 DSCLI 결과와 HostApps proof 연결` → `X-01 문서 동기화` → `X-02 swift test` → `X-03 audit`

이 순서를 쓰는 이유:
- evidence는 shell 기준 URL/DOM이 먼저 안정돼야 한다.
- Host proof는 review/evidence 경계가 정리된 뒤에야 역할 중복 없이 닫을 수 있다.
- 전체 테스트와 audit은 구현이 모인 뒤 최종 게이트로 두는 편이 피드백 대비 비용이 맞다.

## 단계별 실행 전략

### Phase 1. PreviewApp Review Shell

목표:
`dsctl render-html` 결과를 canonical review surface로 소비하는 shell 자산과 연결 규칙을 저장소 안에 명시한다.

핵심 결정:
- shell은 source of truth가 아니라 review layer다.
- rendered HTML 자체를 대체하지 않고 감싸거나 로드하는 쪽으로 유지한다.
- review affordance는 authoring 기능이 아니라 inspection/verification 기능만 가진다.

예상 산출물:
- `PreviewApp/shell/layout.html`
- `PreviewApp/shell/review.css`
- `PreviewApp/shell/review.js`
- shell 실행 또는 smoke 확인 절차 문서/스크립트

검증:
1. 정적 자산 참조가 깨지지 않는다.
2. rendered HTML를 shell이 읽거나 감싼다.
3. shell 진입점을 evidence 경로가 재사용한다.

### Phase 2. Browser Evidence Driver

목표:
evidence 수집을 renderer에서 분리된 실행 계층으로 두고, `agent-browser`를 기본 드라이버로 정렬한다.

핵심 결정:
- renderer는 HTML bundle 생성까지만 책임진다.
- evidence driver는 URL open, snapshot, screenshot 수집만 책임진다.
- baselines와 outputs는 운영 규칙이 분리되어야 한다.

예상 산출물:
- evidence driver 스크립트 또는 래퍼
- baselines/output 디렉토리 운영 규칙
- shell 기준 evidence smoke 절차

검증:
1. 인자 전달이 안정적이다.
2. shell URL에서 스냅샷/스크린샷이 생성된다.
3. README/Runbook 설명과 실제 실행 경로가 일치한다.

### Phase 3. HostApps Runtime Proof

목표:
generated source smoke와 별개로 실제 host harness 기반 runtime proof 경계를 iOS/Android에 만든다.

핵심 결정:
- generated source는 disposable mount input이다.
- HostApps는 최종 runtime proof boundary다.
- compile smoke, harness build, runtime flow smoke, proof bundle을 구분한다.

예상 산출물:
- `HostApps/ios` harness 구조
- `HostApps/android` harness 구조
- generated mount/inject 규칙
- 단계별 실행 절차 또는 스크립트

검증:
1. generated mount 위치가 명확하다.
2. platform별 build/run smoke 경로가 있다.
3. `build-sample-apps` 또는 동등한 경로가 HostApps proof와 연결된다.

## 의사결정 게이트

| 게이트 | 확인 내용 | 통과 조건 | 실패 시 |
| --- | --- | --- | --- |
| G1-shell-boundary | Preview shell이 review layer로 남아 있는가 | shell이 authoring 기능 없이 rendered HTML 소비 경계로 정의된다 | shell 범위를 줄이고 review-only 기능만 남긴다 |
| G2-shell-smoke | shell이 실제 render 결과 위에 얹히는가 | shell smoke에서 자산 로드와 HTML 연결이 확인된다 | P1 단계에서 경로/계약부터 다시 고정한다 |
| G3-driver-separation | evidence가 renderer와 분리됐는가 | driver 래퍼 또는 인터페이스가 별도 책임으로 존재한다 | `run-preview-evidence.sh` 직접 호출 구조를 재설계한다 |
| G4-driver-smoke | evidence 실행이 재현 가능한가 | session/url/out 인자로 snapshot/screenshot이 남는다 | driver 인자 계약과 실행 순서를 조정한다 |
| G5-host-proof-shape | HostApps proof 단계가 compile smoke와 구분되는가 | iOS/Android 문서 또는 스크립트에 단계 구분이 있다 | HostApps 단계 정의를 먼저 보강한다 |
| G6-final-quality | 저장소 기본 품질 게이트가 통과하는가 | `swift test` 및 `audit` 성공 | 실패 지점을 blocker로 남기고 수정 후 재실행한다 |

## 검증 순서

### 가장 좁은 검증

1. shell 정적 자산 존재 및 로드 확인
2. evidence driver 인자 계약 확인
3. HostApps mount 지점/단계 정의 확인

### 중간 검증

1. `dsctl render-html` 결과와 shell 연결 확인
2. shell URL 기준 evidence smoke
3. platform별 host harness build/run smoke

### 최종 검증

1. 문서 동기화
2. `swift test`
3. `swift run dsctl audit --project-root . --json`

## 태스크 매핑

| TASK ID | 목적 | 결과물 | 선행 조건 |
| --- | --- | --- | --- |
| P1-01 | shell 구조 생성 | `PreviewApp/shell/*` 골격 | 없음 |
| P1-02 | rendered HTML 연결 계약 고정 | shell-HTML 연결 방식 | P1-01 |
| P1-03 | review affordance 최소 배치 | checklist/inspector/motion 토글 진입점 | P1-01, P1-02 |
| P1-04 | shell smoke 경로 마련 | 확인 절차 또는 스크립트 | P1-02, P1-03 |
| P2-01 | driver 경계 정의 | renderer/evidence 책임 분리 | P1-02 |
| P2-02 | driver 래퍼 구현 준비 | `agent-browser` 실행 계층 | P2-01 |
| P2-03 | evidence 운영 규칙 고정 | baseline/output 규칙 | P2-02 |
| P2-04 | evidence smoke 절차 | shell 기준 실행 가능 경로 | P1-04, P2-02 |
| P3-01 | iOS host proof 구조화 | iOS harness/mount 규칙 | 없음 |
| P3-02 | Android host proof 구조화 | Android harness/mount 규칙 | 없음 |
| P3-03 | proof 단계 구분 | build/run/proof 절차 | P3-01, P3-02 |
| P3-04 | DSCLI-HostApps 연결 | sample build와 host proof 연결 규칙 | P3-03 |
| X-01 | 문서 동기화 | README/RUNBOOK/plans 정합성 | P1-04, P2-04, P3-04 |
| X-02 | 테스트 게이트 | `swift test` 성공 | 구현 태스크 완료 |
| X-03 | 감사 게이트 | `audit` 성공 | X-02 |

## 계획 가정

- Phase 1, 2, 3은 같은 미션 안에 포함되지만 실행은 순차적이다.
- shell, evidence, host proof는 모두 source-owned 보조 경계이며 authoritative contracts를 대체하지 않는다.
- 최종 완료 전에는 generated output을 근거로 hand patch 하지 않는다.

## 열린 가장자리

- `PreviewApp/shell`이 어떤 방식으로 rendered HTML를 포함할지 구현 방식은 아직 열려 있다.
- `HostApps`의 실제 harness 기술 선택은 현재 저장소 안의 미구현 정도에 따라 달라질 수 있다.
- `build-sample-apps`와 HostApps proof 연결 방식은 구현 시점에 코드 구조를 보고 가장 작은 경로로 결정해야 한다.

이 열린 가장자리는 실행 중 구체화하되, task id와 phase 순서는 유지한다.
