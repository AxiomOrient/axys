# Unified Execution Plan And Task Ledger

상위 계획 문서: [plans/IMPLEMENTATION-PLAN.md](/Users/axient/repository/axys/plans/IMPLEMENTATION-PLAN.md)

기준일: 2026-03-13

이 문서는 현재 `docs/PLAN.md`에 남아 있는 다음 3개 우선순위를 한 번에 실행하기 위한 단일 계획/태스크 문서다.

1. `PreviewApp` review shell 완성
2. browser evidence driver 추가
3. `HostApps` runtime proof 강화

## 미션

`contracts/*` 와 `schemas/current/*` 를 입력 기준으로 유지한 채, HTML review shell, browser evidence, native host proof 경계를 실제 실행 가능한 수준으로 닫는다.

## 대상 범위

- `PreviewApp/*`
- `HostApps/*`
- `Sources/DSCore/*`
- `Sources/DSCLI/*`
- `Sources/DSMCP*/*`
- `Tests/*`
- 필요 시 관련 `contracts/review/*`

## 비범위

- generated HTML/native/adapters 산출물 hand edit
- `contracts/*` 바깥의 새 authoritative root 추가
- Penpot/Pencil authoring round-trip 확장
- Host proof와 무관한 샘플 앱 미관 작업

## 전체 완료 조건

| 조건 | 필요 증거 |
| --- | --- |
| Phase 1, 2, 3의 모든 태스크가 `done` 이다 | 아래 task ledger 상태와 산출 경로 |
| review shell이 HTML review 결과 위에 명확히 얹힌다 | Preview shell 파일, 실행 경로, smoke evidence |
| browser evidence 경로가 renderer와 분리된 driver로 동작한다 | driver 구현, 실행 스크립트, evidence output 확인 |
| iOS/Android host proof 경계가 compile smoke 이상으로 정의되고 실행 가능하다 | HostApps harness/runner/readme/test evidence |
| 저장소 기본 품질 게이트가 통과한다 | `swift test`, `swift run dsctl audit --project-root . --json` |

## 단계별 실행 계획

### Phase 1. PreviewApp Review Shell

목표:
`dsctl render-html` 산출물 위에서 동작하는 review shell 구조를 고정하고, review에 필요한 최소 UI/스크립트 자산을 저장소 경계 안에 배치한다.

핵심 산출물:
- `PreviewApp/shell/*` 기본 구조
- shell에서 읽는 review UI 자산
- renderer 출력과 shell 연결 규칙 문서화
- shell smoke 검증 경로

검증 순서:
1. 가장 좁은 확인: shell 정적 자산과 연결 경로가 로컬 fixture/rendered HTML에서 깨지지 않는다.
2. 중간 확인: `dsctl render-html` 결과를 shell이 감싼다.
3. 넓은 확인: Preview evidence 경로가 shell 기준 URL을 사용한다.

### Phase 2. Browser Evidence Driver

목표:
browser evidence 수집을 renderer와 분리된 driver 계층으로 고정하고, 기본 경로를 `agent-browser` 중심으로 정리한다.

핵심 산출물:
- evidence driver 책임 분리
- browser 세션 실행 스크립트 또는 래퍼
- baseline/output 구조 정리
- headless evidence smoke 검증

검증 순서:
1. 가장 좁은 확인: driver 호출이 지정 URL과 session/output 인자를 안정적으로 전달한다.
2. 중간 확인: shell URL 기준 snapshot/screenshot이 생성된다.
3. 넓은 확인: README/Runbook 수준에서 evidence 실행 경로가 일관된다.

### Phase 3. HostApps Runtime Proof

목표:
generated source smoke와 구분되는 host harness 기반 runtime proof 경계를 iOS/Android 양쪽에 정의하고 최소 실행 경로를 확보한다.

핵심 산출물:
- iOS host proof 구조
- Android host proof 구조
- generated UI mount/inject 규칙
- runtime proof 단계별 스크립트 또는 문서

