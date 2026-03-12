# 28. V2 Schema Drafts

## 1. Draft Set

v2 초안은 아래 여섯 schema로 시작한다.

1. `schemas/v2/app-spec.schema.json`
2. `schemas/v2/flow-spec.schema.json`
3. `schemas/v2/screen-spec-v2.schema.json`
4. `schemas/v2/component-registry-v2.schema.json`
5. `schemas/v2/motion-spec.schema.json`
6. `schemas/v2/review-checklist.schema.json`

## 2. Relationship

```text
AppSpec
  -> FlowSpec[*]
  -> token set id
  -> registry id
  -> motion spec id
  -> review checklist id

FlowSpec
  -> ScreenSpec v2[*]

ScreenSpec v2
  -> component registry item ids
  -> motion pattern ids
  -> review checklist ids

Component Registry v2
  -> web renderer mapping
  -> native renderer mapping

MotionSpec
  -> screen / transition motion ids

Review Checklist
  -> HTML review gate
  -> acceptance evidence ids
```

## 3. Schema Policy

- schema version은 `2.1` 로 시작한다.
- 모든 id는 kebab-case로 고정한다.
- HTML / iOS / Android target은 explicit field로 가진다.
- arbitrary prop bag는 허용하되 `allowedProps` 와 registry contract로 제한한다.
- tokenized value와 raw literal을 분리한다.
- layout tree는 generic node + registry item reference 조합으로 유지한다.

## 4. Why Generic Layout Tree

v1은 fixed node kind 중심이었다.
v2는 richer registry를 위해 layout tree를 generic container와 component reference로 나눈다.

즉:

- layout semantics는 screen contract가 소유
- visual implementation details는 registry item이 소유
- renderer mapping은 registry와 generator가 공동 소유

## 5. Required Invariants

### AppSpec
- 모든 flow ref는 실제 FlowSpec path를 가리켜야 한다.
- registry id / token set / motion set / review set이 explicit해야 한다.

### FlowSpec
- entry screen은 screens 목록 안에 있어야 한다.
- transitions는 declared screen id만 참조해야 한다.

### ScreenSpec v2
- preview state는 declared state 전체를 덮어야 한다.
- layout tree의 component id는 registry에 존재해야 한다.
- bindings/action/navigation은 state/action/navigation contract를 벗어나면 안 된다.

### Registry
- 모든 item은 web + native mapping policy를 가져야 한다.
- allowedProps와 slot contract가 explicit해야 한다.

### MotionSpec
- 모든 motion pattern은 reduced motion fallback을 가져야 한다.

### Review Checklist
- HTML review와 native viability를 모두 커버해야 한다.

## 6. Draft Status

이 schema들은 구현 완료 schema가 아니라 **v2 authoring contract를 고정하기 위한 draft** 다.
generator 구현보다 먼저 안정화해야 하며, v2.1에서는 schema drift를 최소화하는 것이 우선이다.
