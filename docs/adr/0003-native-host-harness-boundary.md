# ADR-0003: native proof는 HostApps 경계에서 검증한다

상태: Proposed  
날짜: 2026-03-12

## 결정

axys의 native proof는 generated source 자체만으로 끝나지 않는다. 최종 검증 경계는 `HostApps/ios`, `HostApps/android`에서 정의한다.

현재 sample/native smoke는 유지하되 이름을 명확히 구분한다.

- Level 0: generated-source smoke
- Level 1: host harness build
- Level 2: runtime flow smoke
- Level 3: proof bundle

## 배경

현재 저장소에는 native generation과 sample build 경로가 존재하지만, 이것만으로는 실제 host app runtime/integration proof라고 보기 어렵다. HTML canonical review와 native runtime proof의 경계를 분리해야 한다.

## 결과

좋은 점:

- compile smoke와 runtime proof를 혼동하지 않게 된다.
- generated output이 disposable artifact라는 원칙이 유지된다.
- iOS/Android integration 오류를 더 일찍 포착할 수 있다.

나쁜 점:

- HostApps 유지비가 추가된다.
- CI 시간이 증가한다.

## 실행

1. `HostApps/ios` 골격을 추가한다.
2. `HostApps/android` 골격을 추가한다.
3. generated source mount 규약을 문서화한다.
4. 최소 flow smoke 1개씩 구현한다.
5. proof bundle에 native proof 결과를 포함한다.
