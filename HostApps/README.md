# HostApps

HostApps는 generated SwiftUI / Compose output을 실제 호스트 앱 경계에서 검증하기 위한 디렉토리다. generated source는 disposable artifact고, HostApps는 최종 runtime proof boundary다.

```text
HostApps/
  ios/
  android/
```

## 원칙

1. HostApps는 generated source를 source of truth로 보지 않는다.
2. generated source는 mount/inject 되는 disposable artifact다.
3. HostApps는 runtime proof 경계다.
4. compile smoke와 runtime proof를 구분한다.

## 검증 레벨

- Level 0: generated-source smoke
- Level 1: host harness build
- Level 2: runtime flow smoke
- Level 3: proof bundle

## 현재 상태

HostApps는 generated-source smoke와 별개로 실제 native runtime proof를 수행하는 경계다. 이 디렉토리 아래의 호스트 앱과 스크립트만이 runtime proof 기준이 된다.
