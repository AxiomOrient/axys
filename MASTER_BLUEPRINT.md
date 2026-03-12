# Master Blueprint

기준일: 2026-03-11

## 1. 최종 결정

이 프로젝트의 핵심 파이프라인은 아래로 고정한다.

```text
screen-doc (markdown)
    -> starter screen-spec
    -> complete screen-spec
    -> validate
    -> generate
    -> review
    -> integrate
    -> ios/swiftui
    -> android/compose
    -> html/preview
```

## 2. 최종 완성 목표

이 저장소는 “가능한 기능을 모두 넣는 시스템”이 아니라,
**핵심기능이 실제로 정확하게 돌아가는 완성형 delivery system** 을 목표로 한다.

완성 기준의 핵심기능은 아래 여섯 가지다.

1. `screen-doc` 에서 starter spec을 만들고 authoritative `ScreenSpec` 으로 완성시키는 authoring path
2. 상태, 액션, 네비게이션, asset, preview state를 명시적으로 담는 `ScreenSpec`
3. unresolved/ambiguous semantics를 generation 전에 차단하는 semantic validation
4. SwiftUI / Compose / HTML이 같은 의미를 유지하는 deterministic generation
5. declared preview state 전체를 보여주는 HTML review path
6. generated adapter만으로 host app에 연결되는 integration path

## 3. 최종 기술 선택

```text
Control plane language : Swift 6
Build tool             : Swift Package Manager
CLI                    : dsctl
Doc sync binary        : ds-doc-sync
MCP server             : ds-mcp
iOS target             : SwiftUI source generation
Android target         : Jetpack Compose source generation
Preview target         : Static HTML
Tests                  : XCTest
Contract format        : JSON + Markdown + contract roots
Token format           : DTCG-style JSON
```

## 4. 왜 이렇게 결정했는가

### 4.1 Swift를 고른 이유
- macOS 기본 환경과 가장 잘 맞는다.
- iOS 출력과 문맥 거리가 짧다.
- control plane과 iOS renderer 설계를 한 언어로 통일할 수 있다.
- MCP 공식 Swift SDK가 존재한다.
- CLI 구현에 Swift Package Manager + ArgumentParser 조합이 자연스럽다.

### 4.2 Rust를 고르지 않은 이유
- 현재 프로젝트의 최대 병목은 실행 속도보다 계약 정밀도와 흐름 단순화다.
- iOS 중심 팀에 추가 toolchain 부담이 생긴다.
- Kotlin/Swift 코드를 모두 문자열 또는 구조화된 emission으로 생성해야 하므로 Rust가 본질적인 단순화를 보장하지 않는다.

### 4.3 HTML preview를 기본 review path로 둔 이유
- Xcode / Android Studio 없이 바로 확인 가능하다.
- static artifact로 남길 수 있다.
- CLI/MCP에서 생성·서빙하기 쉽다.
- review와 host integration 사이의 의미 parity를 가장 빨리 검증할 수 있다.

## 5. source of truth

제품 계약과 운영 계약은 아래 입력 집합으로 닫는다.

```text
1. docs/                  - 정책, 아키텍처, execution contract
2. examples/screen-doc    - 사람의 의도
3. examples/screens       - authoritative ScreenSpec contract
4. examples/tokens        - 시각 값(tokens)
5. examples/catalogs      - 허용 vocabulary
6. examples/configs       - project path / default platform 설정
7. meta/runtime           - CLI/MCP/doc-sync runtime contract
8. meta/governance        - governance / evidence contract
9. meta/views             - planning / traceability / generated-doc source
```

생성물은 모두 disposable이다.

```text
generated code / preview / snapshots / manifests / reports / exported views
```

## 6. 현재 베이스라인

- 저장소는 이미 `dsctl`, `ds-doc-sync`, `ds-mcp` executable target을 가진 SwiftPM package로 동작한다.
- `login`, `product-detail` 예시는 compile / validate / generate / audit baseline을 제공한다.
- `11`, `12`, `20` 의 structured section은 `meta/views/*` source와 doc-sync 경로로 동기화된다.
- 활성 completion ledger는 `docs/11-execution-plan.md`, `docs/12-task-matrix.md`, `docs/20-traceability-matrix.md` 에서 관리하고, `24`, `25` 는 authoritative-source annex로 사용한다.

## 7. 에이전트 운용 원칙

- 에이전트는 ScreenSpec과 upstream contract를 생성하거나 수정한다.
- 생성된 SwiftUI / Compose / HTML 파일을 사람이 직접 수정하지 않는다.
- 수정은 반드시 upstream에서 일어난다.
- `validate -> generate -> review -> integrate` 순서를 강제한다.
- starter spec을 final authoritative spec으로 착각하지 않는다.

## 8. 이 문서 패키지의 사용 목적

이 문서 패키지는 다른 에이전트나 다른 개발자가 아래를 끝까지 수행할 수 있게 만드는 것이 목적이다.

1. 프로젝트 방향과 핵심기능 계약 이해
2. compile / validate / generate / review 흐름 완성
3. CLI / MCP / doc-sync / audit 운영 계약 정렬
4. iOS / Android host integration path 설계
5. traceability와 acceptance evidence 관리