검증 순서:
1. 가장 좁은 확인: host harness가 generated output mount 위치를 명확히 가진다.
2. 중간 확인: 플랫폼별 build/run smoke가 실행 가능하다.
3. 넓은 확인: sample app build 또는 host proof 문서/스크립트가 저장소 기본 루프와 맞물린다.

## Task Ledger

| ID | Phase | 작업 | 상태 | 완료 기준 | 선행 조건 |
| --- | --- | --- | --- | --- | --- |
| P1-01 | PreviewApp | `PreviewApp/shell/` 디렉토리와 기본 layout/css/js 자산 구조를 만든다 | done | shell 파일 구조와 각 파일 책임이 존재한다 | 없음 |
| P1-02 | PreviewApp | rendered HTML 결과를 shell이 감싸는 연결 방식과 입력/출력 계약을 정의한다 | done | shell이 어떤 HTML 산출물을 어떻게 읽는지 문서 또는 코드로 확인된다 | P1-01 |
| P1-03 | PreviewApp | review checklist, token inspector, reduced-motion 같은 최소 review affordance를 shell 범위 안에 배치한다 | done | shell UI에 review용 패널/토글 진입점이 존재한다 | P1-01, P1-02 |
| P1-04 | PreviewApp | Preview shell smoke 경로를 문서화하거나 스크립트화한다 | done | 로컬에서 shell 확인 절차가 재현 가능하다 | P1-02, P1-03 |
| P2-01 | Evidence | 현재 `run-preview-evidence.sh`를 기준으로 driver 책임을 분리할 target 인터페이스를 정리한다 | done | renderer와 evidence driver의 경계가 코드/문서에 드러난다 | P1-02 |
| P2-02 | Evidence | `agent-browser` 기반 driver 래퍼 또는 스크립트 계층을 추가한다 | done | session, URL, output 인자를 받아 snapshot/screenshot을 안정적으로 실행한다 | P2-01 |
| P2-03 | Evidence | `PreviewApp/evidence/baselines` 와 `PreviewApp/evidence/output` 운영 규칙을 정리한다 | done | baseline/output 구분과 보관 규칙이 명시된다 | P2-02 |
| P2-04 | Evidence | shell URL 기준 evidence smoke 검증 절차를 추가한다 | done | shell을 띄운 뒤 evidence를 남기는 재현 가능한 절차가 있다 | P1-04, P2-02 |
| P3-01 | HostApps | `HostApps/ios` runtime proof에 필요한 harness 구조와 generated mount 지점을 구체화한다 | done | iOS host proof 루트와 mount 규칙이 문서/코드에 반영된다 | 없음 |
| P3-02 | HostApps | `HostApps/android` runtime proof에 필요한 harness 구조와 generated mount 지점을 구체화한다 | done | Android host proof 루트와 mount 규칙이 문서/코드에 반영된다 | 없음 |
| P3-03 | HostApps | 플랫폼별 compile smoke와 runtime proof를 구분한 실행 단계 또는 스크립트를 추가한다 | done | Level 0/1/2 이상의 구분과 실행 경로가 존재한다 | P3-01, P3-02 |
| P3-04 | HostApps | `build-sample-apps` 또는 host proof 경로와 HostApps 경계를 연결하는 검증 절차를 정리한다 | done | DSCLI 결과물이 HostApps proof와 어떻게 이어지는지 확인된다 | P3-03 |
| X-01 | Cross-cutting | 관련 README/RUNBOOK/plan 문서를 현재 구현과 맞춘다 | done | PreviewApp/HostApps/evidence 설명이 실제 구조와 어긋나지 않는다 | P1-04, P2-04, P3-04 |
| X-02 | Cross-cutting | `swift test` 를 통과시킨다 | done | 전체 테스트 통과 로그 또는 성공 결과 | 구현 태스크 완료 |
| X-03 | Cross-cutting | `swift run dsctl audit --project-root . --json` 를 통과시킨다 | done | audit 성공 결과 | X-02 |

