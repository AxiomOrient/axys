# 08. Generation Architecture

## 1. Overall generator design

```text
ScreenSpec
  + TokenStore
  + ComponentCatalog
      ↓
ValidationReport
      ↓
ArtifactGenerator
      ↓
SwiftUI / Compose / HTML / Manifests
```

## 2. Generator responsibilities

### 2.1 iOS generator
- SwiftUI file 생성
- platform-typed `DesignTokens.swift` 생성 또는 연결
- explicit `stateFields` 기반 hoisted state struct 생성
- explicit `actions` 기반 action closure contract 생성
- explicit `navigation` 기반 navigation closure contract 생성
- declared `previewStates` 기반 multi-preview block 생성
- root/card surface를 native `Color`/`CGFloat` token으로 적용

### 2.2 Android generator
- Compose screen file 생성
- platform-typed `DesignTokens.kt` 생성 또는 연결
- explicit `stateFields` 기반 hoisted state data class 생성
- explicit `actions` 기반 action lambda contract 생성
- explicit `navigation` 기반 navigation lambda contract 생성
- declared `previewStates` 기반 `@Preview` 함수 생성
- root/card surface를 native `Color`/`Dp` token으로 적용

### 2.3 HTML generator
- screen html 생성
- preview index 생성
- declared `previewStates` review surface 생성
- navigation button이면 route anchor를 생성
- tokens.css 생성

## 3. Rendering philosophy

generator는 “자유롭게 UI를 창작”하지 않는다.
generator는 contract를 **platform-appropriate primitive tree**로 사상(mapping)한다.

## 4. Mapping policy

generator는 `ScreenSpec.platforms` 에 포함된 플랫폼에 대해서만 artifact를 생성한다.

### 4.1 vstack
- iOS: `VStack`
- Android: `Column`
- HTML: `display:flex; flex-direction:column`

### 4.2 hstack
- iOS: `HStack`
- Android: `Row`
- HTML: `display:flex; flex-direction:row`

### 4.3 text role mapping
- iOS: `.title`, `.body`, `.caption`, caption-weighted label style
- Android: `titleLarge`, `bodyLarge`, `bodySmall`, `labelMedium`
- HTML: role class name 유지

### 4.4 button variants
- iOS: `.borderedProminent`, `.bordered`
- Android: `Button`, `OutlinedButton`
- HTML: `button-primary`, `button-secondary`

### 4.5 fields
- `textField`
  - iOS: `TextField` + `keyboardType` / `textContentType` / autocorrection policy
  - Android: `OutlinedTextField` + `KeyboardOptions`
  - HTML: `<input type="text|email|number">`
- `secureField`
  - iOS: `SecureField` + password content type + no autocorrect
  - Android: `OutlinedTextField` + `PasswordVisualTransformation` + password keyboard
  - HTML: `<input type="password" autocomplete="current-password">`

### 4.6 interaction contract
- iOS: generated `State` + `Actions` + `Navigation` injection
- Android: generated `State` + `Actions` + `Navigation` lambda injection
- generator는 `ScreenSpec.stateFields`, `ScreenSpec.actions`, `ScreenSpec.navigation`, input node `binding`, button node `navigation` 을 먼저 읽는다
- explicit interaction contract가 없을 때만 baseline tree inference를 fallback으로 사용한다

- button이 `action` 을 가지면 generated callback/lambda를 호출한다
- button이 `navigation` 을 가지면 generated navigation adapter를 호출하고, HTML에서는 destination route anchor로 렌더링한다

### 4.7 preview-state review contract
- HTML: declared `previewStates` 를 순서대로 모두 렌더링하고 state id / note를 review surface에 노출한다
- iOS: declared `previewStates` 를 named `#Preview` block으로 노출한다
- Android: declared `previewStates` 를 named `@Preview` function으로 노출한다
- preview state가 field 값을 가지면 generator는 declared `stateFields` default 위에 override해서 preview snapshot을 만든다

### 4.8 surfaces and token typing
- iOS: color token은 `Color(.sRGB, ...)`, dimension token은 `CGFloat`
- Android: color token은 `Color(0xAARRGGBB)`, dimension token은 `Dp`
- HTML: token CSS variable 유지
- root surface는 screen background + outer padding으로 적용
- `card` 는 platform-native container background/shape/padding으로 적용

### 4.9 media primitives
- `image`
  - iOS: `Image("asset")`
  - Android: `Image(painterResource(...))`
  - HTML: `<img class="image" ...>`
- `icon`
  - iOS: `Image(systemName: ...)`
  - Android: `Icon(painterResource(...))`
  - HTML: `<img class="icon" ...>`
- generator와 validator는 media node를 렌더링하기 전에 `ScreenSpec.assets` 에 declared asset이 있는지 먼저 확인한다.

## 5. Token resolution policy

generator는 raw token JSON을 직접 다루지 않고, resolver가 만든 `ResolvedTokenStore`를 사용한다.

필수 기능:
- alias resolution
- cycle detection
- type carry-through
- deterministic ordering

## 6. Artifact layout

```text
build/login/
  manifest.json
  report.validation.json
  ios/              # present only when ios is enabled
    LoginScreen.swift
    DesignTokens.swift
  android/          # present only when android is enabled
    LoginScreen.kt
    DesignTokens.kt
  html/             # present only when html is enabled
    login.html
    index.html
    tokens.css
```

## 7. Manifest content

manifest는 다음을 포함한다.
- input spec path
- input token paths
- generated files
- validation summary
- generator version
- schemaVersion

## 8. Determinism requirements

- input path order 정규화
- token merge order 정규화
- output file sort order 정규화
- manifest key order 정규화
- timestamp는 v1에서는 manifest에서 제외한다
