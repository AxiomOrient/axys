# 27. V2 Document Structure

## 1. Authoritative Document Set

v2의 문서 패키지는 prose 문서와 machine contract를 분리한다.

### prose docs
- `26-v2-system-design.md`
- `27-v2-doc-structure.md`
- `28-v2-schema-drafts.md`
- `29-v2-private-shadcn-registry.md`
- `30-v2-operating-runbook.md`

### machine contracts
- `schemas/v2/*.schema.json`
- `examples/v2/apps/*.app.yaml`
- `examples/v2/flows/*.flow.yaml`
- `examples/v2/screens/*.screen.yaml`
- `examples/v2/motion/*.motion.yaml`
- `examples/v2/review/*.review.yaml`

## 2. Repository Layout

```text
examples/v2/
  apps/
    commerce.app.yaml
    banking.app.yaml
  flows/
    commerce-checkout.flow.yaml
    banking-onboarding.flow.yaml
  screens/
    checkout-cart.screen.yaml
    checkout-payment.screen.yaml
    onboarding-verify-phone.screen.yaml
  motion/
    mobile-core.motion.yaml
  review/
    mobile-core.review.yaml

registries/shadcn/
  registry.json
  items/
    primitives/
    mobile/
    flow-shells/
```

## 3. Required Authoring Artifacts

### 3.1 AppSpec
- 앱 단위 ownership
- brand / theme / registry / token set / flow inventory

### 3.2 FlowSpec
- multi-screen graph
- entry screen
- transitions
- deep link / exit condition

### 3.3 ScreenSpec v2
- screen semantics
- state fields
- actions
- navigation
- layout tree
- component bindings
- preview states
- review benchmark refs

### 3.4 MotionSpec
- transition id
- duration/easing token
- reduced motion fallback
- screen-level motion pattern

### 3.5 Review Checklist
- structure
- semantics
- tokens
- motion
- native viability

## 4. Authoring Order

1. `AppSpec`
2. `FlowSpec`
3. `MotionSpec`
4. `ScreenSpec v2`
5. `Review Checklist`
6. HTML review
7. Penpot / Pencil adapter
8. native generation
9. sample-app build

## 5. Example Templates

### AppSpec file naming
- `<app-id>.app.yaml`

### FlowSpec file naming
- `<app-id>-<flow-id>.flow.yaml`

### ScreenSpec file naming
- `<flow-id>-<screen-id>.screen.yaml`

### MotionSpec file naming
- `<motion-set-id>.motion.yaml`

### Review file naming
- `<review-set-id>.review.yaml`

## 6. Disposable Outputs

아래는 v2에서도 disposable artifact다.

- generated HTML bundle
- generated SwiftUI source
- generated Compose source
- exported Penpot payload
- exported Pencil payload
- build logs
- snapshots

## 7. Source-Owned Evidence

아래는 source-owned evidence로 남긴다.

- review approval snapshot
- sample app build result
- adapter sync result
- audit report
- acceptance report

## 8. Simplicity Rule

하나의 screen을 설명하기 위해 prose를 길게 쓰지 않는다.
의미가 contract field로 떨어질 수 있으면 반드시 structured field로 내린다.
Markdown은 rationale과 human note를 위한 것이고, generation truth는 YAML/JSON 계약이 소유한다.
