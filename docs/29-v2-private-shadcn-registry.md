# 29. V2 Private shadcn Registry

## 1. Decision

v2의 HTML canonical review generator는 public shadcn registry를 직접 소비하지 않는다.
대신 **private shadcn registry** 를 두고, generator는 이 registry에 등록된 component/block만 사용한다.

## 2. Why Private Registry

- arbitrary component drift 방지
- agent가 허용된 block만 쓰게 강제
- web / native mapping을 registry item metadata에 고정
- visual style와 token policy를 team-owned contract로 유지

## 3. Namespace Design

```text
@axys-mobile/primitives/*
@axys-mobile/mobile/*
@axys-mobile/flow-shells/*
```

### primitives
- button
- text-input
- secure-input
- card
- image-frame
- icon
- divider
- spacer

### mobile
- auth-form
- checkout-summary
- payment-form
- profile-header
- empty-state
- loading-panel

### flow-shells
- top-app-bar
- bottom-tab-shell
- modal-shell
- sheet-shell
- stepper-shell

## 4. Registry Item Contract

각 item은 아래를 explicit하게 가진다.

- `id`
- `kind`
- `importPath`
- `exportName`
- `allowedProps`
- `slots`
- `stateRequirements`
- `reviewHints`
- `nativeMapping.ios`
- `nativeMapping.android`
- `motionSlots`

## 5. HTML Generation Rule

HTML generator는 아래 규칙을 따른다.

1. screen layout tree를 읽는다.
2. `componentId` 를 registry item으로 resolve 한다.
3. item metadata에 정의된 allowed props만 렌더링한다.
4. Tailwind class는 registry source 안에만 존재한다.
5. screen contract는 arbitrary class string을 직접 쓰지 못한다.

즉 contract는 “무엇을 렌더링할지”를 말하고,
registry는 “그것을 web에서 어떻게 구현할지”를 말한다.

## 6. Native Mapping Rule

private shadcn registry는 web-only registry가 아니다.
각 item은 아래 native mapping 힌트를 가져야 한다.

- `ios.component`
- `android.component`
- `ios.props`
- `android.props`
- `stateBindings`
- `actionBindings`
- `navigationBindings`

이 매핑은 native generator가 AI에게 free-form HTML을 다시 해석하게 만들지 않고,
같은 contract semantics를 직접 native renderer에 투입하게 만든다.

## 7. Tailwind Policy

- Tailwind utility는 registry implementation 내부에서만 쓴다.
- ScreenSpec은 Tailwind class 문자열을 직접 소유하지 않는다.
- spacing / color / radius / motion duration은 token alias로만 들어간다.
- class composition이 필요하면 registry item source에서 해결한다.

## 8. Proposed Registry Files

```text
registries/shadcn/
  registry.json
  items/
    primitives/
      button.json
      text-input.json
      secure-input.json
    mobile/
      auth-form.json
      checkout-summary.json
      payment-form.json
    flow-shells/
      top-app-bar.json
      stepper-shell.json
```

`registry.json` 은 generator가 읽는 canonical manifest다.
`items/*/*.json` 은 item 단위 authoring slice이며, release 시점에 `registry.json` 으로 compile 될 수 있다.

## 9. Approval Rule

새 registry item은 아래를 모두 통과해야 한다.

- schema validation
- HTML review example
- SwiftUI mapping review
- Compose mapping review
- reduced motion fallback check
- sample screen integration smoke

## 10. Final Rule

private shadcn registry는 convenience layer가 아니라 **deterministic rendering vocabulary** 다.
public ecosystem의 빠른 속도를 그대로 source of truth에 들이지 않고,
team-owned registry로 흡수해서 안정성을 확보한다.