## 권장 실행 순서

1. `P1-01` ~ `P1-04`
2. `P2-01` ~ `P2-04`
3. `P3-01` ~ `P3-04`
4. `X-01` ~ `X-03`

이 순서를 권장하는 이유는 Preview shell이 먼저 고정되어야 evidence driver가 안정된 URL/DOM 기준을 가질 수 있고, 그 다음에야 HostApps proof를 review/evidence 경계와 분리해서 닫을 수 있기 때문이다.

## 태스크 수행 규칙

- generated 산출물은 수정하지 않고 upstream contract, shell, proof 코드만 수정한다.
- 각 phase는 가장 좁은 smoke 확인 후 더 넓은 검증으로 확장한다.
- `swift test` 와 `audit` 는 전체 미션 완료 주장 전에 반드시 다시 실행한다.
- Host proof는 generated-source smoke와 동일시하지 않는다.
- evidence driver는 renderer 책임과 섞지 않는다.

## 실행 시작점

첫 번째 작업은 `P1-01 PreviewApp shell 구조 생성` 이다.

## Execution Sync

| TASK ID | 상태 | 증거 |
| --- | --- | --- |
| P1-01 | done | `PreviewApp/shell/layout.html`, `PreviewApp/shell/review.css`, `PreviewApp/shell/review.js` 생성 |
| P1-02 | done | `Sources/DSCore/HTMLRenderer.swift` 에서 root `index.html` shell entrypoint 와 `html/<screen>.html` 연결 구현 |
| P1-03 | done | shell에 checklist, preview states, token inspector, reduced-motion toggle 추가 |
| P1-04 | done | `PreviewApp/evidence/scripts/run-shell-smoke.sh` 추가 |
| P2-01 | done | `PreviewApp/evidence/scripts/run-preview-evidence.sh` 가 driver 래퍼를 호출하도록 분리 |
| P2-02 | done | `PreviewApp/evidence/drivers/agent-browser-driver.sh` 추가 |
| P2-03 | done | `PreviewApp/evidence/README.md`, `PreviewApp/evidence/baselines/README.md`, `PreviewApp/evidence/output/README.md` 추가 |
| P2-04 | done | shell smoke 기준 URL 이 `run-shell-smoke.sh` 와 `run-preview-evidence.sh` 로 재현 가능 |
| P3-01 | done | `HostApps/ios/README.md`, `HostApps/ios/scripts/run-host-proof.sh` 추가 |
| P3-02 | done | `HostApps/android/README.md`, `HostApps/android/scripts/run-host-proof.sh` 추가 |
| P3-03 | done | Host proof Level 0/1/2/3 규칙을 HostApps 문서와 script summary 경로에 반영 |
| P3-04 | done | `Sources/DSCore/ProjectService.swift` 에 `HostProof/proof.manifest.json` 생성 로직 추가 |
| X-01 | done | `README.md`, `docs/RUNBOOK.md`, `PreviewApp/README.md`, `HostApps/README.md` 동기화 |
| X-02 | done | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test` 로 33 tests passed |
| X-03 | done | `./.build/arm64-apple-macosx/debug/dsctl audit --project-root . --json` 결과 `ok: true` |

## Verification Notes

- 기본 `swift` 는 CommandLineTools `6.2.4` 였고 SDK interface 와 불일치했다.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 로 Xcode Swift `6.2.3` 을 선택해 SDK 매칭을 맞췄다.
- sandbox 안에서는 `sandbox-exec: sandbox_apply: Operation not permitted` 로 막혀 외부 실행이 필요했다.
- 외부 실행 시 `HOME=/tmp/axys-home`, `CLANG_MODULE_CACHE_PATH=/tmp/axys-clang-module-cache` 로 cache/write 경로를 우회했다.
