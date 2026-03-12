# 30. V2 Operating Runbook

## 1. Objective

이 runbook의 목적은 v2 authoring부터 review, adapter sync, native build, acceptance까지
하나의 운영 루프로 닫는 것이다.

## 2. Inputs

- `AppSpec`
- `FlowSpec`
- `ScreenSpec v2`
- `MotionSpec`
- `Review Checklist`
- `Component Registry v2`
- token set
- benchmark refs

## 3. Daily Authoring Loop

1. benchmark refs를 정리한다.
2. app / flow scope를 고정한다.
3. screen contract를 작성한다.
4. motion / review contract를 붙인다.
5. validate를 실행한다.
6. HTML review bundle을 생성한다.
7. 사람이 review checklist로 승인한다.
8. Penpot / Pencil adapter를 sync 한다.
9. SwiftUI / Compose를 생성한다.
10. sample app build / test를 실행한다.
11. acceptance evidence를 남긴다.

## 4. Proposed Command Surface

아래는 v2 target command surface다.

```text
dsctl v2 validate-app
dsctl v2 validate-flow
dsctl v2 validate-screen
dsctl v2 render-html
dsctl v2 sync-penpot
dsctl v2 sync-pencil
dsctl v2 generate-native --platform ios
dsctl v2 generate-native --platform android
dsctl v2 build-sample-apps
dsctl v2 audit
```

이 문서의 명령은 현재 저장소의 구현 surface와 맞춘다.
`dsctl v2 validate-app`, `dsctl v2 validate-flow`, `dsctl v2 validate-screen`, `dsctl v2 render-html`, `dsctl v2 sync-penpot`, `dsctl v2 sync-pencil`, `dsctl v2 generate-native`, `dsctl v2 build-sample-apps`, `dsctl v2 audit` 는 모두 구현됐다.

## 5. HTML Review Gate

HTML gate는 아래를 통과해야 한다.

- declared preview states 전체 노출
- flow shell과 screen shell hierarchy 확인
- CTA emphasis 확인
- token alias usage 확인
- motion intent 확인
- native viability 확인

출력물:

- HTML bundle
- review screenshots
- review approval record

## 6. Penpot / Pencil Sync Gate

adapter gate는 아래를 통과해야 한다.

- source contract에서 export 가능
- adapter payload freshness 유지
- token alias 보존
- frame / component naming deterministic
- adapter drift audit 가능

출력물:

- Penpot sync payload
- Pencil sync payload
- adapter evidence

## 7. Native Generation Gate

native gate는 아래를 통과해야 한다.

- SwiftUI source generation 성공
- Compose source generation 성공
- screen state/action/navigation binding 명시
- motion token mapping 명시
- unsupported registry item 없음

출력물:

- generated SwiftUI
- generated Compose
- native manifest

## 8. Sample App Build Gate

v2.4에서 sample app build를 source-owned runtime smoke verification으로 승격한다.

### iOS
- generated Swift sample host executable build
- runtime smoke execution with deterministic `runtime-smoke:ok:<screenId>` marker
- route entry wrapper smoke

### Android
- generated Kotlin sample host jar build
- runtime smoke execution with deterministic `runtime-smoke:ok:<screenId>` marker
- route entry wrapper smoke

## 9. Acceptance Gate

acceptance는 아래 evidence를 모두 가져야 한다.

- HTML review evidence
- adapter sync evidence
- iOS sample app build evidence
- Android sample app build evidence
- audit report

## 10. Incident Recovery

### registry drift
- registry item freeze
- affected screens identify
- HTML regenerate
- native regenerate

### adapter drift
- Penpot / Pencil sync disable
- HTML review path 우선 유지
- adapter schema patch 후 재동기화

### native build failure
- failing platform freeze
- web review artifact 유지
- mapping layer 수정

## 11. Ownership

- authoring contracts: product / design system / agent
- registry: design system team
- HTML review approval: design + product
- native mapping: platform engineers
- audit / governance: control-plane owner

## 12. Definition of Done

한 flow의 완료는 아래 조건이 모두 참일 때다.

1. flow graph valid
2. screen contracts valid
3. HTML review approved
4. Penpot / Pencil sync pass
5. SwiftUI / Compose generation pass
6. iOS / Android sample app build pass
7. acceptance evidence archived
