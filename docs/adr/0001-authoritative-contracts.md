# ADR-0001: axys의 authoritative source는 contracts다

상태: Proposed  
날짜: 2026-03-12

## 결정

axys의 authoritative source는 다음으로 정의한다.

- `contracts/apps/**`
- `contracts/flows/**`
- `contracts/screens/**`
- `contracts/motion/**`
- `contracts/review/**`
- `contracts/registry/**`
- `contracts/tokens/**`
- `schemas/current/**`

`build/ir/**`는 machine-authoritative compiled intermediate다.

다음은 authoritative source가 아니다.

- PreviewApp generated bundle
- generated SwiftUI / Compose source
- Penpot/Pencil export
- evidence screenshots/videos/traces
- sample apps generated output

## 배경

실제 저장소에는 이미 `schemas/current`, `contracts`, current validator/renderer 구현, `dsctl ...`가 존재한다. 저장소는 사실상 current implementation을 이미 가진 상태지만, 기존 문서는 아직 machine-spec 중심 서사를 유지했다.

## 결과

좋은 점:

- source of truth가 선명해진다.
- Preview/native/adapters가 모두 derived라는 점이 명확해진다.
- legacy/renewal 혼선을 줄인다.

나쁜 점:

- 기존 문서와 예제 경로를 이동하거나 강등해야 한다.
- 복수 contract root를 동시에 두면 validator의 parent resolution이 중복 문서를 보게 될 수 있다.

## 실행

1. `contracts/*`를 단일 contract root로 고정한다.
2. `README`와 `MASTER_BLUEPRINT`를 renewal 기준으로 개정한다.
3. legacy planning docs는 historical 표기로 강등한다.
4. legacy authoring fixture는 제거하거나 historical evidence로만 보관한다.
