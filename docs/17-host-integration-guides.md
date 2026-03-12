# 17. Host Integration Guides

## 1. iOS host app integration

### 권장 구조
```text
apps/ios/
  App/
  DesignSystem/
  GeneratedUI/
  SnapshotTests/
  UITests/
```

### 통합 규칙
- `GeneratedUI`는 generated source만 가진다.
- `DesignSystem`은 사람이 유지한다.
- generator는 `DesignSystem` symbol을 소비하도록 설계한다.
- generated UI는 app logic을 몰라야 한다.
- generated `State` / `Actions` / `Navigation` surface는 `ScreenSpec.stateFields` / `ScreenSpec.actions` / `ScreenSpec.navigation` 에서 결정된다.
- action과 navigation은 callback / coordinator / view model injection으로 연결한다.

### 최소 연결 방식
1. generated `LoginScreen.swift` 추가
2. generated `LoginScreenState`를 app state에 연결
3. `DesignTokens.swift` 를 host target에 포함하고 native `Color` / `CGFloat` token으로 사용
4. `LoginScreenActions`를 app action에 연결
5. 필요한 screen이면 generated `...Navigation` surface를 router/coordinator에 연결
6. compile-backed host smoke를 추가

이 저장소의 최소 smoke pack은 `integration/ios/LoginHostScreen.swift`,
`integration/ios/ProductDetailHostScreen.swift` 에 있다.
source-owned evidence snapshot은 `audit/evidence/integration/ios-host-smoke.json` 에 기록한다.
테스트는 fresh generated SwiftUI에서 host-facing adapter surface를 추린 뒤
이 wrapper와 함께 `swiftc -typecheck` 해서 generated adapter가 host-owned
code에서 바로 소비되는지 확인한다.
이 evidence 파일은 최소한 `artifactId`, `artifactType`, `platform`, `status`,
`requiredCapability`, `doctorEvidence`, `wrapperSources`, `verification`, `notes` 를 가져야 한다.
preflight로 `dsctl doctor --json` 의 `ios_host_smoke` 가 `true` 인지 먼저 본다.

## 2. Android host app integration

### 권장 구조
```text
apps/android/
  app/
  designsystem/
  generatedui/
  host-smoke/
  ui-tests/
```

### 통합 규칙
- generatedui는 generated compose만 가진다.
- designsystem은 사람이 유지한다.
- action과 navigation binding은 lambda / interface / viewmodel injection으로 처리한다.
- generated `State`는 viewmodel 또는 screen state holder와 연결한다.
- generated `State` / `Actions` / `Navigation` surface는 `ScreenSpec.stateFields` / `ScreenSpec.actions` / `ScreenSpec.navigation` 에서 결정된다.
- generated `DesignTokens.kt` 는 native `Color` / `Dp` token을 제공하므로 host theme bridge에서 직접 소비할 수 있다.
- generated files는 app module에 직접 섞지 않는다.

이 저장소의 최소 smoke pack은 `integration/android/LoginHostScreen.kt`,
`integration/android/ProductDetailHostScreen.kt` 에 있다.
현재 repository test는 fresh generated Compose 화면을 host-facing surface로 distill한 뒤
wrapper와 함께 `kotlinc` 로 compile-backed smoke를 수행한다.
즉 `State` / `Actions` / `Navigation` surface가 host-owned code에서 실제로 compile되는지를 source-owned evidence로 남긴다.
source-owned evidence snapshot은 `audit/evidence/integration/android-host-smoke.json` 에 기록한다.
preflight로 `dsctl doctor --json` 의 `android_host_smoke` 와 `toolchains` 를 본다.
`android_renderer=true` 는 Compose source generation 가능 여부일 뿐이고,
compile-backed smoke readiness는 `android_host_smoke` 로 따로 판단한다.
integration evidence는 `doctorEvidence` 로 `audit/evidence/runtime/doctor.json` snapshot을 참조한다.

## 3. Preview integration

preview는 human review artifact다.
배포 앱의 runtime과 동일할 필요는 없지만 semantic 구조는 같아야 한다.

## 4. Optional Visual Regression Strategy

### iOS
- 대표 screen 1: login
- 대표 screen 2: product-detail
- light / dark
- dynamic type optional

### Android
- 대표 screen 1: login
- 대표 screen 2: product-detail
- phone width baseline
- tablet width optional
