# ADR-0002: PreviewApp evidence automation은 agent-browser를 우선 채택한다

상태: Proposed  
날짜: 2026-03-12

## 결정

PreviewApp evidence automation의 1차 구현은 Playwright 직접 API가 아니라 `agent-browser`를 우선 채택한다.

단, 다음 경계를 고정한다.

- `agent-browser`는 evidence driver다.
- `agent-browser`는 renderer가 아니다.
- CI 기본 모드는 daemon mode다.
- `--native`는 canary/experimental 용도다.
- axys 내부에는 `BrowserEvidenceDriver` 추상화를 둔다.

## 배경

현재 저장소는 Swift 기반 `HTMLRenderer`를 이미 가지고 있다. 따라서 지금 당장 별도 브라우저 렌더링 스택을 추가하는 것보다, 기존 renderer 위에 evidence driver를 얹는 것이 change surface가 작다.

## 결과

좋은 점:

- HTML evidence 자동화가 agent 친화적으로 정리된다.
- session, snapshot, screenshot, recording, tracing, media emulation을 재사용할 수 있다.
- PreviewApp shell을 deterministic evidence run으로 검증하기 쉽다.

나쁜 점:

- 추가 CLI/runtime 의존성이 생긴다.
- security controls가 opt-in이라 repo 정책을 명시해야 한다.
- baseline diff나 artifact bundling 일부는 axys가 직접 소유해야 한다.

## 실행

1. `BrowserEvidenceDriver` 프로토콜을 추가한다.
2. `AgentBrowserDriver` 구현을 추가한다.
3. `PreviewApp/evidence/scripts/`를 만든다.
4. 보안 정책/config를 repo에 명시한다.
5. CI 기본 모드는 daemon mode, native mode는 canary only로 유지한다.
