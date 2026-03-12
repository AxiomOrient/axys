# 09. Preview, Review, and Optional Adapters

## 1. Canonical review path

canonical review path는 **HTML preview**다.

## 2. Why HTML

- 가장 가볍다.
- CI artifact로 남기기 쉽다.
- local file로 열 수 있다.
- 다른 앱을 켜지 않아도 된다.
- design editor lock-in이 없다.

## 3. Review workflow

```text
generate
  → open html
  → check declared preview states
  → confirm structure/hierarchy/action emphasis
  → approve
  → integrate native
```

## 4. Review checklist

### 4.1 Structure
- hierarchy가 명확한가
- 스크린이 하나의 primary intent를 갖는가

### 4.2 Semantics
- declared preview state가 모두 보이는가
- state note와 field snapshot이 review 의도와 맞는가
- title / body / caption / label이 적절한가
- button variant가 맞는가

### 4.3 Tokens
- spacing이 tokens에서 왔는가
- color가 tokens에서 왔는가

### 4.4 Native viability
- 이 구조를 SwiftUI/Compose로 무리 없이 옮길 수 있는가

source-owned acceptance evidence는 이 체크를 자유형 메모로 남기지 않는다.
canonical acceptance artifact의 `review` section은 아래 최소 checklist id를 가진다.

- `structure.primary_intent`
- `semantics.preview_coverage`
- `tokens.alias_usage`
- `native.adapter_viability`

또한 `review.reviewedPreviewStates` 는 referenced `ScreenSpec.previewStates[*].id`
전체를 담아야 하고, HTML review surface 안에서도 같은 state id가 보여야 한다.
acceptance artifact는 여기서 끝나지 않고 `generatedManifest` 로 같은 review surface와
declared platform output이 실제 generated bundle 안에 있는지도 함께 고정한다.

## 5. Penpot policy

Penpot은 다음 역할만 가진다.
- optional review adapter
- optional self-hosted collaboration surface
- optional token / inspect alignment aid

Penpot file은 authoritative source가 아니다.

## 6. Pencil policy

Pencil은 다음 역할만 가진다.
- optional local preview / operator tool
- optional AI-assisted visual exploration

Pencil file은 authoritative source가 아니다.

## 7. Adapter boundary

어떤 adapter도 아래를 건드리면 안 된다.
- ScreenSpec schema
- token policy
- generation pipeline

즉, adapter는 **core path 외부**에 있다.
